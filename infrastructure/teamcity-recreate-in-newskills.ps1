# teamcity-recreate-in-newskills.ps1 - Deletes rg-* configs from RaymondGrayPlatform and recreates them in Newskillsprojects
# Usage: .\infrastructure\teamcity-recreate-in-newskills.ps1
#
# Because TeamCity build type IDs are globally unique, we must DELETE the
# rg_* build types from RaymondGrayPlatform, then recreate them in Newskillsprojects.

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
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

$projectId = "Newskillsprojects"
$vcsRootId = "Newskillsprojects_HttpsGithubComPekay23newskillsprojectsRefsHeadsMain"

$buildTypeIds = @(
    "rg_workorder_dev", "rg_workorder_staging", "rg_workorder_prod",
    "rg_cmms_dev", "rg_cmms_staging", "rg_cmms_prod",
    "rg_helpdesk_dev", "rg_helpdesk_staging", "rg_helpdesk_prod",
    "rg_api_gateway_dev", "rg_api_gateway_staging", "rg_api_gateway_prod",
    "rg_sync_agent_dev", "rg_sync_agent_staging", "rg_sync_agent_prod",
    "rg_report_engine_dev", "rg_report_engine_staging", "rg_report_engine_prod"
)

# ================================================================
# STEP 1: DELETE old build configs from RaymondGrayPlatform
# ================================================================
Write-Host "=== Step 1: Deleting old build configs from RaymondGrayPlatform ===" -ForegroundColor Cyan

foreach ($bt in $buildTypeIds) {
    try {
        Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$bt" -Headers $headers -Method Delete | Out-Null
        Write-Host "  Deleted $bt" -ForegroundColor Green
    } catch {
        Write-Host "  Failed to delete $bt : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# STEP 2: Recreate build configs in Newskillsprojects
# ================================================================
Write-Host "`n=== Step 2: Creating build configs in Newskillsprojects ===" -ForegroundColor Cyan

$services = @(
    @{ name = "rg-workorder"; folder = "rg-workorder-service" },
    @{ name = "rg-cmms"; folder = "rg-cmms-service" },
    @{ name = "rg-helpdesk"; folder = "rg-helpdesk-service" },
    @{ name = "rg-api-gateway"; folder = "rg-api-gateway" },
    @{ name = "rg-sync-agent"; folder = "rg-sync-agent" },
    @{ name = "rg-report-engine"; folder = "rg-report-engine" }
)

$environments = @(
    @{ name = "dev"; branch = "dev"; desc = "Development" },
    @{ name = "staging"; branch = "staging"; desc = "Staging/QA" },
    @{ name = "prod"; branch = "main"; desc = "Production" }
)

$serviceSteps = @{
    "rg-workorder" = @(
        @{ name = "Lint"; cmd = "go vet ./... && golangci-lint run" },
        @{ name = "Test"; cmd = "go test ./... -race -coverprofile=coverage.out" },
        @{ name = "Build"; cmd = "go build -o bin/server ./cmd/server" }
    )
    "rg-cmms" = @(
        @{ name = "Restore"; cmd = "dotnet restore" },
        @{ name = "Build"; cmd = "dotnet build --no-restore --configuration Release" },
        @{ name = "Test"; cmd = "dotnet test --no-build --configuration Release" }
    )
    "rg-helpdesk" = @(
        @{ name = "Install"; cmd = "pip install -r requirements.txt" },
        @{ name = "Lint"; cmd = "ruff check . && mypy ." },
        @{ name = "Test"; cmd = "pytest tests/ -v" }
    )
    "rg-api-gateway" = @(
        @{ name = "Lint"; cmd = "go vet ./..." },
        @{ name = "Test"; cmd = "go test ./..." },
        @{ name = "Build"; cmd = "go build -o rg-api-gateway.exe ./cmd/gateway" }
    )
    "rg-sync-agent" = @(
        @{ name = "Test"; cmd = "go test ./..." },
        @{ name = "Build"; cmd = "go build -o rg-sync-agent.exe ./cmd/syncagent" }
    )
    "rg-report-engine" = @(
        @{ name = "Bundle Install"; cmd = "bundle install" },
        @{ name = "Lint"; cmd = "bundle exec rubocop" },
        @{ name = "Test"; cmd = "bundle exec rspec --format documentation" }
    )
}

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env.name)"
        $btName = "$($service.name)-$($env.name)"
        $btDesc = "Builds and tests $($service.name) on the $($env.branch) branch. $($env.desc) environment."

        Write-Host "  Creating $btName..." -ForegroundColor Gray

        # Create build type
        try {
            $btBody = @{
                id = $btId
                name = $btName
                project = @{ id = $projectId }
                description = $btDesc
            } | ConvertTo-Json -Depth 3

            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes" -Headers $headers -Method Post -Body $btBody | Out-Null
            Write-Host "    Created" -ForegroundColor Green
        } catch {
            Write-Host "    Create error: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }

        # Attach VCS root
        try {
            $vcsEntry = '{"vcs-root": {"id": "' + $vcsRootId + '"}}'
            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/vcs-root-entries" -Headers $headers -Method Post -Body $vcsEntry | Out-Null
            Write-Host "    VCS attached" -ForegroundColor Green
        } catch {
            Write-Host "    VCS error: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Add VCS trigger
        try {
            $triggerBody = @{
                type = "vcsTrigger"
                properties = @{
                    property = @(
                        @{ name = "branchFilter"; value = "+:$($env.branch)" },
                        @{ name = "groupingPolicy"; value = "DONT_GROUP" }
                    )
                }
            } | ConvertTo-Json -Depth 5

            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/triggers" -Headers $headers -Method Post -Body $triggerBody | Out-Null
            Write-Host "    Trigger added" -ForegroundColor Green
        } catch {
            Write-Host "    Trigger error: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Add build steps
        $steps = $serviceSteps[$service.name]
        foreach ($step in $steps) {
            try {
                $stepBody = @{
                    name = $step.name
                    type = "simpleRunner"
                    properties = @{
                        property = @(
                            @{ name = "script.content"; value = $step.cmd },
                            @{ name = "teamcity.step.mode"; value = "default" },
                            @{ name = "use.custom.script"; value = "true" }
                        )
                    }
                } | ConvertTo-Json -Depth 5

                Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Post -Body $stepBody | Out-Null
                Write-Host "    Step: $($step.name)" -ForegroundColor Green
            } catch {
                Write-Host "    Step error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# ================================================================
# VERIFICATION
# ================================================================
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
try {
    $b = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes?locator=project:Newskillsprojects" -Headers $headers -Method Get
    Write-Host "Build configs in Newskillsprojects: $($b.buildType.Count)"
    if ($b.buildType) {
        $b.buildType | ForEach-Object { Write-Host "  $($_.name) (id: $($_.id))" }
    }
} catch {
    Write-Host "Error verifying: $($_.Exception.Message)" -ForegroundColor Red
}