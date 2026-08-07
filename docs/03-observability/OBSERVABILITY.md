# Observability & Operations Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Logging standards, health checks, metrics, backup runbooks, and operational procedures

---

## 1. Logging Standards

### 1.1 Log Format (Structured JSON)

Every service emits structured JSON logs to stdout. Docker captures these and they can be queried or forwarded to a log aggregator.

**Standard fields:**
```json
{
  "level": "info",
  "service": "workorder-service",
  "version": "1.2.0",
  "request_id": "uuid",
  "user_id": "supabase-sub-uuid",
  "method": "PATCH",
  "path": "/api/v1/workorders/uuid",
  "status": 200,
  "duration_ms": 42,
  "timestamp": "2026-08-04T18:00:00.000Z"
}
```

**Error log:**
```json
{
  "level": "error",
  "service": "workorder-service",
  "request_id": "uuid",
  "error": "pq: connection refused",
  "stack": "...",
  "timestamp": "2026-08-04T18:00:00.000Z"
}
```

### 1.2 Log Libraries Per Language

| Service | Library | Config |
|---------|---------|--------|
| Go | `rs/zerolog` | `zerolog.SetGlobalLevel(zerolog.InfoLevel)` |
| C#/.NET | `Serilog` + `Serilog.Sinks.Console` (JSON formatter) | `WriteTo.Console(new JsonFormatter())` |
| Python | `structlog` | `structlog.configure(processors=[...JSONRenderer...])` |
| Ruby | `semantic_logger` | `SemanticLogger.add_appender(io: STDOUT, formatter: :json)` |

### 1.3 Log Levels

| Level | When to Use |
|-------|------------|
| DEBUG | Detailed diagnostics (disabled in production) |
| INFO | Normal operations (request received, record created) |
| WARN | Non-fatal issues (retry occurred, cache miss, deprecated field used) |
| ERROR | Failed operations (DB error, upstream service down) |
| FATAL | Unrecoverable errors (service cannot start) |

### 1.4 What to Log

**Always log:**
- Every inbound HTTP request (method, path, status, duration_ms, user_id)
- Every database error
- Every sync conflict
- Every SLA breach
- Every file upload success/failure

**Never log:**
- JWT tokens or credentials
- Passwords
- Full request bodies containing PII (resident descriptions etc.)
- Full SQL queries with bound parameters

### 1.5 Log Storage

```
Docker → stdout → docker compose logs
                 → (future) Loki or Elasticsearch for searchable log aggregation
```

Log rotation on Docker: `--log-opt max-size=100m --log-opt max-file=5` in Docker Compose.

---

## 2. Health Checks

### 2.1 Health Endpoint Contract

Every service must expose:

**`GET /health`** — Liveness (is the process alive?)
```json
{
  "status": "ok",
  "service": "workorder-service",
  "version": "1.2.0",
  "uptime_seconds": 3600
}
```

**`GET /ready`** — Readiness (can it serve traffic?)
```json
{
  "status": "ok",
  "checks": {
    "database": "ok",
    "redis": "ok",
    "minio": "ok"
  }
}
```

If any dependency is unhealthy, `ready` returns HTTP 503:
```json
{
  "status": "degraded",
  "checks": {
    "database": "ok",
    "redis": "error: connection refused",
    "minio": "ok"
  }
}
```

### 2.2 Docker Compose Health Check

```yaml
# docker-compose.yml
services:
  workorder:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
```

### 2.3 Dependency Startup Order

```yaml
services:
  workorder:
    depends_on:
      redis:
        condition: service_healthy
  # Note: Neon is external — no Docker dependency
  # Services should handle Neon unavailability gracefully with retries
```

---

## 3. Metrics (Future Phase)

When traffic warrants it, add Prometheus + Grafana to the Docker Compose stack.

### 3.1 Prometheus Setup

```yaml
# docker-compose.yml addition
  prometheus:
    image: prom/prometheus:latest
    ports: ["9090:9090"]
    volumes:
      - ./infrastructure/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports: ["3001:3000"]
    depends_on: [prometheus]
```

### 3.2 Metrics Per Service

Each service exposes `GET /metrics` (Prometheus text format):

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total requests by method, path, status |
| `http_request_duration_seconds` | Histogram | Request latency percentiles |
| `work_orders_open_total` | Gauge | Current open work order count |
| `sla_breach_total` | Counter | Total SLA breaches by priority |
| `sync_queue_depth` | Gauge | Unsynced records in _changes table |
| `sync_conflicts_total` | Counter | Sync conflicts generated |
| `db_query_duration_seconds` | Histogram | DB query latency |
| `redis_operations_total` | Counter | Redis operations by command |

### 3.3 Grafana Dashboards (Pre-Built)

1. **Operations Dashboard:** open WOs, SLA compliance rate, WOs by priority, overdue items
2. **System Health:** CPU/memory per container, DB latency, Redis latency, request rates
3. **Sync Dashboard:** queue depth, sync lag, conflict rate per device
4. **Billing Dashboard:** collection rate, overdue units, monthly revenue

