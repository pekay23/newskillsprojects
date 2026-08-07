# Data Layer Reference
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Complete specification of all database schemas, migration strategy, sync tables, and data access patterns

---

## 1. Neon PostgreSQL — Cloud Primary Store

### 1.1 Connection

```bash
# .env (all services)
NEON_URL=postgresql://<user>:<password>@<project-id>.neon.tech/<database>?sslmode=require

# Per-service search_path configuration (set on connection pool init):
# Go (pgx):     conn.Exec(ctx, "SET search_path = workorders, public")
# .NET (EF):    modelBuilder.HasDefaultSchema("cmms")
# Python (SA):  engine = create_engine(NEON_URL, connect_args={"options": "-c search_path=helpdesk,public"})
# Ruby (Rails): schema_search_path: "reports,public"
```

### 1.2 Neon Branching Strategy

| Branch | Purpose | Connection |
|--------|---------|-----------|
| `main` | Production data | Used by production Docker Compose |
| `dev` | Development — reset freely | Used by local development |
| `staging` | Pre-production testing | Used by TeamCity staging pipeline |
| `feature/*` | Short-lived per-feature testing | Created/deleted per PR |

```bash
# Create a dev branch (Neon CLI)
neon branch create --name dev --parent main
neon branch create --name staging --parent main
```

---

## 2. Schema: `workorders`

```sql
CREATE SCHEMA IF NOT EXISTS workorders;
SET search_path = workorders, public;

-- SLA Policies
CREATE TABLE sla_policy (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    priority_level  VARCHAR(20) NOT NULL UNIQUE,  -- emergency, high, medium, low
    response_hours  INTEGER NOT NULL,
    resolution_hours INTEGER NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO sla_policy (priority_level, response_hours, resolution_hours) VALUES
    ('emergency', 1, 4),
    ('high', 4, 24),
    ('medium', 24, 72),
    ('low', 72, 168);

-- Work Orders
CREATE TABLE work_order (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(500) NOT NULL,
    description     TEXT,
    category        VARCHAR(50) NOT NULL,  -- electrical, plumbing, hvac, general, safety
    priority        VARCHAR(20) NOT NULL REFERENCES sla_policy(priority_level),
    status          VARCHAR(30) NOT NULL DEFAULT 'open',
                    -- open, assigned, in_progress, pending_parts, complete, closed, cancelled
    property_id     UUID,
    asset_id        UUID,  -- references cmms.asset.id (cross-schema)
    assigned_to     UUID,  -- user UUID from Supabase auth
    reported_by     UUID,  -- user UUID from Supabase auth
    source          VARCHAR(20) DEFAULT 'manual',  -- manual, resident_request, iot, ppm
    source_ref_id   UUID,  -- references helpdesk.resident_request.id if source=resident_request
    sla_response_due TIMESTAMPTZ,
    sla_resolve_due  TIMESTAMPTZ,
    sla_response_met BOOLEAN,
    sla_resolve_met  BOOLEAN,
    completed_at    TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_modified_at TIMESTAMPTZ DEFAULT NOW(),
    last_modified_by UUID
);

CREATE INDEX idx_wo_status ON work_order(status);
CREATE INDEX idx_wo_property ON work_order(property_id);
CREATE INDEX idx_wo_assigned ON work_order(assigned_to);
CREATE INDEX idx_wo_created ON work_order(created_at DESC);

-- Work Order Notes
CREATE TABLE work_order_note (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id   UUID NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    author_id       UUID NOT NULL,
    content         TEXT NOT NULL,
    is_internal     BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Work Order Photos (references MinIO paths, no BLOBs)
CREATE TABLE work_order_photo (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id   UUID NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    uploaded_by     UUID NOT NULL,
    file_path       TEXT NOT NULL,   -- MinIO path: rg-workorder-photos/{property}/{wo_id}/{filename}
    thumbnail_path  TEXT,
    file_size_bytes BIGINT,
    mime_type       VARCHAR(100),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- SLA Breach Audit Log
CREATE TABLE sla_breach_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id   UUID NOT NULL REFERENCES work_order(id),
    breach_type     VARCHAR(20) NOT NULL,  -- response, resolution
    due_at          TIMESTAMPTZ NOT NULL,
    breached_at     TIMESTAMPTZ DEFAULT NOW(),
    escalated_to    UUID
);

-- Desktop Sync Changes Table (per-service)
CREATE TABLE _changes (
    id              BIGSERIAL PRIMARY KEY,
    entity          VARCHAR(100) NOT NULL,
    entity_id       UUID NOT NULL,
    operation       VARCHAR(10) NOT NULL,  -- INSERT, UPDATE, DELETE
    payload         JSONB NOT NULL,
    client_id       VARCHAR(100) NOT NULL, -- unique per desktop device
    changed_at      TIMESTAMPTZ NOT NULL,
    synced_at       TIMESTAMPTZ,           -- NULL = not yet confirmed
    conflict_at     TIMESTAMPTZ            -- set if server rejected this change
);

CREATE INDEX idx_changes_unsynced ON _changes(synced_at) WHERE synced_at IS NULL;
```

