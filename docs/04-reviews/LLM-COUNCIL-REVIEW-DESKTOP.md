# LLM Council Review — Desktop App Build (Tauri + React + Rust)

> **Subject Under Review:** Building the `rg-desktop-windows` Tauri desktop app to commercial grade
> **Council Convened:** 2026-08-06
> **Context:** The desktop app scaffolding exists (package.json, tauri.conf.json, README) but has NO Rust backend, NO React frontend, NO SQLite integration, NO sync agent wiring. The user wants it fully built, running without errors, very functional, and commercial grade — using the LLM council process to predict unforeseen issues and continuously improve.

---

## Stage 1: First Opinions (Divergence)

### 🏗️ Council Member 1: The Enterprise Architect

**Overall Assessment: C (Scaffolding only — needs complete build)**

**Strengths:**
- Tauri v2 + React + TypeScript is the right stack for a lightweight, secure desktop app
- The architecture doc (Section 8) already defines the correct layering: React UI → Tauri Rust backend → SQLite → Go Sync Agent → API Gateway
- The sync engine spec is thorough and provides clear contracts

**Critical Issues:**

1. **Tauri v2 RC vs stable mismatch.** `package.json` uses `@tauri-apps/api@^2.0.0-rc.0` and `@tauri-apps/cli@^2.0.0-rc.0`. The Rust crates must match the JS API version exactly (both v2 RC). Mismatched versions cause runtime IPC failures. **Recommendation: Pin exact versions and verify the Rust `tauri` crate version matches the JS `@tauri-apps/api` version.**

2. **Missing capabilities/permissions file.** Tauri v2 requires a `capabilities/default.json` file to grant the frontend permissions (e.g., `core:default`, `core:window:allow-*`). Without it, IPC calls fail silently. **This is the #1 cause of "app runs but nothing works" in Tauri v2.**

3. **SQLite schema must mirror the sync spec.** The `_changes` table in the sync agent uses `table_name`, `record_id`, `operation`, `timestamp`, `synced`. The desktop SQLite must use the SAME schema so the sync agent can read it. The spec (Section 2.1) defines a richer schema with `entity`, `entity_id`, `payload`, `client_id`, `changed_at`, `synced_at`. **Recommendation: Align the desktop SQLite schema with the SYNC-ENGINE-SPEC (Section 2.1), not the current sync agent's simplified schema.**

4. **The sync agent is a separate Go process.** The Tauri app must spawn it as a child process and manage its lifecycle (start on app launch, stop on exit). This requires the Rust backend to use `std::process::Command` and handle process cleanup.

5. **Conflict resolution UI is a core feature, not a nice-to-have.** The spec (Section 5) requires a conflict badge in the top nav + a conflict panel with "Use Mine", "Use Cloud", "Open Record to Merge". This must be built into the React UI.

---

### 🔧 Council Member 2: The DevOps & CI/CD Engineer

**Overall Assessment: D (No build pipeline, no icons, no packaging)**

**Critical Issues:**

1. **No icons.** Tauri requires `src-tauri/icons/icon.ico` (Windows) and `icon.png` (macOS/Linux) for bundling. Without them, `tauri build` fails. **Recommendation: Generate placeholder icons early.**

2. **No `Cargo.toml`.** The Rust backend doesn't exist. Need to create it with correct dependencies: `tauri`, `tauri-build`, `serde`, `serde_json`, `rusqlite` (with `bundled` feature for Windows), `uuid`, `chrono`.

3. **Windows build requirements.** Tauri on Windows needs:
   - Rust toolchain (MSVC)
   - WebView2 runtime (pre-installed on Win 11)
   - C++ Build Tools
   - The `tauri.conf.json` `bundle.windows.certificateThumbprint` is `null` — unsigned builds will show SmartScreen warnings. **For dev, this is fine; for commercial, need code signing.**

4. **No `vite.config.ts` or `tsconfig.json`.** The frontend can't build without these. Need to create them with the Tauri-specific Vite config (clearScreen: false, server.port: 5173, strictPort: true, envPrefix).

