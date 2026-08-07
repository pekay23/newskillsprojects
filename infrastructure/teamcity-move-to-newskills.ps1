# teamcity-move-to-newskills.ps1 - Moves the 18 rg-* build configs to the Newskillsprojects project
# Usage: .\infrastructure\teamcity-move-to-newskills.ps1
#
# TeamCity build type IDs are globally unique, so the rg_* build types created
# under RaymondGrayPlatform must be MOVED to Newskillsprojects (not recreated).

param(
    [string]$TeamCityUrl = "",
    [string]$Username = "",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

# Load credentials from .env
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)="?(.+?)"?\s*$') {
            Set-Variable -Name $Matches[1] -Value $Matches[2] -Scope Script
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
    "Content-Type" = "text/plain"
    "Accept" = "text/plain"
}

$buildTypeIds = @(
    "rg_workorder_dev", "rg_workorder_staging", "rg_workorder_prod",
    "rg_cmms_dev", "rg_cmms_staging", "rg_cmms_prod",
    "rg_helpdesk_dev", "rg_helpdesk_staging", "rg_helpdesk_prod",
    "rg_api_gateway_dev", "rg_api_gateway_staging", "rg_api_gateway_prod",
    "rg_sync_agent_dev", "rg_sync_agent_staging", "rg_sync_agent_prod",
    "rg_report_engine_dev", "rg_report_engine_staging", "rg_report_engine_prod"
)

Write-Host "=== Moving build configs to Newskillsprojects project ===" -ForegroundColor Cyan

foreach ($bt in $buildTypeIds) {
    try {
        # TeamCity expects the project ID as plain text body
        $body = 'Newskillsprojects'
        Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$bt/project" -Headers $headers -Method Put -Body $body | Out-Null
        Write-Host "  Moved $bt -> Newskillsprojects" -ForegroundColor Green
    } catch {
        Write-Host "  Failed $bt : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan
try {
    $b = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes?locator=project:Newskillsprojects" -Headers $headers -Method Get
    Write-Host "Build configs in Newskillsprojects: $($b.buildType.Count)"
    if ($b.buildType) {
        $b.buildType | ForEach-Object { Write-Host "  $($_.name) (id: $($_.id))" }
    }
} catch {
    Write-Host "Error verifying: $($_.Exception.Message)" -ForegroundColor Red
}