---

## 3. Schema: `cmms`

```sql
CREATE SCHEMA IF NOT EXISTS cmms;
SET search_path = cmms, public;

-- Properties
CREATE TABLE property (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(200) NOT NULL,
    address         TEXT NOT NULL,
    type            VARCHAR(50),  -- residential, commercial, mixed
    total_units     INTEGER,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_modified_at TIMESTAMPTZ DEFAULT NOW()
);

-- Assets
CREATE TABLE asset (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id     UUID NOT NULL REFERENCES property(id),
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(100) NOT NULL,  -- hvac, electrical, plumbing, elevator, generator
    sub_category    VARCHAR(100),
    manufacturer    VARCHAR(100),
    model           VARCHAR(100),
    serial_number   VARCHAR(100),
    installation_date DATE,
    warranty_expiry DATE,
    status          VARCHAR(30) DEFAULT 'active',  -- active, maintenance, decommissioned
    location_floor  VARCHAR(20),
    location_room   VARCHAR(100),
    purchase_cost   NUMERIC(12,2),
    current_value   NUMERIC(12,2),
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_modified_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_asset_property ON asset(property_id);
CREATE INDEX idx_asset_status ON asset(status);

-- PPM Schedules
CREATE TABLE ppm_schedule (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id        UUID NOT NULL REFERENCES asset(id),
    task_name       VARCHAR(200) NOT NULL,
    frequency       VARCHAR(20) NOT NULL,  -- daily, weekly, monthly, quarterly, annual
    assigned_to     UUID,                  -- technician user ID
    next_due        DATE NOT NULL,
    last_completed  DATE,
    is_active       BOOLEAN DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- PPM Completions
CREATE TABLE ppm_completion (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id     UUID NOT NULL REFERENCES ppm_schedule(id),
    completed_by    UUID NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL,
    condition_found VARCHAR(30),  -- good, fair, poor, defective
    notes           TEXT,
    work_order_id   UUID,         -- references workorders.work_order.id if WO was raised
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Unit Billing
CREATE TABLE unit_billing (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id     UUID NOT NULL REFERENCES property(id),
    unit_number     VARCHAR(20) NOT NULL,
    unit_owner_id   UUID,
    period          VARCHAR(7) NOT NULL,  -- YYYY-MM
    amount          NUMERIC(10,2) NOT NULL,
    billing_type    VARCHAR(30) NOT NULL,  -- hoa_fee, reserve_fund, special_assessment, late_fee
    status          VARCHAR(20) DEFAULT 'pending',  -- pending, paid, overdue, waived
    due_date        DATE,
    paid_at         TIMESTAMPTZ,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_modified_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_billing_period ON unit_billing(period);
CREATE INDEX idx_billing_status ON unit_billing(status);
```

---

## 4. Schema: `helpdesk`

