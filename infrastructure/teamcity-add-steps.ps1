# teamcity-add-steps.ps1 - Adds actual build steps to the TeamCity build configs
# Usage: .\infrastructure\teamcity-add-steps.ps1 -Username "pekay" -Password "yourpw"
#
# Adds the correct build commands for each service to its dev/staging/prod configs.

param(
    [string]$TeamCityUrl = "http://localhost:8111",
    [string]$Username = "pekay",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

$pair = "${Username}:${Password}"
$base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    "Authorization" = "Basic $base64"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

Write-Host "=== Adding Build Steps to TeamCity Configs ===" -ForegroundColor Cyan

# Service definitions with their build steps
$services = @(
    @{
        name = "rg-workorder"
        folder = "rg-workorder-service"
        steps = @(
            @{ name = "Lint"; cmd = "go vet ./... && golangci-lint run" },
            @{ name = "Test"; cmd = "go test ./... -race -coverprofile=coverage.out" },
            @{ name = "Build"; cmd = "go build -o bin/server ./cmd/server" }
        )
    },
    @{
        name = "rg-cmms"
        folder = "rg-cmms-service"
        steps = @(
            @{ name = "Restore"; cmd = "dotnet restore" },
            @{ name = "Build"; cmd = "dotnet build --no-restore --configuration Release" },
            @{ name = "Test"; cmd = "dotnet test --no-build --configuration Release" }
        )
    },
    @{
        name = "rg-helpdesk"
        folder = "rg-helpdesk-service"
        steps = @(
            @{ name = "Install"; cmd = "pip install -r requirements.txt" },
            @{ name = "Lint"; cmd = "ruff check . && mypy ." },
            @{ name = "Test"; cmd = "pytest tests/ -v" }
        )
    },
    @{
        name = "rg-api-gateway"
        folder = "rg-api-gateway"
        steps = @(
            @{ name = "Lint"; cmd = "go vet ./..." },
            @{ name = "Test"; cmd = "go test ./..." },
            @{ name = "Build"; cmd = "go build -o rg-api-gateway.exe ./cmd/gateway" }
        )
    },
    @{
        name = "rg-sync-agent"
        folder = "rg-sync-agent"
        steps = @(
            @{ name = "Test"; cmd = "go test ./..." },
            @{ name = "Build"; cmd = "go build -o rg-sync-agent.exe ./cmd/syncagent" }
        )
    },
    @{
        name = "rg-report-engine"
        folder = "rg-report-engine"
        steps = @(
            @{ name = "Bundle Install"; cmd = "bundle install" },
            @{ name = "Lint"; cmd = "bundle exec rubocop" },
            @{ name = "Test"; cmd = "bundle exec rspec --format documentation" }
        )
    }
)

$environments = @("dev", "staging", "prod")

$totalAdded = 0

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env)"
        $btName = "$($service.name)-$($env)"

        Write-Host "`nAdding steps to $btName..." -ForegroundColor Yellow

        foreach ($step in $service.steps) {
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

            try {
                Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/steps" -Headers $headers -Method Post -Body $stepBody | Out-Null
                Write-Host "  + $($step.name): $($step.cmd)" -ForegroundColor Green
                $totalAdded++
            } catch {
                Write-Host "  ! Failed to add $($step.name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n=== Done! Added $totalAdded build steps across 18 configs ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Open TeamCity at $TeamCityUrl and verify the build steps."
Write-Host "Each step's working directory should be set to the service folder (e.g., $($services[0].folder))."