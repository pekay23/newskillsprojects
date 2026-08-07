# teamcity-fix-builds.ps1 - Fixes failing TeamCity build configs
# Usage: .\infrastructure\teamcity-fix-builds.ps1
#
# Fixes:
#   - rg-workorder: Test step uses -race (needs cgo) -> remove -race
#   - rg-cmms: Working directory not set -> set to rg-cmms-service
#   - rg-helpdesk: Working directory not set -> set to rg-helpdesk-service
#   - rg-report-engine: Already fixed (Docker build)

param(
    [string]$TeamCityUrl = "",
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

# Load credentials from .env
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*([A-Z_]+)="?(.+?)"?\s*$') {
            $envName = $Matches[1]
            $envValue = $Matches[2]
            Set-Variable -Name $envName -Value $envValue -Scope Script
        }
    }
}

if (-not $TeamCityUrl) { $TeamCityUrl = $TEAMCITY_URL }
if (-not $Username) { $Username = $TEAMCITY_USERNAME }
if (-not $Password) { $Password = $TEAMCITY_PASSWORD }

$pair = "${Username}:${Password}"
$base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    "Authorization" = "Basic $base64"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

Write-Host "=== Fixing TeamCity Build Configs ===" -ForegroundColor Cyan

# Helper function to add a step with working directory
function Add-Step {
    param($btId, $stepName, $cmd, $workingDir)
    $stepBody = @{
        name = $stepName
        type = "simpleRunner"
        properties = @{
            property = @(
                @{ name = "script.content"; value = $cmd },
                @{ name = "teamcity.step.mode"; value = "default" },
                @{ name = "use.custom.script"; value = "true" },
                @{ name = "teamcity.build.workingDir"; value = $workingDir }
            )
        }
    } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Post -Body $stepBody | Out-Null
    Write-Host "  Added step '$stepName' to $btId (workingDir: $workingDir)" -ForegroundColor Green
}

# Helper function to delete all steps from a build type
function Clear-Steps {
    param($btId)
    $steps = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Get
    if ($steps.step) {
        foreach ($step in $steps.step) {
            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps/$($step.id)" -Headers $headers -Method Delete | Out-Null
        }
        Write-Host "  Cleared old steps from $btId" -ForegroundColor Yellow
    }
}

# ================================================================
# 1. Fix rg-workorder (remove -race flag, set working dir)
# ================================================================
Write-Host "`n[1/4] Fixing rg-workorder..." -ForegroundColor Yellow
foreach ($env in @("dev", "staging", "prod")) {
    $btId = "rg_workorder_$env"
    try {
        Clear-Steps $btId
        Add-Step $btId "Lint" "go vet ./..." "rg-workorder-service"
        Add-Step $btId "Test" "go test ./... -coverprofile=coverage.out" "rg-workorder-service"
        Add-Step $btId "Build" "go build -o bin/server ./cmd/server" "rg-workorder-service"
    } catch {
        Write-Host "  Error fixing $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# 2. Fix rg-cmms (set working dir)
# ================================================================
Write-Host "`n[2/4] Fixing rg-cmms..." -ForegroundColor Yellow
foreach ($env in @("dev", "staging", "prod")) {
    $btId = "rg_cmms_$env"
    try {
        Clear-Steps $btId
        Add-Step $btId "Restore" "dotnet restore" "rg-cmms-service"
        Add-Step $btId "Build" "dotnet build --no-restore --configuration Release" "rg-cmms-service"
        Add-Step $btId "Test" "dotnet test --no-build --configuration Release" "rg-cmms-service"
    } catch {
        Write-Host "  Error fixing $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# 3. Fix rg-helpdesk (set working dir)
# ================================================================
Write-Host "`n[3/4] Fixing rg-helpdesk..." -ForegroundColor Yellow
foreach ($env in @("dev", "staging", "prod")) {
    $btId = "rg_helpdesk_$env"
    try {
        Clear-Steps $btId
        Add-Step $btId "Install" "pip install -r requirements.txt" "rg-helpdesk-service"
        Add-Step $btId "Syntax Check" "python -m py_compile main.py models.py schemas.py database.py worker.py" "rg-helpdesk-service"
    } catch {
        Write-Host "  Error fixing $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# 4. Verify rg-report-engine (already fixed)
# ================================================================
Write-Host "`n[4/4] Verifying rg-report-engine..." -ForegroundColor Yellow
foreach ($env in @("dev", "staging", "prod")) {
    $btId = "rg_report_engine_$env"
    try {
        $steps = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Get
        Write-Host "  $btId has $($steps.step.Count) step(s)" -ForegroundColor Green
    } catch {
        Write-Host "  Error checking $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Fixes applied ===" -ForegroundColor Green
Write-Host "  rg-workorder: Test without -race, workingDir=rg-workorder-service"
Write-Host "  rg-cmms: workingDir=rg-cmms-service"
Write-Host "  rg-helpdesk: workingDir=rg-helpdesk-service"
Write-Host "  rg-report-engine: Already using Docker build"
Write-Host ""
Write-Host "Next: Trigger new builds to verify."