```sql
CREATE SCHEMA IF NOT EXISTS helpdesk;
SET search_path = helpdesk, public;

-- Resident Requests
CREATE TABLE resident_request (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id     UUID NOT NULL,
    unit_number     VARCHAR(20) NOT NULL,
    resident_id     UUID NOT NULL,
    category        VARCHAR(50) NOT NULL,  -- maintenance, noise, amenity, billing, general
    description     TEXT NOT NULL,
    status          VARCHAR(30) DEFAULT 'open',  -- open, in_review, in_progress, resolved, closed
    linked_wo_id    UUID,                         -- set when a work order is created
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    last_modified_at TIMESTAMPTZ DEFAULT NOW()
);

-- Amenities
CREATE TABLE amenity (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id     UUID NOT NULL,
    name            VARCHAR(100) NOT NULL,
    capacity        INTEGER DEFAULT 1,
    advance_days    INTEGER DEFAULT 7,  -- how far ahead can be booked
    is_active       BOOLEAN DEFAULT TRUE
);

-- Amenity Bookings
CREATE TABLE amenity_booking (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id      UUID NOT NULL REFERENCES amenity(id),
    property_id     UUID NOT NULL,
    unit_number     VARCHAR(20) NOT NULL,
    resident_id     UUID NOT NULL,
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) DEFAULT 'confirmed',  -- confirmed, cancelled, no_show
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT no_booking_overlap EXCLUDE USING gist (
        amenity_id WITH =,
        tstzrange(start_time, end_time) WITH &&
    )
);

-- Surveys
CREATE TABLE survey (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id     UUID NOT NULL,
    title           VARCHAR(200) NOT NULL,
    period          VARCHAR(7) NOT NULL,  -- YYYY-MM
    questions       JSONB NOT NULL,       -- array of question objects
    status          VARCHAR(20) DEFAULT 'draft',  -- draft, active, closed
    sent_at         TIMESTAMPTZ,
    closed_at       TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Survey Responses
CREATE TABLE survey_response (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    survey_id       UUID NOT NULL REFERENCES survey(id),
    unit_number     VARCHAR(20) NOT NULL,
    resident_id     UUID NOT NULL,
    answers         JSONB NOT NULL,
    sentiment_score NUMERIC(4,2),  -- computed by spaCy NLP (-1.0 to 1.0)
    keywords        TEXT[],        -- extracted by spaCy
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. Schema: `reports`

```sql
CREATE SCHEMA IF NOT EXISTS reports;
SET search_path = reports, public;

-- Materialized cross-schema views (refreshed on schedule)
CREATE MATERIALIZED VIEW v_work_order_summary AS
SELECT
    wo.id,
    wo.title,
    wo.category,
    wo.priority,
    wo.status,
    wo.property_id,
    wo.sla_response_met,
    wo.sla_resolve_met,
    wo.created_at,
    wo.completed_at,
    EXTRACT(EPOCH FROM (wo.completed_at - wo.created_at))/3600 AS resolution_hours
FROM workorders.work_order wo;

CREATE MATERIALIZED VIEW v_ppm_compliance AS
SELECT
    s.id AS schedule_id,
    s.asset_id,
    a.property_id,
    a.name AS asset_name,
    s.task_name,
    s.frequency,
    s.next_due,
    s.last_completed,
    CASE WHEN s.next_due < CURRENT_DATE THEN FALSE ELSE TRUE END AS is_compliant
FROM cmms.ppm_schedule s
JOIN cmms.asset a ON a.id = s.asset_id
WHERE s.is_active = TRUE;

CREATE MATERIALIZED VIEW v_resident_satisfaction AS
SELECT
    r.property_id,
    r.period,
    COUNT(*) AS response_count,
    AVG(r.sentiment_score) AS avg_sentiment,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY r.sentiment_score) AS median_sentiment
FROM helpdesk.survey_response r
JOIN helpdesk.survey s ON s.id = r.survey_id
GROUP BY r.property_id, r.period;

-- Generated Report Records (metadata only)
CREATE TABLE generated_report (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type     VARCHAR(50) NOT NULL,  -- monthly_ops, quarterly_review, annual_summary
    property_id     UUID NOT NULL,
    period          VARCHAR(7) NOT NULL,
    file_path       TEXT NOT NULL,         -- MinIO path
    generated_by    UUID,
    generated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. Schema: `auth_bridge`

```sql
CREATE SCHEMA IF NOT EXISTS auth_bridge;
SET search_path = auth_bridge, public;

-- Local cache of Supabase user data (synced on login)
-- Avoids cross-service calls to Supabase for user display names etc.
CREATE TABLE users (
    id          UUID PRIMARY KEY,   -- matches Supabase auth.users.id
    email       VARCHAR(255) UNIQUE NOT NULL,
    full_name   VARCHAR(200),
    role        VARCHAR(30) NOT NULL DEFAULT 'resident',
    property_id UUID,               -- primary property assignment
    unit_number VARCHAR(20),        -- for resident users
    is_active   BOOLEAN DEFAULT TRUE,
    synced_at   TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 7. SQLite — Desktop Local Schema

Each desktop client has a local `local.db` SQLite file that mirrors the subset of data the user needs offline.

```sql
-- Mirrors subset of workorders.work_order
CREATE TABLE work_order (
    id              TEXT PRIMARY KEY,
    title           TEXT NOT NULL,
    description     TEXT,
    category        TEXT NOT NULL,
    priority        TEXT NOT NULL,
    status          TEXT NOT NULL,
    property_id     TEXT,
    asset_id        TEXT,
    assigned_to     TEXT,
    completed_at    TEXT,
    created_at      TEXT NOT NULL,
    last_modified_at TEXT NOT NULL,
    _synced         INTEGER DEFAULT 0  -- 0 = local-only, 1 = synced to cloud
);

-- Change tracking queue
CREATE TABLE _changes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    entity      TEXT NOT NULL,
    entity_id   TEXT NOT NULL,
    operation   TEXT NOT NULL,   -- INSERT, UPDATE, DELETE
    payload     TEXT NOT NULL,   -- JSON string
    client_id   TEXT NOT NULL,
    changed_at  TEXT NOT NULL,   -- ISO8601 string
    synced_at   TEXT             -- NULL until confirmed
);

