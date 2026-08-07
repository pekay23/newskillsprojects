# LLM Council Review — API Gateway Integration for Desktop App

> **Subject Under Review:** Linking the `rg-desktop-windows` Tauri app to the `rg-api-gateway` and the original `raymond-gray-platform` project (with subdomains), WITHOUT modifying the original project.
> **Council Convened:** 2026-08-06
> **Context:** The desktop app builds and runs, but the sync agent binary isn't found (it's never been compiled to .exe). The user wants to know how to use the API gateway, link it to the original project in `C:\Projects`, account for subdomains, and perfect the integration without touching the original project's files.

---

## Stage 1: First Opinions (Divergence)

### 🏗️ Council Member 1: The Enterprise Architect

**Overall Assessment: B (Sound architecture, needs concrete wiring)**

**Strengths:**
- The polyglot architecture is correct: desktop (Tauri/Rust) → sync agent (Go) → API gateway (Go) → backend services
- The gateway already has `/health` and `/ready` endpoints and Supabase JWT auth scaffolding
- The sync agent already reads `API_GATEWAY_URL` and `SYNC_AUTH_TOKEN` env vars

**Critical Issues:**

1. **The sync agent binary is never built.** The desktop app's `SyncManager` looks for `rg-sync-agent.exe` but it doesn't exist. **Fix: build it with `go build` and place it where the desktop app looks for it.**

2. **The sync agent's env var names don't match what the desktop app passes.** The desktop app's `sync.rs` passes `RG_GATEWAY_URL`, `RG_DB_PATH`, `RG_POLL_INTERVAL_MS`, but the sync agent reads `API_GATEWAY_URL`, `LOCAL_DB_PATH`, `SYNC_AUTH_TOKEN`. **Fix: align the env var names.**

3. **The gateway's `/sync/*` endpoints may not exist yet.** The sync agent calls `/sync/push`, but the gateway's `main.go` only shows `/health` and `/ready`. Need to verify the proxy routes include `/sync/*`.

4. **Subdomain routing.** The original project uses `www.raymond-gray.org` and `remotesupport.raymond-gray.org`. The desktop app should point to the API gateway, which routes to the appropriate backend service. The gateway must be configured with the correct service URLs.

---

### 🔧 Council Member 2: The DevOps & CI/CD Engineer

**Overall Assessment: C (Build pipeline missing for sync agent)**

**Critical Issues:**

1. **No build script for the sync agent.** Need a `build.ps1` or Makefile that runs `go build -o rg-sync-agent.exe ./cmd/syncagent`.

2. **The sync agent needs to be placed in the right location.** The desktop app's `sync.rs` looks for it in:
   - `../rg-sync-agent/rg-sync-agent.exe`
   - `../../rg-sync-agent/rg-sync-agent.exe`
   - `rg-sync-agent.exe`
   - `./rg-sync-agent.exe`
   
   **Fix: build it to `rg-sync-agent/rg-sync-agent.exe`** (the first candidate the desktop app checks).

3. **The API gateway needs to be running** for sync to work. The desktop app's Settings view lets the user set the gateway URL. Default should be `http://localhost:8080`.

4. **Subdomain routing in production.** The gateway should be deployed behind a reverse proxy (Nginx/Caddy) that routes `api.raymond-gray.org` to the gateway, and the gateway routes to services. For local dev, `localhost:8080` is fine.

---

### 🧑‍💻 Council Member 3: The Solo Developer Realist

**Overall Assessment: B (Doable, but must be pragmatic)**

**Critical Issues:**

1. **The sync agent's `PushChanges` sends `table_name` and `record_id` but the desktop app's `_changes` table uses `entity` and `entity_id`.** The SYNC-ENGINE-SPEC (Section 2.1) defines `entity`, `entity_id`, `operation`, `payload`, `client_id`, `changed_at`, `synced_at`. The sync agent's `manager.go` queries `SELECT id, table_name, record_id, operation FROM _changes WHERE synced = 0` — this won't match the desktop app's schema. **Fix: align the sync agent's SQL with the desktop app's `_changes` schema.**

2. **The sync agent's `PushChanges` posts to `/sync/push` but the spec says `POST /sync/{service}`.** Need to verify the gateway route.

3. **JWT auth.** The sync agent needs a valid Supabase JWT to authenticate. The desktop app doesn't currently have a login flow. **For now, use a placeholder/device token or make auth optional in dev.**

4. **Don't over-engineer.** The user wants to link the desktop app to the gateway and the original project. Focus on: (a) build the sync agent, (b) align env vars, (c) align the `_changes` schema, (d) configure the gateway URL.

---

### 💰 Council Member 4: The Financial/Business Analyst

**Overall Assessment: B (Right product, needs clear integration path)**

**Critical Issues:**

1. **The value proposition is offline-first field work.** The desktop app must sync work orders, assets, and helpdesk requests to the cloud. The gateway is the bridge.

2. **Subdomains matter for the business.** `www.raymond-gray.org` is the public marketing site, `remotesupport.raymond-gray.org` is the remote support portal. The desktop app should NOT touch these — it talks to the API gateway, which is a separate concern.

3. **The gateway should be a separate deployment** (e.g., `api.raymond-gray.org`) so it doesn't interfere with the marketing site or remote support.

