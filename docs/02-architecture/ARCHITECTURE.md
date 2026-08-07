# Architecture Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Detailed architecture diagrams, component interaction flows, and decision rationale

---

## 1. High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLIENT LAYER                                      │
│                                                                              │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │  Next.js Web │  │ Windows Desktop  │  │ macOS Desktop│  │ Mobile App  │  │
│  │  (Browser)   │  │ (Tauri + React) │  │ (Tauri)      │  │ (Flutter)   │  │
│  └──────┬───────┘  └────────┬────────┘  └──────┬───────┘  └──────┬──────┘  │
└─────────┼───────────────────┼──────────────────┼─────────────────┼─────────┘
          │ HTTPS             │ SQLite+Sync        │ SQLite+Sync      │ HTTPS
          │                   │ Agent              │ Agent            │
          ▼                   ▼                   ▼                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GO API GATEWAY  :8080                                │
│  • JWT validation (Supabase JWKS)                                            │
│  • Rate limiting (per user, per IP)                                          │
│  • Request routing                                                            │
│  • /sync/* endpoints for desktop agents                                      │
│  • Structured request logging                                                 │
└───┬───────────┬───────────┬───────────┬───────────┬──────────────────────┘
    │           │           │           │           │
    ▼           ▼           ▼           ▼           ▼
┌───────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
│  Go   │  │  .NET  │  │ Python │  │  Ruby  │  │  C/C++ │
│ Work  │  │ Asset  │  │ Help-  │  │ Report │  │  IoT   │
│ Order │  │  CMMS  │  │ desk   │  │ Engine │  │  Sim   │
│ :8081 │  │ :8082  │  │ :8083  │  │ :8084  │  │ :8085  │
└───┬───┘  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘
    │          │           │           │            │
    └──────────┴───────────┴───────────┴────────────┘
                           │
          ┌────────────────┼──────────────────────┐
          ▼                ▼                      ▼
   ┌──────────────┐  ┌──────────┐        ┌──────────────┐
   │ NEON         │  │  REDIS   │        │    MINIO     │
   │ PostgreSQL   │  │ :6379    │        │    :9000     │
   │ (Cloud)      │  │          │        │  (Files)     │
   │              │  │ SLA tmrs │        │              │
   │ workorders   │  │ pub/sub  │        │ photos/docs  │
   │ cmms         │  │ cache    │        │ exports      │
   │ helpdesk     │  └──────────┘        └──────────────┘
   │ reports      │
   │ auth_bridge  │
   └──────────────┘
          ▲
          │ MQTT
   ┌──────────────┐
   │  MOSQUITTO   │
   │  MQTT Broker │
   │  :1883       │
   └──────────────┘
          ▲
          │
   ┌──────────────┐
   │ IoT Sensors  │
   │ (simulated   │
   │  or Arduino  │
   │  in future)  │
   └──────────────┘
```

---

## 2. Request Flow: Web Client → Work Order Create

```
Browser → POST /api/v1/workorders
  │
  ▼
Next.js API Route (/api/v1/workorders/[...path].ts)
  │ proxies to
  ▼
Go API Gateway :8080
  │ validates JWT (Supabase JWKS)
  │ extracts user_id, roles → X-User-ID, X-User-Roles headers
  ▼
Go Work Order Service :8081
  │ validates X-User-Roles (must include facility_manager or admin)
  │ inserts into workorders.work_order (Neon)
  │ publishes Redis event: "workorder.created"
  │ triggers SLA timer goroutine
  ▼
Response: 201 Created { data: { id, ... }, meta: { request_id, timestamp } }
  │
  ▼
Browser receives response
  │
  (meanwhile)
  ▼
WebSocket subscribers receive live update (if any dashboard is open)
```

---

## 3. Request Flow: Desktop Sync Agent → Cloud

```
Field technician updates Work Order offline on desktop
  │
  ▼
SQLite trigger fires → inserts into _changes table
  { entity: "work_order", entity_id: "...", operation: "UPDATE",
    payload: { status: "complete", completed_at: "..." }, changed_at: "now" }
  │
  ▼
Go Sync Agent (background goroutine, polls every 500ms)
  │ finds unsynced rows in _changes WHERE synced_at IS NULL
  │ batches up to 50 records
  ▼
POST /sync/workorders  (to API Gateway)
  Authorization: Bearer <jwt>
  Body: [ { entity_id, operation, payload, client_id, changed_at }, ... ]
  │
  ▼
API Gateway validates JWT → forwards to Go Work Order Service sync handler
  │
  ▼
Work Order Service:
  for each change:
    if incoming.changed_at > current.last_modified_at:
      → apply change to Neon (INSERT/UPDATE/DELETE)
      → return { entity_id: "...", result: "applied" }
    else:
      → return { entity_id: "...", result: "conflict",
                  server_record: { ... current Neon record ... } }
  │
  ▼
Sync agent on success:
  → marks _changes.synced_at = now()
Sync agent on conflict:
  → stores in _conflicts table
  → desktop app shows conflict notification badge
```

---

## 4. IoT Event Flow: Sensor → Work Order

```
IoT Simulation (C/C++ process)
  │ generates sensor reading (e.g., temperature > threshold)
  ▼
MQTT PUBLISH: "sensors/building-1/temperature"
  payload: { sensor_id: "T-101", value: 38.5, threshold: 35.0, unit: "C" }
  │
  ▼
Eclipse Mosquitto MQTT Broker (:1883)
  │
  ▼
Go Work Order Service (MQTT subscriber)
  │ receives message on "sensors/#"
  │ evaluates against alert rules
  ▼
Auto-creates Emergency Work Order in Neon:
  { title: "High temperature alert: Building 1",
    priority: "emergency", category: "hvac",
    source: "iot", sensor_id: "T-101" }
  │ publishes Redis event
  │ notifies WebSocket subscribers (dashboard live alert)
  ▼
Field Technician receives push notification on mobile
```

---

## 5. Report Generation Flow

```
Manager requests Monthly Report via dashboard
  │
  ▼
Next.js → GET /api/v1/reports/monthly?period=2026-07
  │
  ▼
API Gateway → Ruby Report Engine :8084
  │ queries Neon read-only views:
  │   reports.v_work_order_summary    (from workorders schema)
  │   reports.v_ppm_compliance        (from cmms schema)
  │   reports.v_resident_satisfaction  (from helpdesk schema)
  │   reports.v_billing_summary       (from cmms billing tables)
  ▼
Ruby assembles report data
  │ generates PDF using Prawn gem
  │ uploads PDF to MinIO: rg-exports/monthly/2026-07/report.pdf
  ▼
Returns: { data: { report_url: "minio://...", generated_at: "..." } }
  │
  ▼
Manager downloads PDF from MinIO signed URL
```

---

## 6. Authentication Sequence Diagram

```
Browser                Supabase Auth         API Gateway         Service
   │                       │                     │                   │
   │── POST /auth/signin ──►│                     │                   │
   │◄── JWT (access_token)─│                     │                   │
   │                       │                     │                   │
   │── GET /api/v1/workorders ──────────────────►│                   │
   │   Authorization: Bearer <jwt>               │                   │
   │                       │                     │                   │
   │                       │◄── GET /.well-known/jwks.json (once, cached)
   │                       │                     │                   │
   │                       │                     │ verify sig        │
   │                       │                     │ extract sub,roles │
   │                       │                     │                   │
   │                       │                     │── X-User-ID ─────►│
   │                       │                     │── X-User-Roles ──►│
   │                       │                     │                   │
   │                       │                     │                   │ authorize
   │                       │                     │                   │ query Neon
   │◄──────────────────────────────────────── 200 OK ───────────────│
```

---

## 7. Phase Architecture Evolution

### Phase 1–3: BFF Proxy (Next.js routes)
```
Browser → Next.js → /api/v1/workorders → Go :8081
                 → /api/v1/assets    → .NET :8082
                 → /api/v1/helpdesk  → Python :8083
```

### Phase 4+: API Gateway
```
Browser → API Gateway :8080 → Go :8081
                            → .NET :8082
                            → Python :8083
                            → Ruby :8084
```

### Scale Path: Kubernetes
```
Internet → Load Balancer → API Gateway (3 replicas) → Services (2-5 replicas each)
                                                     → Neon (with read replicas)
```

---

## 8. Desktop Application Architecture

```
┌──────────────────────────────────────────────────────┐
│             Desktop App (Tauri + React)               │
│                                                       │
│  ┌─────────────────┐    ┌──────────────────────────┐ │
│  │   React UI      │    │   Tauri Rust Backend      │ │
│  │   (renderer)    │    │                           │ │
│  │                 │    │  ┌──────────────────────┐ │ │
│  │  Work Orders    │◄──►│  │  SQLite local.db     │ │ │
│  │  Assets         │    │  │  (via rusqlite)       │ │ │
│  │  Helpdesk       │    │  └──────────────────────┘ │ │
│  │  Conflict Panel │    │                           │ │
│  └─────────────────┘    └──────────┬────────────────┘ │
│                                    │                   │
└────────────────────────────────────┼───────────────────┘
                                     │ spawns
                                     ▼
                          ┌──────────────────────┐
                          │  Go Sync Agent       │
                          │  (separate process)  │
                          │                      │
                          │  Watches _changes    │
                          │  POST /sync/*        │
                          │  Handles conflicts   │
                          └──────────────────────┘
                                     │ HTTPS
                                     ▼
                          API Gateway :8080
```

> **Alternative desktop framework:** If Tauri is not preferred, WPF (.NET 8 on Windows) or Electron (cross-platform, heavier) are documented in `ALTERNATIVES.md`.
