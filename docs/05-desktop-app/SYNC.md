# Desktop App — Offline Sync & Conflict Resolution

> **Location:** `rg-desktop-windows/`
> **Mechanism:** Go sync agent + SQLite change tracking + API gateway

---

## 1. Overview

The desktop app is **offline-first**. All data is stored locally in SQLite. Every write is recorded in the `_changes` table. The Go sync agent (`rg-sync-agent`) polls for unsynced changes, pushes them to the API gateway, pulls remote changes, and detects conflicts.

## 2. Sync Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DESKTOP APP (Tauri)                       │
│                                                             │
│  ┌──────────────────────┐  ┌─────────────────────────────┐  │
│  │   React Frontend     │  │   Rust Backend              │  │
│  │                      │  │                             │  │
│  │  • CRUD operations   │◄─┤  • SQLite (rusqlite)        │  │
│  │  • Sync status UI    │  │  • Sync Manager (spawns)    │  │
│  │  • Conflict panel    │  │  • Change tracking          │  │
│  └──────────────────────┘  └──────────────┬──────────────┘  │
│                                           │                 │
└───────────────────────────────────────────┼─────────────────┘
                                            │ spawns child process
                                            ▼
                                ┌───────────────────────┐
                                │  Go Sync Agent        │
                                │  (rg-sync-agent.exe)  │
                                │                       │
                                │  • Polls _changes     │
                                │  • Pushes to gateway  │
                                │  • Pulls remote       │
                                │  • Detects conflicts  │
                                └───────────┬───────────┘
                                            │ HTTPS
                                            ▼
                                ┌───────────────────────┐
                                │  Go API Gateway       │
                                │  (:8080)              │
                                └───┬───────┬───────┬───┘
                                    │       │       │
                                    ▼       ▼       ▼
                                WorkOrder  CMMS   Helpdesk
                                (:8081)   (:8082)  (:8083)
```

## 3. Change Tracking

### 3.1 `_changes` Table

Every write operation (create, update, delete) is recorded:

```sql
CREATE TABLE _changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,        -- 'work_order', 'asset', 'helpdesk_request'
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL,     -- 'create', 'update', 'delete'
    payload TEXT NOT NULL,       -- JSON snapshot
    client_id TEXT NOT NULL,
    changed_at TEXT NOT NULL,
    synced_at TEXT
);
```

### 3.2 Write Flow

```
User creates work order
        │
        ▼
1. INSERT INTO work_orders (...)
        │
        ▼
2. INSERT INTO _changes (entity, entity_id, operation, payload, client_id, changed_at)
        │
        ▼
3. UI shows "Syncing..." indicator
        │
        ▼
4. Sync agent picks up the change on next poll
```

## 4. Sync Agent Lifecycle

### 4.1 Rust SyncManager

The Rust backend (`sync.rs`) manages the Go sync agent:

- **Start** — spawns `rg-sync-agent.exe` on app launch
- **Monitor** — checks if the process is running
- **Restart** — restarts with backoff if it crashes
- **Stop** — terminates on app exit

### 4.2 Env Var Contract

| Desktop app passes | Sync agent reads | Purpose |
|--------------------|------------------|---------|
| `RG_GATEWAY_URL` | `RG_GATEWAY_URL` | API gateway base URL |
| `RG_DB_PATH` | `RG_DB_PATH` | Path to local.db |
| `RG_POLL_INTERVAL_MS` | `RG_POLL_INTERVAL_MS` | Sync poll interval |
| `RG_AUTH_TOKEN` | `RG_AUTH_TOKEN` | JWT for gateway auth |

## 4. Sync Status

The UI shows a sync status indicator in the TopBar:

| Status | Indicator | Meaning |
|--------|-----------|---------|
| Connected | 🟢 Green dot | Agent running, no pending changes |
| Syncing | 🟡 Yellow dot | Pending changes being pushed |
| Offline | 🔴 Red dot | Agent not running or gateway unreachable |

The status is polled every 5 seconds via `get_sync_status` IPC command.

## 5. Conflict Detection & Resolution

### 5.1 How conflicts occur

When the same record is modified both locally (offline) and remotely (cloud), a conflict is detected:

```
Local:  WorkOrder #123 updated offline (status: "in_progress")
Cloud:  WorkOrder #123 updated remotely (status: "completed")
        │
        ▼
Sync agent detects mismatch → stores in _conflicts
```

### 5.2 Conflict UI

The ConflictsView shows each conflict with:

- **Your Version** — the local copy
- **Cloud Version** — the remote copy
- **Actions:**
  - **Use Mine** — keep the local version, push to cloud
  - **Use Cloud** — discard local, pull the cloud version
  - **Merge** — open the record to manually merge

### 5.3 Conflict Resolution Commands

| Command | Description |
|---------|-------------|
| `get_conflicts()` | List all unresolved conflicts |
| `resolve_conflict({ conflict_id, action })` | Resolve with `use_mine`, `use_cloud`, or `merge` |

## 6. Sync Agent Build

```powershell
powershell -File rg-sync-agent/build.ps1
```

This produces `rg-sync-agent/rg-sync-agent.exe`, which the desktop app finds automatically.

## 7. Gateway Configuration

In the desktop app's **Settings** view, set the **Gateway URL**:

- **Development:** `http://localhost:8080`
- **Production:** `https://api.raymond-gray.org`

The sync agent uses this URL to push changes.

## 8. Troubleshooting

| Issue | Fix |
|-------|-----|
| Sync agent not found | Build it: `powershell -File rg-sync-agent/build.ps1` |
| Gateway not reachable | Verify gateway is running on `:8080` |
| Conflicts not appearing | Check `_conflicts` table in local.db |
| Pending changes stuck | Check `_changes` table for `synced_at IS NULL` |