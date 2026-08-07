# teamcity-enable-auto-cancel.ps1 - Enables "Cancel outdated builds" on all build configs
# Usage: .\infrastructure\teamcity-enable-auto-cancel.ps1
#
# Sets the VCS trigger on each build config to:
#   - Cancel queued builds when a newer one is triggered
#   - Cancel running builds if a newer build starts after 3 minutes

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

$buildTypes = @(
    "rg_workorder_dev", "rg_workorder_staging", "rg_workorder_prod",
    "rg_cmms_dev", "rg_cmms_staging", "rg_cmms_prod",
    "rg_helpdesk_dev", "rg_helpdesk_staging", "rg_helpdesk_prod",
    "rg_api_gateway_dev", "rg_api_gateway_staging", "rg_api_gateway_prod",
    "rg_sync_agent_dev", "rg_sync_agent_staging", "rg_sync_agent_prod",
    "rg_report_engine_dev", "rg_report_engine_staging", "rg_report_engine_prod"
)

Write-Host "=== Enabling Auto-Cancel on Build Configs ===" -ForegroundColor Cyan

$total = 0
foreach ($bt in $buildTypes) {
    try {
        # Get the existing trigger
        $triggers = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$bt/triggers" -Headers $headers -Method Get
        if ($triggers.trigger -and $triggers.trigger.Count -gt 0) {
            $triggerId = $triggers.trigger[0].id

            # Determine the branch filter from the build type name
            $branch = "main"
            if ($bt -match "_dev$") { $branch = "dev" }
            elseif ($bt -match "_staging$") { $branch = "staging" }

            # Build the trigger body with auto-cancel properties
            $triggerBody = @{
                type = "vcsTrigger"
                properties = @{
                    property = @(
                        @{ name = "branchFilter"; value = "+:$branch" },
                        @{ name = "groupingPolicy"; value = "DONT_GROUP" },
                        @{ name = "cancelNewQueuedBuilds"; value = "true" },
                        @{ name = "cancelRunningBuilds"; value = "true" },
                        @{ name = "cancelRunningBuildsTimeout"; value = "180" }
                    )
                }
            } | ConvertTo-Json -Depth 5

            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$bt/triggers/$triggerId" -Headers $headers -Method Put -Body $triggerBody | Out-Null
            Write-Host "  Updated $bt (branch: $branch) - auto-cancel enabled" -ForegroundColor Green
            $total++
        } else {
            Write-Host "  $bt - no trigger found" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Failed $bt : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Done: $total build configs updated ===" -ForegroundColor Green
Write-Host "  - Cancel queued builds when newer one is triggered"
Write-Host "  - Cancel running builds if newer build starts after 3 min"