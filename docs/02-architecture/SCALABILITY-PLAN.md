# Scalability Plan
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Growth triggers, upgrade paths, and migration guides for every infrastructure component

---

## 1. Scaling Philosophy

The platform is designed with a **"scale when it hurts" principle**:

1. Start simple (single instance, free tiers, local Docker)
2. Measure actual load and identify bottlenecks
3. Scale the specific bottleneck — never pre-optimise

Every component has a **trigger threshold** and a **documented upgrade path** that requires **zero application code changes**.

---

## 2. Neon PostgreSQL Scaling

### 2.1 Growth Stages

| Stage | Trigger | Action | Cost Impact |
|-------|---------|--------|------------|
| **PoC** | Starting out | Free tier: 0.25 vCPU, 512 MB storage, 10 branches | Free |
| **Growth** | Storage > 400 MB or query p99 > 200ms | Upgrade to **Neon Launch** ($19/mo): 10 GB storage, auto-scaling compute | ~$19/mo |
| **Scale** | Storage > 10 GB or concurrent connections > 100 | Upgrade to **Neon Scale** ($69/mo): 50 GB, 500 connections, read replicas | ~$69/mo |
| **Enterprise** | Multi-region, SLA requirements, > 200 GB | Migrate to **Neon Business** or self-managed PostgreSQL (RDS, Cloud SQL, bare metal) | Variable |

### 2.2 Read Replicas for Reports

When the Ruby Report Engine's read-heavy queries start impacting write performance:

```
Current:  All services → single Neon compute endpoint
After:    Write services → primary endpoint
          Report Engine  → read replica endpoint
```

Neon read replicas are additional compute endpoints on the same storage — no data copy needed:
```bash
# Neon CLI
neon endpoint create --branch main --type read_replica
# Returns a new connection string for read traffic
```

Update only the Ruby Report Engine's `DATABASE_URL` to the read replica — no code changes.

### 2.3 Connection Pooling

Neon includes built-in connection pooling (PgBouncer). Services should connect through the pooled endpoint:

```
# Pooled (for application queries — recommended)
postgresql://user:pw@project.neon.tech/db?sslmode=require&pgbouncer=true

# Direct (for migrations and long-running queries only)
postgresql://user:pw@project.neon.tech/db?sslmode=require
```

### 2.4 Migration to Self-Managed PostgreSQL

If Neon is outgrown or cost becomes prohibitive at very large scale:

1. `pg_dump` full Neon database
2. Provision PostgreSQL 16+ (Docker, RDS, Cloud SQL, or bare metal)
3. `pg_restore` to new instance
4. Update `NEON_URL` env variable across all services
5. **Zero application code changes** — all services use standard PostgreSQL wire protocol

---

## 3. Service Scaling

### 3.1 Horizontal Scaling (Docker Compose)

All services are **stateless** — state lives in Neon + Redis. Scaling is trivial:

```bash
# Scale a specific service to 3 instances
docker compose up -d --scale workorder=3

# Load balance across instances using Nginx or Traefik
```

Add Nginx as a reverse proxy in front of the API Gateway:

```nginx
# infrastructure/nginx/nginx.conf
upstream api_gateway {
    server api-gateway-1:8080;
    server api-gateway-2:8080;
    server api-gateway-3:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://api_gateway;
    }
}
```

### 3.2 Kubernetes Migration Path

When Docker Compose is no longer sufficient (10+ services, auto-scaling, multi-node):

| Docker Compose Concept | Kubernetes Equivalent |
|-----------------------|----------------------|
| `services:` | `Deployment` + `Service` |
| `ports:` | `Service` (ClusterIP/NodePort) |
| `environment:` | `ConfigMap` + `Secret` |
| `volumes:` | `PersistentVolumeClaim` |
| `healthcheck:` | `livenessProbe` + `readinessProbe` |
| `depends_on:` | `initContainers` |
| `networks:` | Kubernetes networking (automatic) |

Migration tool: Use **Kompose** to auto-generate initial Kubernetes manifests:
```bash
kompose convert -f docker-compose.yml
```

Then refine with:
- HPA (Horizontal Pod Autoscaler) for auto-scaling based on CPU/request rate
- Ingress controller (Nginx Ingress or Traefik) for external access
- Cert-Manager for automatic TLS certificates

### 3.3 Per-Service Scaling Guidance

| Service | Expected Load | Scale Trigger | Strategy |
|---------|--------------|--------------|----------|
| API Gateway | All traffic | CPU > 70% | Scale to 3 replicas + sticky sessions for WebSocket |
| Work Order | Highest write load | Request queue > 50 | Scale to 2–3 replicas |
| CMMS | Moderate read/write | Response time > 500ms | Scale to 2 replicas |
| Helpdesk | Seasonal (survey periods) | During survey sends | Burst to 3 replicas, scale back |
| Report Engine | Periodic heavy reads | During report generation | Scale to 2 replicas during generation window |

---

## 4. Redis Scaling

### 4.1 Growth Stages

| Stage | Trigger | Action |
|-------|---------|--------|
| **PoC** | Starting out | Single Redis instance (Docker) |
| **Growth** | Memory > 500 MB or connections > 200 | Add Redis Sentinel (3 nodes for HA) |
| **Scale** | Memory > 4 GB or global distribution needed | Migrate to managed Redis (Upstash serverless, Redis Cloud, or AWS ElastiCache) |

### 4.2 Redis Cluster Setup (Docker Compose)

