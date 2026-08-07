# Points the backend services at the Neon services_test preview branch
# so you can test without touching production data.
# Run from the repo root:  powershell -File infrastructure/use-test-branch.ps1

# NOTE: Do NOT set $ErrorActionPreference = "Stop" here — docker writes
# warnings (e.g. obsolete `version` attribute) to stderr, which PowerShell
# would treat as a terminating error.

# The services_test preview branch connection string.
# NOTE: channel_binding=require is intentionally omitted — Npgsql (.NET CMMS)
# cannot parse it. sslmode=require is sufficient for Neon.
$env:NEON_URL = "postgresql://neondb_owner:npg_6NuRrdpeUC4S@ep-muddy-morning-ah530x58-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require"

Write-Host "NEON_URL set to the services_test preview branch:"
Write-Host "  $env:NEON_URL"
Write-Host ""
Write-Host "Starting backend services against the test branch..."
Write-Host "  (workorder-service, cmms-service, helpdesk-service, report-engine)"
Write-Host ""

# Use -f so this works from any working directory.
# Redirect stderr to stdout so docker's warnings don't trip up PowerShell.
docker compose -f infrastructure/docker-compose.yml up -d --build redis minio mosquitto workorder-service cmms-service helpdesk-service report-engine 2>&1

Write-Host ""
Write-Host "Services are running against the services_test branch."
Write-Host "The desktop app sync agent -> gateway -> services -> services_test (NOT production)."
Write-Host ""
Write-Host "To switch back to production, run:"
Write-Host "  powershell -File infrastructure/use-prod-branch.ps1"