5. **No `index.html`.** Vite needs an entry HTML file.

6. **No `src-tauri/build.rs`.** Tauri v2 requires this for the build script.

7. **No `src-tauri/capabilities/`.** Required for Tauri v2 permissions.

---

### 🧑‍💻 Council Member 3: The Solo Developer Realist

**Overall Assessment: C (Doable but must be pragmatic)**

**Critical Issues:**

1. **Scope is large.** Building a full commercial desktop app (Work Orders, Assets, Helpdesk, Conflict Panel, Sync) in one session is ambitious. **Recommendation: Build a solid MVP first (Work Orders + Conflict Panel + Sync), then add Assets and Helpdesk.**

2. **SQLite via rusqlite in Rust is verbose.** For a commercial app, consider using a Rust ORM or at least a clean repository pattern. But for pragmatism, direct rusqlite with prepared statements is fine.

3. **The sync agent is Go, the desktop is Rust.** Two languages in one app. The Rust backend should NOT reimplement sync — it should spawn the Go binary and let it handle sync. The Rust backend only manages SQLite reads/writes for the UI.

4. **Testing.** Need at least basic unit tests for the Rust DB layer and the React components. Commercial grade requires tests.

5. **Error handling.** Every IPC command must return a `Result<T, String>` and the frontend must handle errors gracefully (toast/notification, not silent failure).

---

### 💰 Council Member 4: The Financial/Business Analyst

**Overall Assessment: B (Right product, needs commercial polish)**

**Critical Issues:**