```yaml
# Add to docker-compose.yml when HA is needed
redis-master:
  image: redis:7-alpine
  command: redis-server --appendonly yes
redis-replica-1:
  image: redis:7-alpine
  command: redis-server --replicaof redis-master 6379
redis-sentinel:
  image: redis:7-alpine
  command: redis-sentinel /sentinel.conf
```

### 4.3 Alternative: Upstash (Serverless Redis)

If preferring managed over self-hosted:
- Upstash offers serverless Redis with per-request pricing
- Free tier: 10,000 commands/day, 256 MB
- Swap by changing `REDIS_URL` — no code changes (standard Redis protocol)

---

## 5. MinIO / File Storage Scaling

### 5.1 Growth Stages

| Stage | Trigger | Action |
|-------|---------|--------|
| **PoC** | Starting out | Single MinIO node, local Docker volume |
| **Growth** | Storage > 50 GB | MinIO Distributed Mode (4 drives minimum) |
| **Scale** | Storage > 500 GB or global access needed | Migrate to Cloudflare R2 or AWS S3 |

### 5.2 MinIO → Cloud S3 Migration

```bash
# Use MinIO Client (mc) to mirror data
mc mirror minio/rg-workorder-photos s3/rg-workorder-photos
mc mirror minio/rg-documents s3/rg-documents
mc mirror minio/rg-exports s3/rg-exports

# Update environment variable (all services use S3 SDK)
# MINIO_ENDPOINT=https://s3.amazonaws.com  (or r2.cloudflarestorage.com)
```

**Zero application code changes** — S3 SDK works with any S3-compatible endpoint.

---

## 6. API Gateway Scaling

### 6.1 Growth Stages

| Stage | Action |
|-------|--------|
| **PoC** | Single Go API Gateway (handles ~10K req/sec) |
| **Growth** | 3 replicas behind Nginx load balancer |
| **Scale** | Add Traefik with automatic service discovery |
| **Enterprise** | Replace custom Go gateway with Kong or AWS API Gateway |

### 6.2 WebSocket Scaling

WebSocket connections are stateful. When scaling the API Gateway:
- Use **Redis pub/sub** to broadcast WebSocket messages across gateway instances
- Client connects to any gateway instance
- Gateway subscribes to Redis channel
- When a work order changes, the publishing service pushes to Redis
- All gateway instances receive the message and forward to their connected clients

```
Client A ──► Gateway-1 ──┐
                          ├──► Redis pub/sub ◄──── Work Order Service publishes event
Client B ──► Gateway-2 ──┘
```

---

## 7. Desktop Sync Scaling

### 7.1 Growth Stages

| Stage | Action |
|-------|--------|
| **PoC** | Sync agent polls every 500ms, batches of 50 |
| **Growth** (100+ devices) | Reduce poll frequency to 2s, increase batch to 200 |
| **Scale** (1000+ devices) | Replace polling with **Server-Sent Events (SSE)** or WebSocket for push-based sync |

### 7.2 Server-Side Sync Scaling

When many desktop clients sync simultaneously:
- API Gateway rate-limits sync requests per client (60/min per device)
- Neon connection pool shared across sync handlers
- If sync load is high, add a dedicated sync service (extract from API Gateway into its own microservice)

---

## 8. Multi-Property / Multi-Tenant Scaling

### 8.1 Stage 1: Single-Property (Current)

All data in one set of schemas. `property_id` column filters data per property.

### 8.2 Stage 2: Multi-Property (Same Schemas)

Add more properties — same schemas, same services. Data isolation via `property_id` + `X-User-Property` header. No architectural change needed.

### 8.3 Stage 3: Multi-Tenant SaaS

Each tenant (management company) gets isolated data:

| Isolation Strategy | Pros | Cons | Best For |
|-------------------|------|------|----------|
| **Row-level** (tenant_id column) | Simplest, lowest cost | No true isolation, complex RLS policies | < 100 tenants |
| **Schema-per-tenant** | Good isolation, same DB | Schema management overhead, Neon supports this well | 100–500 tenants |
| **Database-per-tenant** | Full isolation | Complex routing, higher cost | 500+ tenants or compliance-heavy |

Recommended path: Start with **row-level** → migrate to **schema-per-tenant** if compliance demands it.

---

## 9. Observability Scaling

| Stage | Action |
|-------|--------|
| **PoC** | `docker compose logs` + TeamCity email alerts |
| **Growth** | Add Grafana + Prometheus stack (Docker Compose) |
| **Scale** | Add Loki for log aggregation (searchable logs) |
| **Enterprise** | Migrate to Datadog, New Relic, or Grafana Cloud |

---

## 10. Scaling Decision Matrix

Use this table to quickly determine what to scale next based on symptoms:

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| API requests timing out | Service overloaded | Scale service replicas |
| Database queries slow | Neon compute too small | Upgrade Neon plan, add read replica |
| Sync falling behind | Too many devices syncing | Increase batch size, add sync service |
| File uploads slow | MinIO disk I/O | MinIO distributed mode or cloud S3 |
| Dashboard WebSocket drops | Gateway overwhelmed | Scale gateway, add Redis pub/sub |
| Redis memory full | Too much cache | Increase instance memory or add eviction policy |
| Builds slow in TeamCity | Single agent | Add TeamCity build agents |
| Docker host running low on RAM | Too many containers | Vertically scale host or split to 2 hosts |