---

## 4. Backup Strategy

### 4.1 Neon PostgreSQL Backup

| Strategy | Method | Frequency | Retention |
|----------|--------|-----------|-----------|
| Neon PITR (paid tier) | Automatic (Neon Pro) | Continuous | 7 days |
| Manual `pg_dump` | PowerShell script → MinIO | Daily (2am) | 30 days |

```powershell
# infrastructure/teamcity/backup-neon.ps1
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$dumpFile = "neon_backup_$timestamp.sql.gz"

# Dump
pg_dump $env:NEON_URL | gzip > $dumpFile

# Upload to MinIO
mc cp $dumpFile minio/rg-backups/neon/$dumpFile

# Remove local file
Remove-Item $dumpFile

# Prune old backups (keep 30 days)
mc find minio/rg-backups/neon --older-than 30d --exec "mc rm {}"
```

### 4.2 SQLite Desktop Backup

The desktop app runs an automatic weekly backup of `local.db`:

```go
// backup.go (sync agent)
func BackupSQLite(dbPath string) error {
    backupDir := filepath.Join(filepath.Dir(dbPath), "backups")
    os.MkdirAll(backupDir, 0755)
    
    timestamp := time.Now().Format("2006-01-02")
    backupPath := filepath.Join(backupDir, fmt.Sprintf("local_%s.db", timestamp))
    
    // SQLite online backup using VACUUM INTO
    db.Exec(fmt.Sprintf("VACUUM INTO '%s'", backupPath))
    
    // Keep last 4 backups only
    pruneOldBackups(backupDir, 4)
    return nil
}
```

### 4.3 MinIO Backup

```powershell
# infrastructure/teamcity/backup-minio.ps1
# Mirror production MinIO buckets to backup location
mc mirror minio/rg-workorder-photos backup-minio/rg-workorder-photos --overwrite
mc mirror minio/rg-documents backup-minio/rg-documents --overwrite
mc mirror minio/rg-exports backup-minio/rg-exports --overwrite
```

### 4.4 Redis Backup

Redis is used for ephemeral data (SLA timers, pub/sub, cache) — **not** for durable state. No critical data lives only in Redis. Redis RDB snapshots are captured by Docker volume persistence.

If Redis is unavailable or loses data:
- SLA timers will be recalculated on next Work Order Service start (from Neon)
- Session caches will be rebuilt on next request
- Pub/sub messages in-flight will be lost (acceptable — real-time events only)

---

## 5. Alerting

### 5.1 Early Stage (TeamCity)

TeamCity sends email notification on:
- Build failure (any service)
- Test failures
- Docker image build failure

### 5.2 Future: Prometheus AlertManager

```yaml
# prometheus/alerts.yml
groups:
  - name: operations
    rules:
      - alert: HighSLABreachRate
        expr: rate(sla_breach_total[5m]) > 0.1
        for: 5m
        annotations:
          summary: "SLA breach rate is high — check work order assignments"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        annotations:
          summary: "Service {{ $labels.job }} is down"

      - alert: DatabaseHighLatency
        expr: histogram_quantile(0.99, db_query_duration_seconds) > 2
        for: 5m
        annotations:
          summary: "DB query p99 latency over 2 seconds"

      - alert: SyncQueueGrowing
        expr: sync_queue_depth > 500
        for: 10m
        annotations:
          summary: "Sync queue not draining — check sync agent"
```

---

## 6. Operational Runbooks

### 6.1 Restart a Service

```powershell
# Restart a single service without downtime
docker compose restart workorder

# Full stack restart
docker compose down && docker compose up -d
```

### 6.2 View Service Logs

```powershell
# Tail logs for a service
docker compose logs -f workorder

# Last 100 lines
docker compose logs --tail=100 workorder

# All services
docker compose logs -f
```

### 6.3 Run Database Migration

```powershell
# Go service (golang-migrate)
docker compose exec workorder migrate -path ./migrations -database $NEON_URL up

# .NET service (EF Core)
docker compose exec cmms dotnet ef database update

# Python service (Alembic)
docker compose exec helpdesk alembic upgrade head

# Ruby service (Rails)
docker compose exec reports rails db:migrate
```

### 6.4 Refresh Neon Materialized Views

```sql
-- Run periodically (nightly via TeamCity)
REFRESH MATERIALIZED VIEW CONCURRENTLY reports.v_work_order_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY reports.v_ppm_compliance;
REFRESH MATERIALIZED VIEW CONCURRENTLY reports.v_resident_satisfaction;
```

### 6.5 Emergency: Disable Sync Agent

If a sync agent is causing data corruption:
```powershell
# On the desktop: kill the sync agent process
Get-Process rg-sync-agent | Stop-Process

# The app continues working offline against local SQLite
# No data loss — all changes queue in _changes table
# Restart sync agent manually when issue is resolved
```
