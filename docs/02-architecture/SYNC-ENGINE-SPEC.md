# Sync Engine Specification
## Raymond Gray IFM Platform

> **Parent:** [PROJECT-1-MASTER-PLAN.md](./PROJECT-1-MASTER-PLAN.md)  
> **Purpose:** Complete specification of the SQLite→Neon sync protocol, conflict resolution, and API contracts

---

## 1. Overview

The sync engine enables desktop clients (Windows/macOS) to operate **fully offline** and synchronize with the cloud (Neon PostgreSQL) when a network connection is available. It consists of three components:

| Component | Location | Technology |
|-----------|----------|-----------|
| **Change Tracker** | Desktop SQLite | SQLite triggers writing to `_changes` table |
| **Sync Agent** | Desktop (background process) | Go binary |
| **Sync API** | API Gateway + Services | Go HTTP handlers |

---

## 2. Change Tracking (SQLite Side)

### 2.1 _changes Table

Every application table in SQLite has AFTER INSERT/UPDATE/DELETE triggers that populate the `_changes` table:

```
_changes
├── id          AUTO INT        — local sequence ID
├── entity      TEXT            — table name (e.g., "work_order")
├── entity_id   TEXT            — UUID of the record
├── operation   TEXT            — INSERT | UPDATE | DELETE
├── payload     TEXT (JSON)     — only changed fields (diff)
├── client_id   TEXT            — unique device identifier (UUID stored in _config)
├── changed_at  TEXT (ISO8601)  — device local time in UTC
└── synced_at   TEXT (ISO8601)  — set by sync agent when server confirms; NULL = unsynced
```

### 2.2 Client ID Generation

On first app launch, the sync agent generates a unique client ID and stores it in `_config`:
```sql
CREATE TABLE _config (key TEXT PRIMARY KEY, value TEXT);
INSERT INTO _config (key, value)
    VALUES ('client_id', lower(hex(randomblob(16))));
```

This allows the server to distinguish concurrent edits from different devices.

### 2.3 Payload Strategy

The trigger payload captures **only the fields relevant to the operation** (not the full row on UPDATE). This minimises payload size and makes conflict detection precise:

```json
// INSERT: full record
{ "id": "...", "title": "...", "status": "open", "created_at": "..." }

// UPDATE: only changed fields + last_modified_at
{ "status": "complete", "completed_at": "2026-08-04T17:00:00Z", "last_modified_at": "2026-08-04T17:00:00Z" }

// DELETE: empty payload (entity_id is sufficient)
{}
```

---

## 3. Sync Agent (Go Binary)

### 3.1 Agent Lifecycle

```
App Start
  │
  ├─► Pull Sync: GET /sync/{service}?since=<last_pull_at>
  │     Apply incoming server changes to local SQLite
  │     Update _sync_state.last_pull_at
  │
  └─► Push Loop (every 500ms):
        Query _changes WHERE synced_at IS NULL LIMIT 50
        If records found:
          POST /sync/{service}
          On 200: mark records synced_at = now()
          On 207 (partial): mark successes, log failures
          On 409 (conflict): store in _conflicts, notify UI
        If no records: wait 500ms, repeat

App Foreground Resume:
  └─► Trigger immediate Pull Sync
```

### 3.2 Network Handling

```
No network:
  Agent silently queues changes in _changes table
  App operates normally on local SQLite
  Agent retries every 30 seconds until network restored

Network restored:
  Agent immediately runs Pull Sync then Push Loop
  Exponential backoff on server errors: 1s → 2s → 4s → 8s → max 60s
```

### 3.3 Agent Configuration

```go
// config.go
type SyncConfig struct {
    GatewayURL     string        // "https://api.raymondgray.local"
    DBPath         string        // "%APPDATA%/RaymondGray/local.db"
    PollInterval   time.Duration // 500ms
    BatchSize      int           // 50
    RetryMax       int           // 5
    JWTToken       string        // refreshed from app session
}
```

---

## 4. Sync API (Server Side)

### 4.1 Push Endpoint

**`POST /sync/{service}`**

- **Auth:** `Authorization: Bearer <supabase_jwt>`
- **Body:** JSON array of change records

Request:
```json
[
  {
    "entity": "work_order",
    "entity_id": "550e8400-e29b-41d4-a716-446655440000",
    "operation": "UPDATE",
    "payload": {
      "status": "complete",
      "completed_at": "2026-08-04T17:00:00Z",
      "last_modified_at": "2026-08-04T17:00:00Z"
    },
    "client_id": "a1b2c3d4e5f6",
    "changed_at": "2026-08-04T17:00:00Z"
  }
]
```

