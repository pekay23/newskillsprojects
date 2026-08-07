# Raymond Gray IFM — Desktop App

> **Location:** `rg-desktop-windows/`
> **Stack:** Tauri 2.0 + React 18 + TypeScript + Vite + Rust + SQLite

---

## Overview

The desktop application for the Raymond Gray IFM platform. Provides **offline-first** facility management for field technicians and facility managers, syncing with the cloud via the Go sync agent.

## Technology Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | React 18 + TypeScript + Vite 5 |
| **Desktop Shell** | Tauri 2.0 (Rust) |
| **Local Storage** | SQLite (via `rusqlite`, bundled) |
| **Sync** | Go sync agent (`rg-sync-agent`) spawned as child process |
| **Updates** | Tauri updater plugin (GitHub Releases) |

## Features

- **Work Orders** — create, edit, update status, delete (offline-capable)
- **Assets** — track equipment and building assets
- **Helpdesk** — resident requests and amenity bookings
- **Sync Conflicts** — resolve offline/cloud conflicts (Use Mine / Use Cloud / Merge)
- **Settings** — configure API gateway URL, view sync status and pending changes queue
- **Authentication** — JWT-based login with secure in-memory token storage
- **Auto-Updates** — checks for new versions on startup, passive install

## Project Structure

```
rg-desktop-windows/
├── index.html              # Vite entry
├── package.json
├── tsconfig.json
├── vite.config.ts
├── latest.json             # Updater manifest (published to GitHub Releases)
├── scripts/
│   ├── check-rust.cmd      # Verifies Rust backend compiles
│   ├── generate-icon.cjs   # Generates RG-branded icon source PNG
│   └── release.ps1         # One-command release: build, sign, publish
├── src/                    # React + TypeScript frontend
│   ├── api.ts              # Tauri IPC wrappers
│   ├── types.ts            # Shared TypeScript types
│   ├── App.tsx             # App shell (sidebar + topbar + routing + updater)
│   ├── styles.css          # RG design system
│   ├── components/         # Sidebar, TopBar, Modal, Badge, EmptyState
│   └── views/              # WorkOrders, Assets, Helpdesk, Conflicts, Settings, Login
└── src-tauri/              # Rust backend
    ├── Cargo.toml
    ├── build.rs
    ├── tauri.conf.json     # Tauri v2 config (updater, bundle, window)
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

## Prerequisites

1. [Node.js](https://nodejs.org/) (v18+)
2. [Rust](https://rustup.rs/) — required for Tauri
3. C++ Build Tools (Windows: Visual Studio Build Tools)

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

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Desktop app architecture
- [RELEASE-PIPELINE.md](./RELEASE-PIPELINE.md) — Update & release process
- [AUTH.md](./AUTH.md) — Authentication flow
- [SYNC.md](./SYNC.md) — Offline sync & conflict resolution