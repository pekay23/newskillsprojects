# Raymond Gray Integrated Facility Management (IFM) Platform
## Project 1 — Canonical Master Plan

> **Status:** ACTIVE — Single Source of Truth  
> **Scope:** Project 1 — Raymond Gray IFM Platform  
> **Developer:** Solo (AI-assisted development)  
> **Stack:** Go · C#/.NET · Python · Ruby · Next.js · Neon PostgreSQL · SQLite · Docker  
> **CI/CD:** TeamCity (`C:\TeamCity`)  
> **Cloud DB:** Neon (PostgreSQL-compatible, serverless)  
> **Local DB:** SQLite (embedded, per-device for desktop clients)  
> **Auth:** Supabase Auth (JWT) — kept for auth only, DB migrated to Neon  

---

## Table of Contents

1. [Vision & Goals](#1-vision--goals)
2. [Architectural Philosophy](#2-architectural-philosophy)
3. [System Architecture](#3-system-architecture)
4. [Services Overview](#4-services-overview)
5. [Data Layer Strategy](#5-data-layer-strategy)
6. [Sync Engine Design](#6-sync-engine-design)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [Storage Strategy (Files & Photos)](#8-storage-strategy-files--photos)
9. [API Design & Versioning](#9-api-design--versioning)
10. [Observability & Operations](#10-observability--operations)
11. [CI/CD Pipeline](#11-cicd-pipeline)
12. [Scalability Plan](#12-scalability-plan)
13. [Alternatives Reference](#13-alternatives-reference)
14. [Gaps — Fixed & Tracked](#14-gaps--fixed--tracked)
15. [Future Roadmap](#15-future-roadmap)
16. [Directory Structure](#16-directory-structure)
17. [Reference Documents](#17-reference-documents)

---

## 1. Vision & Goals

The **Raymond Gray IFM Platform** is a comprehensive, enterprise-grade Integrated Facility Management system for managing:

- **Work Orders & SLA tracking** — from creation to close, with automatic escalation
- **Assets & PPM (Planned Preventive Maintenance)** — full asset lifecycle management
- **Resident Helpdesk** — request management, amenity booking, satisfaction surveys
- **Billing** — HOA fee processing, reserve fund tracking, unit-level billing
- **Reporting** — operational and executive reports, PDF generation
- **Field Operations** — mobile app for technicians with offline support
- **IoT Integration** — building sensor data driving automated work orders

### Design Principles

| Principle | What It Means |
|-----------|--------------|
| **AI-Assisted Build** | Every service is built with AI agents — speed and precision over manual effort |
| **Polyglot by Design** | Each service uses the right language for its domain (Go for performance, Python for NLP, Ruby for reporting) |
| **Offline-First Desktop** | Desktop clients work without internet; sync when connected |
| **Cloud-First Cloud DB** | Neon PostgreSQL as the canonical data store — serverless, branchable, scalable |
| **Schema Isolation** | One Neon database, one schema per service — clean separation without multi-DB overhead |
| **Zero Lock-in** | Every infrastructure component has a documented alternative that can be swapped without rewriting application code |

---

## 2. Architectural Philosophy

### Pattern: Polyglot Microservices with BFF Proxy

The system uses a **Backend-for-Frontend (BFF)** proxy pattern during early phases, graduating to a **dedicated API Gateway** as services multiply.

```
Phase 1-3:  Next.js BFF → individual services (direct proxy)
Phase 4+:   Next.js → Go API Gateway → individual services
```

This avoids premature over-engineering while preserving a clean migration path.

### Pattern: Schema-Per-Service on Shared DB

Rather than one database per service (expensive, complex to join) or one monolithic schema (tight coupling), we use **one Neon PostgreSQL database with one schema per service**. Services can read from each other's schemas via read-only cross-schema views when needed (e.g., reports reading workorder data).

### Pattern: Change-Queue Sync for Offline

Rather than replicating the entire PostgreSQL protocol to SQLite, the desktop sync agent maintains a **`_changes` queue table** in SQLite. A lightweight Go sync agent drains this queue to the cloud via a REST API. This is simple, auditable, and requires no complex CRDT logic.

---

## 3. System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER                                               │
│  Next.js Web App    Windows Desktop    macOS Desktop    iOS/Android Mobile    │
│  (Port 3000)        (WPF/Tauri)        (Tauri/Electron) (Flutter)             │
└────────┬───────────────────┬──────────────────┬──────────────────────────────┘
         │                   │                  │
         │ HTTP/WS           │ SQLite + Go       │ HTTPS REST
         │                   │ Sync Agent        │
         ▼                   ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GO API GATEWAY  (:8080)                                    │
│   JWT Validation · Rate Limiting · Request Routing · /sync endpoints         │
└────┬──────────┬──────────┬──────────┬──────────┬──────────────────────────┘
     │          │          │          │          │
     ▼          ▼          ▼          ▼          ▼
┌─────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────────┐
│  Go     │ │ .NET   │ │ Python │ │ Ruby   │ │ C/C++ IoT  │
│ Work    │ │ Asset  │ │ Help-  │ │ Report │ │ Simulation │
│ Order   │ │ CMMS   │ │ desk   │ │ Engine │ │ Gateway    │
│ :8081   │ │ :8082  │ │ :8083  │ │ :8084  │ │ :8085      │
└────┬────┘ └───┬────┘ └───┬────┘ └───┬────┘ └─────┬──────┘
     │          │          │          │             │
     └──────────┴──────────┴──────────┴─────────────┘
                           │
              ┌────────────▼─────────────┐
              │   NEON POSTGRESQL        │
              │   schema: workorders     │
              │   schema: cmms           │
              │   schema: helpdesk       │
              │   schema: reports        │
              │   schema: auth_bridge    │
              └──────────────────────────┘
              ┌──────────────────────────┐
              │   REDIS (:6379)          │
              │   SLA timers · pub/sub   │
              │   session cache          │
              └──────────────────────────┘
              ┌──────────────────────────┐
              │   MINIO (:9000)          │
              │   Photos · Documents     │
              │   (S3-compatible)        │
              └──────────────────────────┘
```

### Auth Flow

```
User → Next.js → Supabase Auth → JWT issued
JWT → sent with every API request → Go API Gateway validates → forwards to service
```

Supabase is retained **only for authentication**. No application data lives in Supabase.

---

## 4. Services Overview

### 4.1 Go — Work Order & SLA Service (:8081)
**Language:** Go  
**Router:** Chi (`go-chi/chi`)  
**DB Driver:** `pgx/v5` (PostgreSQL) + `mattn/go-sqlite3` (sync agent)  
**Schema:** `workorders`  

**Responsibilities:**
- Full Work Order lifecycle (create → assign → in-progress → complete → close)
- SLA timer engine (goroutine-based background workers)
- Escalation rules (automatic reassignment on SLA breach)
- WebSocket endpoint for live dashboard updates
- Redis pub/sub event publisher (notifies other services of WO state changes)
- `/sync` endpoint handler for desktop sync agent

**Core Entities:**
- `WorkOrder` (id, title, category, priority, status, assigned_to, property_id, asset_id, created_at, last_modified_at)
- `SLAPolicy` (priority_level, response_hours, resolution_hours)
- `WorkOrderNote` (work_order_id, author, content, created_at)
- `WorkOrderPhoto` (work_order_id, file_path, storage_type, created_at)
- `_changes` (entity, entity_id, operation, payload, synced_at) — sync queue

---

### 4.2 C#/.NET — Asset & CMMS Service (:8082)
**Language:** C# 12 / .NET 8  
**Framework:** ASP.NET Core Minimal APIs  
**ORM:** Entity Framework Core 8 (Code First)  
**Schema:** `cmms`  

**Responsibilities:**
- Property and asset register (buildings, floors, rooms, assets)
- Planned Preventive Maintenance (PPM) scheduling and execution tracking
- Asset lifecycle management (purchase → maintenance → disposal)
- HOA billing module (unit fees, reserve fund)
- `IHostedService` background worker for daily PPM scan

**Core Entities:**
- `Property` (id, name, address, type, total_units)
- `Asset` (id, property_id, name, category, serial_number, warranty_expiry, status)
- `PPMSchedule` (id, asset_id, frequency, next_due, last_completed)
- `PPMCompletion` (id, schedule_id, completed_by, completed_at, notes)
- `UnitBilling` (id, unit_id, period, amount, type, status)

---

### 4.3 Python — Resident Helpdesk Service (:8083)
**Language:** Python 3.12+  
**Framework:** FastAPI  
**ORM:** SQLAlchemy 2.x + Alembic (migrations)  
**Schema:** `helpdesk`  
**Async Tasks:** Celery + Redis  

**Responsibilities:**
- Resident request submission and tracking
- Amenity booking system (pool, gym, lounge) with conflict detection
- Monthly satisfaction surveys (Celery scheduled tasks)
- NLP: keyword/topic extraction from resident feedback (`spaCy`)
- Email/SMS notification dispatch (via Celery workers)

**Core Entities:**
- `ResidentRequest` (id, unit_id, category, description, status, assigned_wo_id, created_at)
- `AmenityBooking` (id, amenity_id, unit_id, start_time, end_time, status)
- `Survey` (id, period, questions_json, status)
- `SurveyResponse` (id, survey_id, unit_id, answers_json, sentiment_score, created_at)

---

### 4.4 Ruby — Report Engine (:8084)
**Language:** Ruby 3.3+  
**Framework:** Rails 7 (API mode)  
**DB:** Read-only cross-schema views into Neon  
**Schema:** `reports`  

**Responsibilities:**
- Monthly Operations Report (work orders, PPM compliance, resident satisfaction)
- Quarterly Performance Review
- Financial summary (billing collections, reserve fund status)
- PDF generation (`Prawn` gem)
- JSON API for embedding report data in the Next.js dashboard

---

### 4.5 C/C++ — IoT Gateway Simulation (:8085)
**Language:** C/C++ (or Go for initial simulation)  
**Protocol:** MQTT (Eclipse Mosquitto as broker in Docker)  
**Schema:** events fed into `workorders` schema via the Go service  

**Responsibilities:**
- Simulate building sensors: temperature, humidity, power, water flow
- Publish MQTT messages on threshold breaches
- Go Work Order service subscribes and auto-creates emergency work orders
- Future: replace simulation with real hardware (Arduino Uno via serial → MQTT bridge)

---

### 4.6 Go — API Gateway (:8080)
**Language:** Go  
**Responsibilities:**
- JWT validation (Supabase public key verification)
- Rate limiting (per-user, per-IP)
- Request routing to services
- `/sync/{service}` — receive SQLite change batches from desktop agents
- `/sync/{service}?since=` — return changes since timestamp (pull sync)
- Request/response logging to structured log files

---

## 5. Data Layer Strategy

See full reference: [`DATA-LAYER.md`](./DATA-LAYER.md)

### 5.1 Neon PostgreSQL (Cloud — Primary Store)

- **Connection:** `NEON_URL=postgresql://<user>:<pw>@<project>.neon.tech/<db>?sslmode=require`
- **Schema isolation:** each service sets `search_path = <schema_name>, public`
- **Branching:** use Neon's branch feature for dev, staging, and testing environments
- **Migrations:** each service owns its schema migrations (Go: `golang-migrate`, .NET: EF Core migrations, Python: Alembic, Ruby: Rails migrations)
- **Cross-schema reads:** `reports` schema contains read-only `VIEW`s referencing other schemas (e.g., `reports.v_work_order_summary` selects from `workorders.work_order`)

### 5.2 SQLite — Desktop Client Local Store

- **Location:** `%APPDATA%\RaymondGray\local.db` (Windows), `~/Library/Application Support/RaymondGray/local.db` (macOS)
- **Driver:** `Microsoft.Data.Sqlite` (if desktop is .NET/WPF), `go-sqlite3` (if desktop is Go/Tauri backend)
- **WAL mode:** always enabled (`PRAGMA journal_mode=WAL`) for concurrent read performance
- **Change tracking:** SQLite triggers write to a `_changes` table on every INSERT/UPDATE/DELETE
- **Sync agent:** a lightweight Go binary that drains `_changes` and calls the API Gateway `/sync` endpoint in real time

### 5.3 Neon Free Tier Limits & Upgrade Trigger

| Metric | Free Tier Limit | Upgrade Trigger |
|--------|----------------|----------------|
| Storage | 512 MB | At 400 MB |
| Compute | 0.25 vCPU / 1 GB RAM | When query latency > 200ms average |
| Branches | 10 | At 8 |
| Plan target | Neon Pro ($19/mo) | At any of the above triggers |

### 5.4 Data Migration (Existing Supabase Data → Neon)

If the existing Next.js app has live data in Supabase PostgreSQL:
1. Use `pg_dump` on the Supabase DB to export existing data
2. Run `pg_restore` into Neon (connection-string compatible — both are PostgreSQL)
3. Update all Prisma connection strings to point to `NEON_URL`
4. Validate row counts match, run the Next.js app against Neon in staging branch first

---

## 6. Sync Engine Design

See full reference: [`SYNC-ENGINE-SPEC.md`](./SYNC-ENGINE-SPEC.md)

### 6.1 Change Queue Architecture

```
Desktop SQLite DB
  ├── [application tables]
  └── _changes
       ├── id          (INTEGER PRIMARY KEY AUTOINCREMENT)
       ├── entity      (TEXT — e.g., "work_order")
       ├── entity_id   (TEXT — UUID of the record)
       ├── operation   (TEXT — INSERT | UPDATE | DELETE)
       ├── payload     (TEXT — JSON of changed fields)
       ├── client_id   (TEXT — unique per device, used for conflict tracking)
       ├── changed_at  (TEXT — ISO8601 client timestamp)
       └── synced_at   (TEXT — NULL until confirmed by server)
```

SQLite triggers:
```sql
CREATE TRIGGER trg_workorder_after_insert AFTER INSERT ON work_order
BEGIN
  INSERT INTO _changes (entity, entity_id, operation, payload, client_id, changed_at)
  VALUES ('work_order', NEW.id, 'INSERT', json_object(...), :client_id, datetime('now'));
END;
```

### 6.2 Sync Agent Flow (Real-Time Push)

```
1. Sync agent starts with the app (background goroutine)
2. Polls _changes WHERE synced_at IS NULL every 500ms
3. Batches up to 50 unsynced records
4. POST /sync/{service} → API Gateway → validates JWT → inserts/updates Neon
5. On 200 OK: marks records synced_at = now() in local SQLite
6. On conflict: server returns 409 with conflicted_record payload → queued for UI review
```

### 6.3 Conflict Resolution

**Strategy: Last-Write-Wins with Manual Override UI**

- Every Neon table has a `last_modified_at TIMESTAMPTZ` and `last_modified_by TEXT` column
- Server compares incoming `changed_at` vs `last_modified_at`
- If incoming is newer → apply (last-write-wins)
- If incoming is older (conflict) → reject with 409, include current server record in response
- Sync agent stores conflicts in a local `_conflicts` table
- Desktop app shows a **Conflict Resolution Panel**: diff of client vs. server values, user picks or merges

### 6.4 Pull Sync (on App Start)

```
1. App starts → sync agent calls GET /sync/{service}?since=<last_pull_timestamp>
2. Server returns all changes since that timestamp
3. Agent applies changes to local SQLite (skip if entity_id + changed_at already exists)
4. Updates local `_sync_state` table with new last_pull_timestamp
```

---

## 7. Authentication & Authorization

See full reference: [`AUTH-STRATEGY.md`](./AUTH-STRATEGY.md)

### 7.1 Current: Supabase Auth (Auth-Only)

Supabase is retained **only for authentication**. All application data lives in Neon.

- Users authenticate via Supabase (email/password, OAuth providers)
- Supabase issues a JWT signed with a project-specific RSA key
- The API Gateway fetches Supabase's JWKS endpoint on startup and caches the public key
- Every request validated: `Authorization: Bearer <supabase_jwt>`
- JWT claims used: `sub` (user ID), `email`, `role`, `app_metadata.roles`

### 7.2 Authorization Model (RBAC)

| Role | Access |
|------|--------|
| `admin` | Full system access |
| `facility_manager` | Work orders, assets, reports, billing |
| `technician` | Own work orders only (read + update) |
| `resident` | Helpdesk requests, own bookings, own billing |
| `report_viewer` | Reports read-only |
| `billing_admin` | Billing read/write, no operational access |

Roles stored in Supabase `app_metadata.roles` (array). The API gateway extracts and forwards as `X-User-Roles` header to downstream services. See full permissions matrix in [`AUTH-STRATEGY.md`](./AUTH-STRATEGY.md).

### 7.3 Alternative: Migrate Auth to Self-Hosted

If Supabase Auth is dropped in future, options (in preference order):
1. **Neon Auth** — Neon's built-in auth feature (OAuth + JWT, same Neon project)
2. **Keycloak** — self-hosted, enterprise RBAC, SAML support
3. **Lucia** — lightweight auth library for Node.js apps

---

## 8. Storage Strategy (Files & Photos)

See full reference: [`STORAGE-STRATEGY.md`](./STORAGE-STRATEGY.md)

### 8.1 Storage Architecture

```
Field Technician takes photo on mobile/desktop
         │
         ▼
Local device storage (temp file, not in SQLite)
         │
         ▼
Upload API: POST /files/upload
  - Streams directly to MinIO
  - Returns: { file_id, storage_url, thumbnail_url }
         │
         ▼
Application stores storage_url in Neon (work_order_photo.file_path)
         │
         ▼
Desktop sync: sync agent syncs the file_path metadata (not the file bytes)
Desktop offline: photo queued in a local pending_uploads table
         │
         ▼
When online: sync agent uploads queued files to MinIO, updates metadata in Neon
```

> **Decision:** Photos are **NOT stored as BLOBs in SQLite**. Only the file path/URL reference is stored. This avoids SQLite bloat and keeps the sync payload small.

### 8.2 Storage Backend Options

| Option | Use Case | Notes |
|--------|----------|-------|
| **MinIO** (primary) | On-premise S3-compatible storage | Run in Docker alongside services |
| **Supabase Storage** | Cloud fallback | Already available if staying in Supabase ecosystem |
| **Cloudflare R2** | Cloud alternative (no egress fees) | S3-compatible, swap MinIO URL |
| **AWS S3** | Enterprise-scale upgrade | Same S3 SDK, change endpoint |

The file upload service uses the **S3 SDK** regardless of backend. Switching storage requires only changing the endpoint URL and credentials.

### 8.3 File Organization (MinIO Buckets)

```
rg-workorder-photos/   → {property_id}/{work_order_id}/{filename}
rg-documents/          → {property_id}/{document_type}/{filename}
rg-exports/            → {report_type}/{period}/{filename}.pdf
rg-avatars/            → {user_id}/avatar.{ext}
```

---

## 9. API Design & Versioning

See full reference: [`API-DESIGN.md`](./API-DESIGN.md)

### 9.1 URL Structure

```
/api/v1/{service}/{resource}
```

All APIs are versioned from day one. The Next.js BFF exposes:
```
/api/v1/workorders/*   → Go service :8081
/api/v1/assets/*       → .NET service :8082
/api/v1/helpdesk/*     → Python service :8083
/api/v1/reports/*      → Ruby service :8084
```

When the API Gateway replaces the Next.js proxy, the URLs remain identical — only the internal routing changes.

### 9.2 Standard Response Envelope

All services return a consistent JSON envelope:
```json
{
  "data": { ... },
  "meta": {
    "request_id": "uuid",
    "timestamp": "ISO8601",
    "version": "1.0"
  },
  "error": null
}
```

Errors:
```json
{
  "data": null,
  "meta": { "request_id": "...", "timestamp": "..." },
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable message",
    "details": [ ... ]
  }
}
```

### 9.3 API Versioning Strategy

- **v1** — current active version
- **v2** — introduced when breaking changes are required (new fields are non-breaking, field removal/rename requires v2)
- Old versions maintained for 3 months after new version is stable
- Version advertised in response header: `X-API-Version: 1.0`

---

## 10. Observability & Operations

See full reference: [`OBSERVABILITY.md`](./OBSERVABILITY.md)

### 10.1 Structured Logging

Every service logs in **JSON format** (structured logging):
```json
{
  "level": "info",
  "service": "workorder-service",
  "request_id": "uuid",
  "user_id": "sub-from-jwt",
  "method": "POST",
  "path": "/workorders",
  "status": 201,
  "duration_ms": 42,
  "timestamp": "2026-08-04T18:00:00Z"
}
```

| Language | Log Library |
|----------|------------|
| Go | `zerolog` |
| C#/.NET | `Serilog` (JSON sink) |
| Python | `structlog` |
| Ruby | `semantic_logger` |

### 10.2 Health Checks

Every service exposes:
- `GET /health` → `{ "status": "ok", "db": "ok", "redis": "ok" }`
- `GET /ready` → used by Docker health check (`HEALTHCHECK` in Dockerfile)

Docker Compose `healthcheck` configuration ensures dependent services wait for dependencies.

### 10.3 Metrics (Future)

When scale demands it, add **Prometheus** + **Grafana** via Docker Compose:
- Each service exposes `/metrics` (Prometheus format)
- Grafana dashboards: SLA breach rate, API latency p99, queue depth, sync lag

### 10.4 Alerting

For early-stage: TeamCity build failures send email alerts.  
Later: Prometheus AlertManager → email/Slack/PagerDuty.

### 10.5 Backup Strategy

| Data | Backup Method | Frequency | Retention |
|------|--------------|-----------|-----------|
| Neon PostgreSQL | Neon built-in PITR (paid) or `pg_dump` + MinIO | Daily | 30 days |
| SQLite (desktop) | App auto-exports `.db` to a local backup folder | Weekly | 4 copies |
| MinIO files | MinIO bucket replication to a secondary folder or S3 | Daily | 90 days |
| Redis | RDB snapshot in Docker volume | On restart | Last 3 |

---

## 11. CI/CD Pipeline

See full reference: [`CICD-PIPELINE.md`](./CICD-PIPELINE.md)

### 11.1 TeamCity Build Configurations

| Build Config | Runner | Steps |
|-------------|--------|-------|
| `rg-workorder-service` | Go | lint → test → build → docker image |
| `rg-cmms-service` | .NET | restore → test → publish → docker image |
| `rg-helpdesk-service` | Python | pip install → pytest → docker image |
| `rg-report-engine` | Ruby | bundle → rspec → docker image |
| `rg-api-gateway` | Go | lint → test → build → docker image |
| `rg-sync-agent` | Go | lint → test → cross-compile (win64 + darwin-arm64) |
| `rg-fieldops-mobile` | Node (Expo EAS) | expo build → EAS submit |

### 11.2 Environment Variables (TeamCity Secrets)

| Variable | Used By |
|----------|---------|
| `NEON_URL` | All backend services |
| `REDIS_URL` | Go, Python services |
| `MINIO_ENDPOINT` | All services that upload files |
| `SUPABASE_JWT_SECRET` | API Gateway |
| `SUPABASE_PROJECT_URL` | API Gateway (JWKS endpoint) |

### 11.3 Docker Compose — Deployment

```yaml
# infrastructure/docker-compose.yml (summary)
services:
  api-gateway:    # Go :8080
  workorder:      # Go :8081
  cmms:           # .NET :8082
  helpdesk:       # Python :8083
  reports:        # Ruby :8084
  iot-gateway:    # C/C++ :8085
  redis:          # Redis :6379
  minio:          # MinIO :9000
  mosquitto:      # MQTT broker :1883
```

Neon is external (not in Docker Compose — it's cloud-hosted).

---

## 12. Scalability Plan

See full reference: [`SCALABILITY-PLAN.md`](./SCALABILITY-PLAN.md)

### 12.1 Neon Scaling

| Stage | Action |
|-------|--------|
| PoC (now) | Free tier — single compute endpoint |
| Growth | Upgrade to Neon Pro; enable auto-scaling compute (0.25–4 vCPU) |
| Scale | Enable read replicas for report-heavy workloads |
| Enterprise | Migrate to Neon Business or bare PostgreSQL on managed cloud (RDS, Cloud SQL) |

### 12.2 Service Scaling

All services are stateless (state lives in Neon/Redis). Scaling is:
1. **Docker Compose scale:** `docker compose up --scale workorder=3`
2. **Load balancer:** Add Nginx or Traefik in front of the API Gateway
3. **Kubernetes:** Migrate Docker Compose to Kubernetes manifests for cloud orchestration

### 12.3 Redis Scaling

| Stage | Action |
|-------|--------|
| PoC | Single Redis in Docker |
| Growth | Redis Cluster (3 nodes) in Docker or managed Redis (Upstash, Redis Cloud) |
| Scale | Redis Sentinel for high availability |

### 12.4 MinIO Scaling

| Stage | Action |
|-------|--------|
| PoC | Single MinIO node in Docker (local volume) |
| Growth | MinIO Distributed Mode (multi-drive) |
| Scale | Migrate to Cloudflare R2 or AWS S3 (same S3 SDK — change endpoint only) |

---

## 13. Alternatives Reference

See full reference: [`ALTERNATIVES.md`](./ALTERNATIVES.md)

| Component | Current Choice | Alternative A | Alternative B |
|-----------|--------------|--------------|--------------|
| Cloud DB | Neon PostgreSQL | PlanetScale (MySQL) | CockroachDB Serverless |
| Local DB | SQLite | LiteDB (.NET NoSQL) | DuckDB (analytics) |
| Auth | Supabase Auth | Neon Auth | Keycloak (self-hosted) |
| File Storage | MinIO | Cloudflare R2 | AWS S3 |
| Message Queue | Redis pub/sub | RabbitMQ | NATS |
| API Gateway | Custom Go | Kong | Traefik |
| Mobile | Flutter | React Native (Expo) | .NET MAUI |
| Desktop | Tauri (Rust+Web) | WPF (.NET) | Electron |
| PDF Reports | Ruby Prawn | WeasyPrint (Python) | Puppeteer (Node) |
| CI/CD | TeamCity | GitHub Actions | Jenkins |

---

## 14. Gaps — Fixed & Tracked

| Gap | Status | Resolution |
|-----|--------|-----------|
| Two plans out of sync | ✅ Fixed | This document is the single canonical plan |
| Photos as BLOBs in SQLite | ✅ Fixed | Photos stored in MinIO; only paths synced |
| SQLite sync mechanism underspecified | ✅ Fixed | Change-queue table with triggers (see §6) |
| Conflict resolution UI unplanned | ✅ Fixed | Dedicated Conflict Resolution Panel in desktop app |
| No migration plan (Supabase → Neon) | ✅ Fixed | pg_dump / pg_restore strategy (see §5.4) |
| No observability plan | ✅ Fixed | Structured logging, health checks, backup strategy (see §10) |
| No backup strategy | ✅ Fixed | Per-component backup table (see §10.5) |
| No API versioning | ✅ Fixed | /api/v1/ from day one, versioning strategy defined (see §9) |
| Desktop framework not chosen | ✅ Fixed | Tauri (primary) + WPF alternative (see §13) |
| Auth gap (Supabase DB dropped but Auth kept) | ✅ Fixed | Explicitly documented — Supabase kept for auth only (see §7) |

---

## 15. Future Roadmap

See full reference: [`FUTURE-ROADMAP.md`](./FUTURE-ROADMAP.md)

### Project 2 (Post-Project-1 Completion)
- **Multi-property portal** — manage multiple Raymond Gray properties under one platform
- **Tenant portal** — resident-facing mobile app with self-service requests and payment

### Future Feature Additions
- **AI-driven predictive maintenance** — ML model (Python/scikit-learn) predicting asset failure based on PPM history
- **Real IoT integration** — Arduino Uno → USB serial → MQTT bridge → IoT Gateway (replacing simulation)
- **Contract management** — vendor contracts, SLA agreement templates, auto-renewal alerts
- **Digital twin** — 2D floor plan with live sensor overlay (Three.js or Mapbox GL)
- **Financial analytics** — budget vs. actual tracking, cash flow forecasting
- **Inspection checklists** — mobile-driven daily/weekly property inspection workflows
- **Push notifications** — mobile/desktop push via Firebase Cloud Messaging
- **Audit trail** — immutable event log of all state changes (append-only table in Neon)
- **White-labeling** — multi-tenant SaaS version with per-tenant schemas in Neon

---

## 16. Directory Structure

```
C:\Projects\newskillsprojects\
│
├── docs/
│   ├── PROJECT-1-MASTER-PLAN.md         ← THIS FILE (canonical plan)
│   ├── ARCHITECTURE.md                  ← Detailed architecture diagrams
│   ├── DATA-LAYER.md                    ← Neon + SQLite full spec
│   ├── SYNC-ENGINE-SPEC.md              ← Sync agent + protocol spec
│   ├── AUTH-STRATEGY.md                 ← Auth + RBAC full spec
│   ├── STORAGE-STRATEGY.md             ← File/photo storage spec
│   ├── API-DESIGN.md                    ← API standards + versioning
│   ├── OBSERVABILITY.md                 ← Logging, monitoring, backup
│   ├── CICD-PIPELINE.md                 ← TeamCity build configs
│   ├── SCALABILITY-PLAN.md              ← Growth + migration paths
│   ├── ALTERNATIVES.md                  ← Technology alternatives reference
│   └── FUTURE-ROADMAP.md               ← Post-Project-1 vision
│
├── rg-workorder-service/                ← Go
│   ├── cmd/server/main.go
│   ├── internal/
│   │   ├── handler/
│   │   ├── domain/
│   │   ├── repository/
│   │   └── sync/
│   ├── migrations/
│   ├── Dockerfile
│   └── go.mod
│
├── rg-cmms-service/                     ← C#/.NET
│   ├── RgCmmsService/
│   ├── Dockerfile
│   └── RgCmmsService.sln
│
├── rg-helpdesk-service/                 ← Python
│   ├── app/
│   ├── alembic/
│   ├── Dockerfile
│   └── pyproject.toml
│
├── rg-report-engine/                    ← Ruby on Rails (API mode)
│   ├── app/
│   ├── db/
│   ├── Dockerfile
│   └── Gemfile
│
├── rg-api-gateway/                      ← Go
│   ├── cmd/gateway/main.go
│   ├── internal/
│   │   ├── proxy/
│   │   ├── auth/
│   │   ├── sync/
│   │   └── ratelimit/
│   ├── Dockerfile
│   └── go.mod
│
├── rg-sync-agent/                       ← Go (compiled to desktop binary)
│   ├── main.go
│   ├── internal/
│   │   ├── watcher/
│   │   ├── pusher/
│   │   └── conflict/
│   └── go.mod
│
├── rg-fieldops-mobile/                  ← Flutter
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
│
├── rg-desktop-windows/                  ← Tauri + React (Windows)
│   ├── src-tauri/
│   ├── src/
│   └── package.json
│
├── rg-iot-simulation/                   ← C/C++ or Go
│   ├── src/
│   └── CMakeLists.txt
│
└── infrastructure/
    ├── docker-compose.yml
    ├── docker-compose.dev.yml
    ├── init-schemas.sql
    ├── nginx/
    ├── minio/
    └── teamcity/
        └── build-configs/
```

---

## 17. Reference Documents

| Document | Purpose |
|----------|---------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Full architecture diagrams with sequence flows |
| [`DATA-LAYER.md`](./DATA-LAYER.md) | Neon schema designs, SQLite schema, migration plan |
| [`SYNC-ENGINE-SPEC.md`](./SYNC-ENGINE-SPEC.md) | Full sync protocol, conflict resolution, API contract |
| [`AUTH-STRATEGY.md`](./AUTH-STRATEGY.md) | JWT flow, RBAC matrix, Supabase auth configuration |
| [`STORAGE-STRATEGY.md`](./STORAGE-STRATEGY.md) | MinIO setup, file naming, upload flow, fallback options |
| [`API-DESIGN.md`](./API-DESIGN.md) | All API endpoints, request/response schemas, versioning |
| [`OBSERVABILITY.md`](./OBSERVABILITY.md) | Logging standards, health check contracts, backup runbooks |
| [`CICD-PIPELINE.md`](./CICD-PIPELINE.md) | TeamCity configs, Docker build steps, environment secrets |
| [`SCALABILITY-PLAN.md`](./SCALABILITY-PLAN.md) | Growth triggers, upgrade paths, Kubernetes migration guide |
| [`ALTERNATIVES.md`](./ALTERNATIVES.md) | Evaluated alternatives with trade-off analysis |
| [`FUTURE-ROADMAP.md`](./FUTURE-ROADMAP.md) | Post-Project-1 features, multi-tenant SaaS vision |
