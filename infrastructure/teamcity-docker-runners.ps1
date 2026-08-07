# teamcity-docker-runners.ps1 - Converts TeamCity build configs to use Docker builds
# Usage: .\infrastructure\teamcity-docker-runners.ps1
#
# Converts each service build config to build its Docker image using the service's
# own Dockerfile (which pins the correct toolchain: golang, dotnet, python, ruby).
#   - rg-workorder     -> docker build ./rg-workorder-service
#   - rg-cmms          -> docker build ./rg-cmms-service
#   - rg-helpdesk      -> docker build ./rg-helpdesk-service
#   - rg-api-gateway   -> docker build ./rg-api-gateway
#   - rg-sync-agent    -> docker build ./rg-sync-agent
#   - rg-report-engine -> docker build ./rg-report-engine
#
# This eliminates "tool not installed on agent" and "working directory" problems.

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

Write-Host "=== Converting Build Configs to Docker Builds ===" -ForegroundColor Cyan

# Helper: clear all steps from a build type
function Clear-Steps {
    param($btId)
    try {
        $steps = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Get
        if ($steps.step) {
            foreach ($step in $steps.step) {
                Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps/$($step.id)" -Headers $headers -Method Delete | Out-Null
            }
            Write-Host "  Cleared steps from $btId" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Error clearing $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Helper: add a single docker build step with correct working directory
function Add-DockerBuildStep {
    param($btId, $stepName, $imageTag, $workingDir)
    try {
        $cmd = "docker build -t $imageTag ."
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
        Write-Host "  Added '$stepName' -> $cmd (workingDir: $workingDir)" -ForegroundColor Green
    } catch {
        Write-Host "  Error adding step to $btId : $($_.Exception.Message)" -ForegroundColor Red
    }
}

$serviceMap = @(
    @{ bt = "rg_workorder_"; tag = "rg-workorder:ci"; folder = "rg-workorder-service" },
    @{ bt = "rg_cmms_"; tag = "rg-cmms:ci"; folder = "rg-cmms-service" },
    @{ bt = "rg_helpdesk_"; tag = "rg-helpdesk:ci"; folder = "rg-helpdesk-service" },
    @{ bt = "rg_api_gateway_"; tag = "rg-api-gateway:ci"; folder = "rg-api-gateway" },
    @{ bt = "rg_sync_agent_"; tag = "rg-sync-agent:ci"; folder = "rg-sync-agent" },
    @{ bt = "rg_report_engine_"; tag = "rg-report-engine:ci"; folder = "rg-report-engine" }
)

$environments = @("dev", "staging", "prod")

foreach ($svc in $serviceMap) {
    foreach ($env in $environments) {
        $btId = "$($svc.bt)$env"
        Write-Host "`nConverting $btId..." -ForegroundColor Yellow
        Clear-Steps $btId
        Add-DockerBuildStep $btId "Docker Build" "$($svc.tag)-$env" $svc.folder
        Write-Host "  $btId -> Docker build configured" -ForegroundColor Green
    }
}

Write-Host "`n=== Docker build conversion complete ===" -ForegroundColor Green
Write-Host "  Each service now builds via its own Dockerfile (toolchain in container)"
Write-Host "  Tags: rg-<service>:ci-<env>"
Write-Host ""
Write-Host "Note: Docker Desktop must be running for these builds to work."