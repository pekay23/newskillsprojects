# Starts the API Gateway with the Supabase project URL configured
# so JWT auth initializes correctly.
# Run from the repo root:  powershell -File rg-api-gateway/start-gateway.ps1

$ErrorActionPreference = "Stop"

# Supabase project URL (from the connected Supabase project)
$env:SUPABASE_PROJECT_URL = "https://nojszntucwdivxurrphf.supabase.co"

# Backend service URLs (adjust ports to match your running services)
if (-not $env:WORKORDER_URL) { $env:WORKORDER_URL = "http://localhost:8081" }
if (-not $env:CMMS_URL)       { $env:CMMS_URL = "http://localhost:8082" }
if (-not $env:HELPDESK_URL)   { $env:HELPDESK_URL = "http://localhost:8083" }
if (-not $env:REPORTS_URL)    { $env:REPORTS_URL = "http://localhost:8084" }

$gatewayDir = Join-Path $PSScriptRoot "."
$exe = Join-Path $gatewayDir "rg-api-gateway.exe"

if (-not (Test-Path $exe)) {
    Write-Host "Gateway binary not found. Building from source..."
    $goBin = "C:\Program Files\Go\bin"
    if (-not (Test-Path (Join-Path $goBin "go.exe"))) {
        Write-Error "Go not found. Install via: winget install GoLang.Go"
        exit 1
    }
    $env:Path = "$goBin;$env:Path"
    Push-Location $gatewayDir
    try {
        go build -o rg-api-gateway.exe ./cmd/gateway
    } finally {
        Pop-Location
    }
}

Write-Host "Starting API Gateway on :8080"
Write-Host "  SUPABASE_PROJECT_URL = $env:SUPABASE_PROJECT_URL"
Write-Host "  WORKORDER_URL        = $env:WORKORDER_URL"
Write-Host "  CMMS_URL             = $env:CMMS_URL"
Write-Host "  HELPDESK_URL         = $env:HELPDESK_URL"
Write-Host "  REPORTS_URL          = $env:REPORTS_URL"
Write-Host "Press Ctrl+C to stop."

& $exe