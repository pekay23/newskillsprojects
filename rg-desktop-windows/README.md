# Raymond Gray IFM — Desktop App

The Tauri desktop application for the Raymond Gray IFM platform. Provides **offline-first** facility management for field technicians and facility managers, syncing with the cloud via the Go sync agent.

## Stack

- **Frontend:** React 18 + TypeScript + Vite
- **Backend shell:** Tauri v2 (Rust)
- **Local storage:** SQLite (via `rusqlite`, bundled)
- **Sync:** Go sync agent (`rg-sync-agent`) spawned as a child process

## Features

- **Work Orders** — create, edit, update status, delete (offline-capable)
- **Assets** — track equipment and building assets
- **Helpdesk** — resident requests and amenity bookings
- **Sync Conflicts** — resolve offline/cloud conflicts (Use Mine / Use Cloud / Merge)
- **Settings** — configure API gateway URL, view sync status and pending changes queue

## Prerequisites

Tauri requires the **Rust toolchain** to compile the native backend shell:

1. [Node.js](https://nodejs.org/) (installed)
2. [Rust](https://rustup.rs/) — **required for Tauri** (install via rustup)
3. C++ Build Tools (on Windows, via Visual Studio Build Tools)

## Running Locally

```bash
npm install
npm run tauri dev
```

## Building

```bash
npm run build          # TypeScript + Vite production build
npm run tauri build    # Full Tauri desktop bundle (requires Rust)
```

## Project Structure

```
rg-desktop-windows/
├── index.html              # Vite entry
├── package.json
├── tsconfig.json
├── vite.config.ts
├── scripts/
│   └── generate-icon.cjs   # Generates RG-branded icon source PNG
├── src/                    # React + TypeScript frontend
│   ├── api.ts              # Tauri IPC wrappers
│   ├── types.ts            # Shared TypeScript types
│   ├── App.tsx             # App shell (sidebar + topbar + routing)
│   ├── styles.css          # RG design system
│   ├── components/         # Sidebar, TopBar, Modal, Badge, EmptyState
│   └── views/              # WorkOrders, Assets, Helpdesk, Conflicts, Settings
└── src-tauri/              # Rust backend
    ├── Cargo.toml
    ├── build.rs
    ├── tauri.conf.json     # Tauri v2 config
    ├── capabilities/       # Tauri v2 permissions
    ├── icons/              # Generated RG-branded icons
    └── src/
        ├── main.rs         # Binary entry
        ├── lib.rs          # Tauri setup + command registration
        ├── models.rs       # Data models (mirror backend services)
        ├── db.rs           # SQLite layer (rusqlite) + change tracking
        ├── sync.rs         # Sync agent lifecycle manager
        └── commands.rs     # IPC commands exposed to the frontend
```

## Sync Architecture

The desktop app writes to a local SQLite database. Every write is recorded in the `_changes` table (per the Sync Engine Spec). The Rust backend spawns the Go sync agent (`rg-sync-agent`) as a child process, which:

- Polls `_changes` for unsynced records
- Pushes them to the API gateway (`POST /sync/{service}`)
- Pulls remote changes and applies them locally
- Detects conflicts and stores them in `_conflicts`

The UI shows a sync status indicator (Connected / Syncing / Offline) and a conflict badge when unresolved conflicts exist.

## API Gateway Integration

The desktop app syncs through the **Go API Gateway** (`rg-api-gateway`), which routes to the backend services. The original `raymond-gray-platform` project is **never modified**.

### Data flow

```
Desktop App (Tauri/Rust)
  └─ spawns → Go Sync Agent (rg-sync-agent.exe)
                └─ reads local.db _changes table
                └─ POST /sync/{service} → API Gateway (:8080)
                                          ├─ /sync/workorders → Work Order Service
                                          ├─ /sync/cmms       → CMMS Service
                                          └─ /sync/helpdesk   → Helpdesk Service
```

### Building the sync agent

```powershell
powershell -File rg-sync-agent/build.ps1
```

This produces `rg-sync-agent/rg-sync-agent.exe`, which the desktop app finds automatically.

### Running the gateway

A pre-built `rg-api-gateway.exe` is included. To run it (from PowerShell or CMD):

```powershell
cd rg-api-gateway
.\rg-api-gateway.exe
```

Or rebuild from source (requires Go):

```bash
cd rg-api-gateway
go run ./cmd/gateway
# or: go build -o rg-api-gateway.exe ./cmd/gateway && .\rg-api-gateway.exe
```

> **Note:** In PowerShell, prefix the binary with `.\` (e.g. `.\rg-api-gateway.exe`), and if rebuilding use `go run ./cmd/gateway` — `run` alone is not a command.

The gateway listens on `:8080` by default. Configure backend service URLs via env vars:
- `WORKORDER_URL` (e.g. `http://localhost:8081`)
- `CMMS_URL` (e.g. `http://localhost:8082`)
- `HELPDESK_URL` (e.g. `http://localhost:8083`)
- `REPORTS_URL` (e.g. `http://localhost:8084`)
- `NEXTAUTH_SECRET` (for JWT auth — validates NextAuth v5 session tokens from the platform)

> **Auth note:** The original `raymond-gray-platform` migrated from Supabase to **NextAuth v5 (JWT strategy) backed by Neon PostgreSQL via Prisma**. The gateway validates NextAuth JWTs signed with `NEXTAUTH_SECRET` (HS256). Supabase is now the secondary/optional auth source. Set `NEXTAUTH_SECRET` to the same value as the platform to enable JWT validation.

### Configuring the desktop app

In the desktop app's **Settings** view, set the **Gateway URL** to `http://localhost:8080` (or `https://api.raymond-gray.org` in production). The sync agent uses this to push changes.

### Subdomains

The original project uses `www.raymond-gray.org` (marketing) and `remotesupport.raymond-gray.org` (remote support). The desktop app does **not** talk to these — it talks to the API gateway, which is a separate service. In production, deploy the gateway behind a reverse proxy at `api.raymond-gray.org`.

### Env var contract (desktop app → sync agent)

| Desktop app passes | Sync agent reads | Purpose |
|--------------------|------------------|---------|
| `RG_GATEWAY_URL` | `RG_GATEWAY_URL` | API gateway base URL |
| `RG_DB_PATH` | `RG_DB_PATH` | Path to local.db |
| `RG_POLL_INTERVAL_MS` | `RG_POLL_INTERVAL_MS` | Sync poll interval |
| `RG_AUTH_TOKEN` | `RG_AUTH_TOKEN` | JWT for gateway auth |

## Release & Update Pipeline

The desktop app uses **Tauri's built-in updater** to push updates to clients automatically.

### How updates work

1. **Build** — `npm run tauri build` produces the installer (`.msi`/`.exe`)
2. **Sign** — `tauri signer sign -k <private-key> <installer>` generates the `.sig` signature
3. **Publish** — Create a GitHub Release with the installer, `.sig`, and `latest.json`
4. **Client update** — On startup, the app checks `latest.json`, downloads the new version, verifies the signature, and installs passively

### One-command release

```powershell
.\scripts\release.ps1 -Version "1.1.0" -SigningKey "C:\path\to\myapp.key"
```

This script:
- Updates version in `package.json` and `tauri.conf.json`
- Builds the frontend and Tauri bundle
- Signs the installer
- Generates `latest.json`
- Creates a GitHub Release with all assets

### CI/CD (GitHub Actions)

Push a tag (`v1.1.0`) to trigger the automated pipeline in `.github/workflows/desktop-release.yml`:

```bash
git tag v1.1.0
git push origin v1.1.0
```

The workflow builds, signs, and publishes the release automatically. Requires these GitHub secrets:
- `TAURI_SIGNING_PRIVATE_KEY` — the Tauri signing private key
- `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` — the key password (if set)

### Generating a signing key

```bash
tauri signer generate -w ~/.tauri/myapp.key
```

The public key is already configured in `src-tauri/tauri.conf.json`.

---

## Build Status

Both the frontend and backend compile cleanly:

- **Frontend:** `npm run build` — TypeScript + Vite production build passes (44 modules, 0 errors)
- **Backend:** `cargo check` — Rust backend compiles with 0 errors, 0 warnings

### Toolchain Setup (Windows)

The full toolchain is now installed on this machine:

1. **Rust** — installed via `winget install Rustlang.Rustup` (cargo 1.97.1)
2. **Visual Studio Build Tools** — MSVC 14.44 linker (`link.exe`)
3. **Windows SDK** — 10.0.22621 (provides `kernel32.lib`)

To run the app in development:

```bash
npm run tauri dev
```

> **Note:** The Rust build requires the MSVC linker and Windows SDK libraries. If `cargo` reports `link.exe` or `kernel32.lib` not found, run the build from a **Visual Studio Developer Command Prompt** (or use `scripts/check-rust.cmd` which initializes the environment automatically).