1. **The app must look professional.** Raymond Gray IFM is a commercial product. The UI needs a clean, modern design with the RG brand (the `rg-*` utility classes from the web app's globals.css).

2. **Offline-first is the killer feature.** The value proposition is "field technicians can work offline and sync later." The conflict resolution UI must be intuitive — non-technical users need to understand "Use Mine" vs "Use Cloud".

3. **Multi-tenancy.** Every record must have `property_id` (per council refinement #12). The desktop app should let users select their property.

4. **Audit trail.** Commercial FM software needs to track who changed what. The `_changes` table with `client_id` and `changed_at` provides this.

---

### 🔒 Council Member 5: The Security Auditor

**Overall Assessment: C (Security must be built in, not bolted on)**

**Critical Issues:**

1. **JWT storage.** The desktop app needs the Supabase JWT to authenticate sync requests. **Never store the JWT in localStorage** (XSS risk). Store it in the Rust backend (in-memory or encrypted file) and pass it to the sync agent via env var or config file with restricted permissions.

2. **SQLite injection.** All SQL in rusqlite must use prepared statements with parameters — never string concatenation.

3. **Path traversal.** The Rust backend must validate all file paths (e.g., for photo uploads) to prevent path traversal.

4. **The sync agent's `PushChanges` sends `table_name` and `record_id` without validation.** The desktop app must validate entity types before writing to `_changes`.

5. **HTTPS only.** The sync agent must use HTTPS for the gateway URL. No plain HTTP in production.

---

## Stage 2: Peer Review (Cross-Examination)

### Architect ↔ Solo Dev

**Architect:** "The sync agent is a separate Go process. How does the Tauri app know it's running?"

**Solo Dev:** "The Rust backend spawns it on app start and checks the process status. If it crashes, the Rust backend restarts it with exponential backoff. The React UI polls the Rust backend for sync status."

**Consensus:** Rust backend manages the sync agent lifecycle. React UI shows sync status (connected/offline/syncing).

### DevOps ↔ Security

**DevOps:** "We need icons for bundling. Can we generate them programmatically?"

**Security:** "Yes, but the icon must be a valid RG brand icon. Use a simple SVG → PNG/ICO conversion. Don't ship with default Tauri icons — that looks unprofessional."

**Consensus:** Generate a simple RG-branded icon (blue square with "RG" text) using a script.

### Business Analyst ↔ Architect

**Business:** "The conflict panel is the most important UI. It must be dead simple."

**Architect:** "Agreed. The spec (Section 5.2) already defines the layout: two columns (Your Version vs Cloud Version), three buttons (Use Mine, Use Cloud, Open Record to Merge). We'll implement exactly that."

**Consensus:** Implement the conflict panel exactly per spec.

### Solo Dev ↔ Security

**Solo Dev:** "Storing the JWT in the Rust backend is more work. Can we just use localStorage?"

**Security:** "No. localStorage is accessible to any XSS. The Rust backend should hold the token in memory and expose it only to the sync agent via a secure channel."

**Consensus:** Rust backend holds JWT in memory. Sync agent receives it via env var on spawn.

---

## Stage 3: Final Synthesis (Chairman's Report)

### Chairman's Verdict: Build is feasible but requires a structured, phased approach

The desktop app is currently scaffolding-only. Building it to commercial grade requires:

---

### Refinement 1: CRITICAL — Pin Tauri v2 versions

Use exact versions for `@tauri-apps/api`, `@tauri-apps/cli`, and the Rust `tauri` crate. Mismatched versions cause silent IPC failures.

### Refinement 2: CRITICAL — Create capabilities file

`src-tauri/capabilities/default.json` with `core:default` and window permissions. Without it, IPC fails.

### Refinement 3: CRITICAL — Align SQLite schema with sync spec

Desktop SQLite uses the SYNC-ENGINE-SPEC schema (Section 2.1): `_changes` with `entity`, `entity_id`, `operation`, `payload`, `client_id`, `changed_at`, `synced_at`. The sync agent reads this.

### Refinement 4: HIGH — Rust backend manages sync agent lifecycle

Spawn Go sync agent on app start, restart on crash with backoff, stop on exit.

### Refinement 5: HIGH — Build order: MVP first, then expand

1. **Phase 1 (MVP):** Rust backend + SQLite + Work Orders CRUD + Conflict Panel + Sync status
2. **Phase 2:** Assets + Helpdesk views
3. **Phase 3:** Polish (icons, branding, error toasts, empty states, loading states)

### Refinement 6: HIGH — Security: JWT in Rust memory, prepared statements

Never store JWT in localStorage. All SQL via prepared statements. Validate entity types.

### Refinement 7: MEDIUM — Generate RG-branded icons

Simple blue square with "RG" text. Not default Tauri icons.

### Refinement 8: MEDIUM — Error handling everywhere

Every IPC command returns `Result<T, String>`. Frontend shows toast on error. No silent failures.

### Refinement 9: MEDIUM — Multi-tenancy

Every table has `property_id`. Property selector in the top bar.

### Refinement 10: MEDIUM — Testing

Rust unit tests for DB layer. React component tests for critical UI (conflict panel).

### Refinement 11: LOW — Offline indicator

Top bar shows sync status: green (connected), yellow (syncing), red (offline).

### Refinement 12: LOW — Empty states

Every list view shows a friendly empty state ("No work orders yet").

---

### Priority Matrix

| Priority | Refinement | Impact |
|----------|-----------|--------|
| 🔴 CRITICAL | #1 Pin Tauri v2 versions | Prevents IPC failures |
| 🔴 CRITICAL | #2 Capabilities file | Prevents silent IPC failure |
| 🔴 CRITICAL | #3 SQLite schema alignment | Sync works correctly |
| 🟠 HIGH | #4 Sync agent lifecycle | App functions offline |
| 🟠 HIGH | #5 Build order (MVP first) | Delivers working app |
| 🟠 HIGH | #6 Security (JWT, prepared stmts) | Commercial grade |
| 🟡 MEDIUM | #7 RG-branded icons | Professional look |
| 🟡 MEDIUM | #8 Error handling | No silent failures |
| 🟡 MEDIUM | #9 Multi-tenancy | Future-proofing |
| 🟡 MEDIUM | #10 Testing | Quality assurance |
| 🟢 LOW | #11 Offline indicator | UX polish |
| 🟢 LOW | #12 Empty states | UX polish |