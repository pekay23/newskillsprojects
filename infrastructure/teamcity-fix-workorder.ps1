# teamcity-fix-workorder.ps1 - Fixes the workorder Build step (uses cmd/workorders not cmd/server)
# Usage: .\infrastructure\teamcity-fix-workorder.ps1

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

Write-Host "=== Fixing Workorder Build Steps ===" -ForegroundColor Cyan

foreach ($env in @("dev", "staging", "prod")) {
    $btId = "rg_workorder_$env"
    try {
        # Get steps
        $steps = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Get
        # Find and fix the Build step (last step - test is 2nd, build is 3rd)
        if ($steps.step) {
            foreach ($step in $steps.step) {
                $props = $step.properties.property
                $content = ($props | Where-Object { $_.name -eq "script.content" }).value
                if ($content -match "cmd/server") {
                    # Delete the old step
                    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps/$($step.id)" -Headers $headers -Method Delete | Out-Null
                    # Add corrected build step
                    $newStep = @{
                        name = "Build"
                        type = "simpleRunner"
                        properties = @{
                            property = @(
                                @{ name = "script.content"; value = "go build -o bin/server ./cmd/workorders" },
                                @{ name = "teamcity.step.mode"; value = "default" },
                                @{ name = "use.custom.script"; value = "true" },
                                @{ name = "teamcity.build.workingDir"; value = "rg-workorder-service" }
                            )
                        }
                    } | ConvertTo-Json -Depth 5
                    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Post -Body $newStep | Out-Null
                    Write-Host "  Fixed Build step in $btId (cmd/workorders)" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host "  Error fixing $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Green