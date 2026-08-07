# Real-Data Integration & Safe Testing Guide

## How the apps fetch real data today

Every service in this repo already connects to the **production Neon database** via `NEON_URL`:

| Service | DB layer | Env var | Source |
|---------|----------|---------|--------|
| Work Order Service (Go) | GORM → Neon | `NEON_URL` | `docker-compose.yml` |
| CMMS Service (.NET) | EF Core → Neon | `NEON_URL` | `Program.cs` |
| Helpdesk Service (Python) | SQLAlchemy → Neon | `NEON_URL` | `docker-compose.yml` |
| Report Engine (Ruby) | Sequel → Neon | `NEON_URL` | `docker-compose.yml` |
| API Gateway (Go) | proxies to services | — | `main.go` |

So reads already show production data. **Writes go to production too** — that's why the desktop app now shows a confirmation modal before every create/update/delete.

## Confirmation modals (implemented)

Every write action in the desktop app (`rg-desktop-windows`) now requires explicit confirmation:
- `ConfirmModal` component (warning icon, "PRODUCTION database" message, Cancel/Confirm buttons)
- Work Orders: create, status update, delete, edit
- Assets: delete
- Helpdesk: delete

The modal text explicitly warns the change will be applied to the **production** database via the sync agent.

## Option A — Test safely with a Neon preview branch (recommended)

Use a Neon **preview branch** with the same schema/data as production, so you can test without touching prod.

**Your preview branch is already created:**

- **Branch name:** `services_test`
- **Connection string:**
  ```
  postgresql://neondb_owner:npg_6NuRrdpeUC4S@ep-muddy-morning-ah530x58-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
  ```

Point services at the branch instead of production:

```powershell
# From the repo root
$env:NEON_URL = "postgresql://neondb_owner:npg_6NuRrdpeUC4S@ep-muddy-morning-ah530x58-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
docker compose up -d workorder-service cmms-service helpdesk-service
```

Or use the helper script (recommended):

```powershell
powershell -File infrastructure/use-test-branch.ps1
```

Desktop app sync agent points at the gateway (unchanged) → gateway → services → **`services_test` preview branch**.

When satisfied, either merge the branch back (Neon "Merge branch") or abandon it.

## Option B — Test locally with a throwaway database

1. Spin up a local Postgres:
   ```powershell
   docker run -d --name rg-test-db -e POSTGRES_PASSWORD=test -p 5433:5432 postgres:16
   ```
2. Point services at it:
   ```powershell
   $env:NEON_URL = "postgresql://postgres:test@localhost:5433/postgres?sslmode=disable"
   ```
3. Run the services locally (no docker compose needed for the DB).

---

> **Safety rule:** never point the desktop app's sync agent at production until you've verified the flow against a preview branch. The confirmation modal is the final guard — every write requires an explicit click.