# Points the backend services back at the PRODUCTION Neon database.
# Run from the repo root:  powershell -File infrastructure/use-prod-branch.ps1

# NOTE: Do NOT set $ErrorActionPreference = "Stop" here — docker writes
# warnings (e.g. obsolete `version` attribute) to stderr, which PowerShell
# would treat as a terminating error.

# The production Neon connection string (from raymond-gray-platform/.env).
# NOTE: channel_binding=require is intentionally omitted — Npgsql (.NET CMMS)
# cannot parse it. sslmode=require is sufficient for Neon.
# Load NEON_URL from .env (gitignored) - do not hardcode credentials
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    $env:NEON_URL = (Get-Content $envFile | Where-Object { $_ -match '^NEON_URL=' }) -replace '^NEON_URL="?', '' -replace '"$', ''
}
if (-not $env:NEON_URL) {
    Write-Error "NEON_URL not found. Set it in infrastructure/.env"
    exit 1
}

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