---

### 🔒 Council Member 5: The Security Auditor

**Overall Assessment: C (Auth must be handled carefully)**

**Critical Issues:**

1. **JWT storage.** The desktop app must not store the Supabase JWT in localStorage. The Rust backend should hold it in memory and pass it to the sync agent via env var.

2. **The sync agent's `PushChanges` sends `table_name` and `record_id` without validation.** The desktop app must validate entity types before writing to `_changes`.

3. **HTTPS only in production.** The gateway URL must be HTTPS in production. Localhost is fine for dev.

4. **The original project must not be modified.** The gateway is a separate service that proxies to the original project's API routes (if any) or to the new backend services. Never modify `C:\Projects\raymond-gray-platform`.

---

## Stage 2: Peer Review (Cross-Examination)

### Architect ↔ Solo Dev

**Architect:** "The sync agent's `_changes` schema must match the desktop app's. The spec (Section 2.1) is the source of truth."

**Solo Dev:** "Agreed. The desktop app's `db.rs` already implements the spec schema. The sync agent's `sqlite.go` uses a simplified schema. We need to update the sync agent to read the spec schema."

**Consensus:** Update the sync agent's `sqlite.go` and `manager.go` to use the SYNC-ENGINE-SPEC schema (`entity`, `entity_id`, `operation`, `payload`, `client_id`, `changed_at`, `synced_at`).

### DevOps ↔ Security

**DevOps:** "We need a build script for the sync agent."

**Security:** "Yes, and the build must produce a standalone .exe that the desktop app can spawn. Also, the JWT must be passed securely."

**Consensus:** Create `build.ps1` that runs `go build -o rg-sync-agent.exe ./cmd/syncagent`. The desktop app passes the JWT via env var on spawn.

### Business ↔ Architect

**Business:** "The gateway should be a separate deployment on `api.raymond-gray.org`."

**Architect:** "Agreed. For local dev, `localhost:8080` is fine. The gateway proxies to the backend services, not to the marketing site."

**Consensus:** Gateway runs on `localhost:8080` locally, `api.raymond-gray.org` in production. It proxies to the backend services (workorder-service, cmms-service, helpdesk-service).

---

## Stage 3: Final Synthesis (Chairman's Report)

### Chairman's Verdict: Integration is feasible with 8 concrete steps

---

### Refinement 1: CRITICAL — Build the sync agent .exe

Create `rg-sync-agent/build.ps1`:
```powershell
go build -o rg-sync-agent.exe ./cmd/syncagent
```
Place the .exe at `rg-sync-agent/rg-sync-agent.exe` (the first location the desktop app checks).

### Refinement 2: CRITICAL — Align env var names

The desktop app's `sync.rs` passes `RG_GATEWAY_URL`, `RG_DB_PATH`, `RG_POLL_INTERVAL_MS`. The sync agent reads `API_GATEWAY_URL`, `LOCAL_DB_PATH`, `SYNC_AUTH_TOKEN`. **Fix: update the sync agent to read `RG_GATEWAY_URL`, `RG_DB_PATH`, `RG_POLL_INTERVAL_MS`** (or update the desktop app to pass the sync agent's names — pick one and be consistent).

### Refinement 3: CRITICAL — Align the `_changes` schema

The sync agent's `sqlite.go` creates `_changes` with `table_name`, `record_id`, `operation`, `timestamp`, `synced`. The desktop app's `db.rs` creates `_changes` with `entity`, `entity_id`, `operation`, `payload`, `client_id`, `changed_at`, `synced_at`. **Fix: update the sync agent to read the desktop app's schema.**

### Refinement 4: HIGH — Verify gateway /sync routes

The sync agent calls `/sync/push`. Verify the gateway's `main.go` routes `/sync/*` to the appropriate backend service. If not, add the route.

### Refinement 5: HIGH — Configure the gateway URL in the desktop app

The desktop app's Settings view lets the user set the gateway URL. Default to `http://localhost:8080`. The sync agent uses this to push changes.

### Refinement 6: HIGH — JWT auth

For dev, allow the sync agent to work without a JWT (or with a placeholder). In production, the desktop app must obtain a Supabase JWT and pass it to the sync agent.

### Refinement 7: MEDIUM — Subdomain routing

The gateway is a separate service. It does NOT route to `www.raymond-gray.org` or `remotesupport.raymond-gray.org`. It routes to the backend services. The original project is untouched.

### Refinement 8: MEDIUM — Build script + docs

Add a `build.ps1` for the sync agent and document the integration in the README.

---

### Priority Matrix

| Priority | Refinement | Impact |
|----------|-----------|--------|
| 🔴 CRITICAL | #1 Build sync agent .exe | Fixes "binary not found" |
| 🔴 CRITICAL | #2 Align env var names | Sync agent connects |
| 🔴 CRITICAL | #3 Align _changes schema | Sync works correctly |
| 🟠 HIGH | #4 Verify gateway /sync routes | Sync reaches backend |
| 🟠 HIGH | #5 Configure gateway URL | Desktop app connects |
| 🟠 HIGH | #6 JWT auth | Secure sync |
| 🟡 MEDIUM | #7 Subdomain routing | Production deployment |
| 🟡 MEDIUM | #8 Build script + docs | Reproducibility |