-- Conflict store
CREATE TABLE _conflicts (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    change_id       INTEGER REFERENCES _changes(id),
    entity          TEXT NOT NULL,
    entity_id       TEXT NOT NULL,
    client_payload  TEXT NOT NULL,  -- JSON — what client tried to write
    server_payload  TEXT NOT NULL,  -- JSON — what server currently has
    detected_at     TEXT NOT NULL,
    resolved_at     TEXT,           -- NULL until user resolves
    resolution      TEXT            -- 'use_client' | 'use_server' | 'merged'
);

-- Sync state
CREATE TABLE _sync_state (
    service         TEXT PRIMARY KEY,
    last_pull_at    TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z'
);

INSERT INTO _sync_state (service) VALUES
    ('workorders'), ('cmms'), ('helpdesk');

-- Pending file uploads
CREATE TABLE _pending_uploads (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    local_file_path TEXT NOT NULL,     -- absolute path on device
    target_bucket   TEXT NOT NULL,     -- MinIO bucket
    target_key      TEXT NOT NULL,     -- MinIO object key
    entity          TEXT NOT NULL,     -- which entity this file belongs to
    entity_id       TEXT NOT NULL,     -- UUID
    uploaded_at     TEXT               -- NULL until complete
);
```

SQLite Triggers (example for work_order):
```sql
CREATE TRIGGER trg_wo_insert AFTER INSERT ON work_order
BEGIN
    INSERT INTO _changes (entity, entity_id, operation, payload, client_id, changed_at)
    VALUES (
        'work_order',
        NEW.id,
        'INSERT',
        json_object(
            'title', NEW.title,
            'description', NEW.description,
            'category', NEW.category,
            'priority', NEW.priority,
            'status', NEW.status,
            'last_modified_at', NEW.last_modified_at
        ),
        (SELECT value FROM _config WHERE key = 'client_id'),
        datetime('now')
    );
END;

CREATE TRIGGER trg_wo_update AFTER UPDATE ON work_order
BEGIN
    INSERT INTO _changes (entity, entity_id, operation, payload, client_id, changed_at)
    VALUES (
        'work_order',
        NEW.id,
        'UPDATE',
        json_object(
            'title', NEW.title,
            'status', NEW.status,
            'completed_at', NEW.completed_at,
            'last_modified_at', NEW.last_modified_at
        ),
        (SELECT value FROM _config WHERE key = 'client_id'),
        datetime('now')
    );
END;
```

---

## 8. Data Migration: Supabase → Neon

If the existing Next.js application has live data in Supabase PostgreSQL:

### Step 1: Export from Supabase
```bash
# Supabase provides a direct pg_dump-compatible export
pg_dump "postgresql://<supabase-connection-string>" \
  --no-owner --no-acl \
  --schema=public \
  -f supabase_export.sql
```

### Step 2: Import into Neon (dev branch first)
```bash
psql "postgresql://<neon-dev-branch-url>" \
  -f supabase_export.sql
```

### Step 3: Validate
```sql
-- Compare row counts
SELECT table_name, (xpath('/row/c/text()', xmlelement(name root, xmlforest(COUNT(*) AS c))))[1]::TEXT::INTEGER AS row_count
FROM information_schema.tables
WHERE table_schema = 'public'
GROUP BY table_name;
```

### Step 4: Update Next.js Prisma Connection
```bash
# .env.local (Next.js)
DATABASE_URL=postgresql://<neon-url>?sslmode=require&pgbouncer=true
DIRECT_URL=postgresql://<neon-url>?sslmode=require
```

### Step 5: Test on staging branch → promote to main
