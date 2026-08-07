# Desktop App — Architecture

> **Location:** `rg-desktop-windows/`
> **Stack:** Tauri 2.0 + React 18 + TypeScript + Vite + Rust + SQLite

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DESKTOP APP (Tauri)                       │
│                                                             │
│  ┌──────────────────────┐  ┌─────────────────────────────┐  │
│  │   React Frontend     │  │   Rust Backend (Tauri)      │  │
│  │   (TypeScript + Vite)│  │                             │  │
│  │                      │  │  • IPC Commands             │  │
│  │  • Views             │◄─┤  • SQLite (rusqlite)        │  │
│  │  • Components        │  │  • Sync Manager             │  │
│  │  • State (hooks)     │  │  • Auth (JWT in memory)     │  │
│  │  • Updater check     │  │  • Process management       │  │
│  └──────────┬───────────┘  └──────────┬──────────────────┘  │
│             │                         │                     │
│             │  Tauri IPC (invoke)     │                     │
│             └─────────────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ spawns child process
                    ▼
        ┌───────────────────────┐
        │  Go Sync Agent        │
        │  (rg-sync-agent.exe)  │
        │                       │
        │  • Reads _changes     │
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

## 2. Frontend Architecture (React + TypeScript)

### 2.1 Component Tree

```
App.tsx
├── Sidebar (navigation)
├── TopBar (sync status, user info, logout)
├── Views
│   ├── WorkOrdersView
│   ├── AssetsView
│   ├── HelpdeskView
│   ├── ConflictsView
│   ├── SettingsView
│   └── LoginView
└── Toast notifications
```

### 2.2 State Management

- **React hooks** (`useState`, `useCallback`, `useEffect`)
- **No external state library** — keeps the app lightweight
- **Polling** — sync status refreshed every 5 seconds
- **Auth state** — user info stored in React state, JWT in Rust memory

### 2.3 API Layer (`src/api.ts`)

All backend communication goes through Tauri IPC:

```typescript
// Example: list work orders
export function listWorkOrders(): Promise<WorkOrder[]> {
  return invoke("list_work_orders");
}
```

## 3. Rust Backend Architecture

### 3.1 Modules

| Module | Purpose |
|--------|---------|
| `main.rs` | Binary entry point |
| `lib.rs` | Tauri setup, plugin registration, command registration |
| `models.rs` | Data models (WorkOrder, Asset, HelpdeskRequest, etc.) |
| `db.rs` | SQLite layer (rusqlite) + change tracking |
| `sync.rs` | Sync agent lifecycle manager |
| `commands.rs` | IPC commands exposed to the frontend |

### 3.2 AppState

```rust
pub struct AppState {
    pub db: Arc<Database>,
    pub sync_manager: Arc<SyncManager>,
    pub auth_token: Arc<Mutex<Option<String>>>,  // JWT in memory
    pub user_info: Arc<Mutex<Option<UserInfo>>>, // Decoded user
}
```

### 3.3 IPC Commands

| Category | Commands |
|----------|----------|
| Work Orders | `list_work_orders`, `get_work_order`, `create_work_order`, `update_work_order`, `delete_work_order` |
| Assets | `list_assets`, `create_asset`, `delete_asset` |
| Helpdesk | `list_helpdesk_requests`, `create_helpdesk_request`, `delete_helpdesk_request` |
| Sync | `get_sync_status`, `set_gateway_url`, `get_conflicts`, `resolve_conflict`, `get_client_id`, `get_pending_changes`, `sync_now` |
| Auth | `set_auth_token`, `logout`, `get_user_info`, `get_auth_token` |

## 4. Data Layer (SQLite)

### 4.1 Tables

| Table | Purpose |
|-------|---------|
| `work_orders` | Work order records |
| `assets` | Equipment and building assets |
| `helpdesk_requests` | Resident requests and bookings |
| `_changes` | Change tracking for sync (per SYNC-ENGINE-SPEC) |
| `_conflicts` | Sync conflict records |
| `_meta` | Client ID, gateway URL, sync state |

### 4.2 Change Tracking

Every write is recorded in `_changes`:

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

## 5. Sync Architecture

### 5.1 Sync Manager (Rust)

- Spawns `rg-sync-agent.exe` as a child process on app start
- Restarts the agent if it crashes (with backoff)
- Stops the agent on app exit
- Reports agent status to the UI

### 5.2 Sync Agent (Go)

- Polls `_changes` for unsynced records
- Pushes to API gateway (`POST /sync/{service}`)
- Pulls remote changes and applies them locally
- Detects conflicts and stores them in `_conflicts`

### 5.3 Env Var Contract

| Desktop app passes | Sync agent reads | Purpose |
|--------------------|------------------|---------|
| `RG_GATEWAY_URL` | `RG_GATEWAY_URL` | API gateway base URL |
| `RG_DB_PATH` | `RG_DB_PATH` | Path to local.db |
| `RG_POLL_INTERVAL_MS` | `RG_POLL_INTERVAL_MS` | Sync poll interval |
| `RG_AUTH_TOKEN` | `RG_AUTH_TOKEN` | JWT for gateway auth |

## 6. Security

- **JWT stored in Rust memory** — never in localStorage (XSS protection)
- **Prepared statements** — all SQL uses parameterized queries
- **HTTPS only** — gateway URL validation (except localhost for dev)
- **Input validation** — all IPC commands validate required fields
- **Capabilities** — Tauri v2 permission system restricts IPC access

## 7. Update Mechanism

- **Tauri updater plugin** checks `latest.json` on GitHub Releases
- **Signature verification** — updates verified against embedded public key
- **Passive install** — silent install on Windows
- **Auto-relaunch** — app restarts after update