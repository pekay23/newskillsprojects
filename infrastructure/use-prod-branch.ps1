# Points the backend services back at the PRODUCTION Neon database.
# Run from the repo root:  powershell -File infrastructure/use-prod-branch.ps1

# NOTE: Do NOT set $ErrorActionPreference = "Stop" here — docker writes
# warnings (e.g. obsolete `version` attribute) to stderr, which PowerShell
# would treat as a terminating error.

# The production Neon connection string (from raymond-gray-platform/.env).
# NOTE: channel_binding=require is intentionally omitted — Npgsql (.NET CMMS)
# cannot parse it. sslmode=require is sufficient for Neon.
$env:NEON_URL = "postgresql://neondb_owner:npg_6NuRrdpeUC4S@ep-ancient-sun-ahghyh2z-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require"

Write-Host "NEON_URL set to the PRODUCTION database:"
Write-Host "  $env:NEON_URL"
Write-Host ""
Write-Host "WARNING: Services will now read/write PRODUCTION data."
Write-Host "The desktop app confirmation modals are the final guard before any write."
Write-Host ""
Write-Host "Restarting backend services against production..."
Write-Host ""

# Use -f so this works from any working directory.
# Redirect stderr to stdout so docker's warnings don't trip up PowerShell.
docker compose -f infrastructure/docker-compose.yml up -d --build redis minio mosquitto workorder-service cmms-service helpdesk-service report-engine 2>&1

Write-Host ""
Write-Host "Services are running against PRODUCTION."
Write-Host "To switch back to the test branch, run:"
Write-Host "  powershell -File infrastructure/use-test-branch.ps1"