Response `200 OK` (all applied):
```json
{
  "results": [
    { "entity_id": "550e8400...", "result": "applied" }
  ]
}
```

Response `207 Multi-Status` (partial conflicts):
```json
{
  "results": [
    { "entity_id": "550e8400...", "result": "applied" },
    {
      "entity_id": "660f9500...",
      "result": "conflict",
      "server_record": {
        "id": "660f9500...",
        "status": "closed",
        "last_modified_at": "2026-08-04T18:00:00Z",
        "last_modified_by": "user-uuid"
      }
    }
  ]
}
```

### 4.2 Pull Endpoint

**`GET /sync/{service}?since=<ISO8601>`**

- **Auth:** `Authorization: Bearer <supabase_jwt>`
- **Query param:** `since` — ISO8601 timestamp of last successful pull

Response `200 OK`:
```json
{
  "changes": [
    {
      "entity": "work_order",
      "entity_id": "550e8400...",
      "operation": "UPDATE",
      "payload": { "status": "assigned", "assigned_to": "user-uuid" },
      "changed_at": "2026-08-04T17:30:00Z"
    }
  ],
  "server_time": "2026-08-04T18:00:00Z"
}
```

The client must update `_sync_state.last_pull_at` with `server_time` (not client clock).

### 4.3 Conflict Resolution Rules (Server)

```
For each incoming change:
  1. Fetch current record from Neon
  2. If record not found AND operation is INSERT → apply
  3. If record not found AND operation is UPDATE/DELETE → return "not_found" (client has stale data, trigger re-pull)
  4. If record found:
       incoming.changed_at > server.last_modified_at  → apply (client is newer)
       incoming.changed_at ≤ server.last_modified_at  → conflict (server is newer or equal)
  5. On conflict → return 207 with server_record
```

---

## 5. Conflict Resolution UI

### 5.1 Conflict Notification

The desktop app shows a **badge/indicator** in the top nav bar when unresolved conflicts exist. Clicking opens the Conflict Panel.

### 5.2 Conflict Panel Layout

```
┌─────────────────────────────────────────────────────────┐
│ ⚠️  2 Sync Conflicts Need Resolution                     │
├─────────────────────────────────────────────────────────┤
│ Work Order #WO-2456 — Status conflict                    │
│                                                          │
│  YOUR VERSION (offline change)   │  CLOUD VERSION        │
│  Status: Complete                │  Status: Closed       │
│  Changed: Aug 4, 17:00           │  Changed: Aug 4, 18:00│
│  Changed by: You                 │  Changed by: J. Smith │
│                                                          │
│  [Use Mine]    [Use Cloud]    [Open Record to Merge]     │
├─────────────────────────────────────────────────────────┤
│ Work Order #WO-2457 — Notes conflict                     │
│  ...                                                     │
└─────────────────────────────────────────────────────────┘
```

### 5.3 Resolution Actions

| Action | Behaviour |
|--------|-----------|
| **Use Mine** | Re-submit client payload to server with `force: true` flag → server applies regardless of timestamp |
| **Use Cloud** | Discard local change, update SQLite with server record, mark conflict resolved |
| **Open Record to Merge** | Open full record editor with both values visible; user manually edits and saves (treated as new change) |

### 5.4 Force Apply Endpoint

**`POST /sync/{service}/force`**

Same format as push endpoint but with `"force": true` per record. Server applies without conflict check. Server stamps `last_modified_by` with the client's user ID.

---

## 6. Services Supported by Sync

| Service | Entities Synced |
|---------|----------------|
| `workorders` | work_order, work_order_note, work_order_photo (metadata only) |
| `cmms` | asset, ppm_schedule, ppm_completion |
| `helpdesk` | resident_request, amenity_booking |

Reports and billing are **read-only** from the desktop (no offline writes).

---

## 7. Security Considerations

- All sync endpoints require a valid Supabase JWT (enforced at API Gateway)
- Client can only sync records belonging to their assigned `property_id` (enforced at service layer)
- `force: true` requires `facility_manager` or `admin` role (residents cannot force-override)
- All sync payloads are HTTPS only (TLS 1.3)
- Client IDs are opaque UUIDs — no PII
- `_changes` and `_conflicts` tables are excluded from any export/backup that the resident app can access
