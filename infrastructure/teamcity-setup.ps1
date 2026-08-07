# teamcity-setup.ps1 - Creates the Dev/Staging/Prod build configurations in TeamCity
# Usage: .\infrastructure\teamcity-setup.ps1 -TeamCityUrl "http://localhost:8111" -Username "admin" -Password "yourpassword"
#
# This script creates:
#   - VCS Root: newskillsprojects-github
#   - Project: Raymond Gray IFM
#   - Build configs: rg-workorder-dev, rg-workorder-staging, rg-workorder-prod
#   - Build configs: rg-cmms-dev, rg-cmms-staging, rg-cmms-prod
#   - Build configs: rg-helpdesk-dev, rg-helpdesk-staging, rg-helpdesk-prod
#   - Build configs: rg-api-gateway-dev, rg-api-gateway-staging, rg-api-gateway-prod
#   - Build configs: rg-sync-agent-dev, rg-sync-agent-staging, rg-sync-agent-prod
#   - Build configs: rg-report-engine-dev, rg-report-engine-staging, rg-report-engine-prod

param(
    [string]$TeamCityUrl = "http://localhost:8111",
    [string]$Username = "admin",
    [string]$Password = "",
    [string]$GitHubUrl = "https://github.com/pekay23/newskillsprojects.git"
)

$ErrorActionPreference = "Stop"

# ================================================================
# AUTHENTICATION
# ================================================================
$pair = "${Username}:${Password}"
$base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{
    "Authorization" = "Basic $base64"
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

Write-Host "=== TeamCity Build Setup ===" -ForegroundColor Cyan
Write-Host "Connecting to $TeamCityUrl as $Username..."

# Test connection
try {
    $server = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/server" -Headers $headers -Method Get
    Write-Host "Connected to TeamCity $($server.version)" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check your username/password and that TeamCity is running."
    exit 1
}

# ================================================================
# CREATE PROJECT
# ================================================================
$projectId = "RaymondGrayIFM"
$projectName = "Raymond Gray IFM"

Write-Host "`n[1/4] Creating project '$projectName'..." -ForegroundColor Yellow
try {
    $projectBody = @{
        id = $projectId
        name = $projectName
        description = "Raymond Gray IFM - polyglot microservices platform"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/projects" -Headers $headers -Method Post -Body $projectBody | Out-Null
    Write-Host "  Project created" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "already exists") {
        Write-Host "  Project already exists" -ForegroundColor Yellow
    } else {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# CREATE VCS ROOT
# ================================================================
$vcsRootId = "newskillsprojects_github"
$vcsRootName = "newskillsprojects-github"

Write-Host "`n[2/4] Creating VCS Root '$vcsRootName'..." -ForegroundColor Yellow
try {
    $vcsBody = @{
        id = $vcsRootId
        name = $vcsRootName
        project = @{ id = $projectId }
        properties = @{
            property = @(
                @{ name = "url"; value = $GitHubUrl },
                @{ name = "authMethod"; value = "PASSWORD" },
                @{ name = "username"; value = "" },
                @{ name = "password"; value = "" },
                @{ name = "branch"; value = "refs/heads/main" }
            )
        }
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/vcs-roots" -Headers $headers -Method Post -Body $vcsBody | Out-Null
    Write-Host "  VCS Root created" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "already exists") {
        Write-Host "  VCS Root already exists" -ForegroundColor Yellow
    } else {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ================================================================
# BUILD CONFIGURATIONS
# ================================================================
$services = @(
    @{ name = "rg-workorder"; lang = "go"; buildSteps = @(
        @{ name = "Lint"; runner = "simpleRunner"; cmd = "go vet ./... && golangci-lint run" },
        @{ name = "Test"; runner = "simpleRunner"; cmd = "go test ./... -race -coverprofile=coverage.out" },
        @{ name = "Build"; runner = "simpleRunner"; cmd = "go build -o bin/server ./cmd/server" }
    )},
    @{ name = "rg-cmms"; lang = "dotnet"; buildSteps = @(
        @{ name = "Restore"; runner = "simpleRunner"; cmd = "dotnet restore" },
        @{ name = "Build"; runner = "simpleRunner"; cmd = "dotnet build --no-restore --configuration Release" },
        @{ name = "Test"; runner = "simpleRunner"; cmd = "dotnet test --no-build --configuration Release" }
    )},
    @{ name = "rg-helpdesk"; lang = "python"; buildSteps = @(
        @{ name = "Install"; runner = "simpleRunner"; cmd = "pip install -r requirements.txt" },
        @{ name = "Lint"; runner = "simpleRunner"; cmd = "ruff check . && mypy ." },
        @{ name = "Test"; runner = "simpleRunner"; cmd = "pytest tests/ -v" }
    )},
    @{ name = "rg-api-gateway"; lang = "go"; buildSteps = @(
        @{ name = "Lint"; runner = "simpleRunner"; cmd = "go vet ./..." },
        @{ name = "Test"; runner = "simpleRunner"; cmd = "go test ./..." },
        @{ name = "Build"; runner = "simpleRunner"; cmd = "go build -o rg-api-gateway.exe ./cmd/gateway" }
    )},
    @{ name = "rg-sync-agent"; lang = "go"; buildSteps = @(
        @{ name = "Test"; runner = "simpleRunner"; cmd = "go test ./..." },
        @{ name = "Build"; runner = "simpleRunner"; cmd = "go build -o rg-sync-agent.exe ./cmd/syncagent" }
    )},
    @{ name = "rg-report-engine"; lang = "ruby"; buildSteps = @(
        @{ name = "Bundle Install"; runner = "simpleRunner"; cmd = "bundle install" },
        @{ name = "Lint"; runner = "simpleRunner"; cmd = "bundle exec rubocop" },
        @{ name = "Test"; runner = "simpleRunner"; cmd = "bundle exec rspec --format documentation" }
    )}
)

$environments = @(
    @{ name = "dev"; branch = "dev"; tag = "dev" },
    @{ name = "staging"; branch = "staging"; tag = "staging" },
    @{ name = "prod"; branch = "main"; tag = "prod" }
)

Write-Host "`n[3/4] Creating build configurations..." -ForegroundColor Yellow

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env.name)"
        $btName = "$($service.name)-$($env.name)"
        $btDesc = "Builds and tests $($service.name) on the $($env.branch) branch. Deploys to $($env.name) environment."

        Write-Host "  Creating $btName..." -ForegroundColor Gray
        try {
            $btBody = @{
                id = $btId
                name = $btName
                project = @{ id = $projectId }
                description = $btDesc
                paused = $false
                vcsRootEntries = @{
                    vcsRootEntry = @(
                        @{
                            vcs-root = @{ id = $vcsRootId }
                            checkout-rules = ""
                        }
                    )
                }
                settings = @{
                    property = @(
                        @{ name = "buildNumberFormat"; value = "%build.counter%" },
                        @{ name = "teamcity.ui.buildView.showAgentTab"; value = "true" }
                    )
                }
                steps = @{
                    step = @(
                        @{
                            name = "Build"
                            type = "simpleRunner"
                            properties = @{
                                property = @(
                                    @{ name = "script.content"; value = "echo Building $($service.name) for $($env.name)" },
                                    @{ name = "teamcity.step.mode"; value = "default" }
                                )
                            }
                        }
                    )
                }
                triggers = @{
                    trigger = @(
                        @{
                            type = "vcsTrigger"
                            properties = @{
                                property = @(
                                    @{ name = "branchFilter"; value = "+:$($env.branch)" },
                                    @{ name = "groupingPolicy"; value = "DONT_GROUP" }
                                )
                            }
                        }
                    )
                }
            } | ConvertTo-Json -Depth 10

            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes" -Headers $headers -Method Post -Body $btBody | Out-Null
            Write-Host "    Created" -ForegroundColor Green
        } catch {
            if ($_.Exception.Message -match "already exists") {
                Write-Host "    Already exists" -ForegroundColor Yellow
            } else {
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host "`n[4/4] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "=== Created Build Configurations ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project: Raymond Gray IFM"
Write-Host "  VCS Root: newskillsprojects-github -> $GitHubUrl"
Write-Host ""
Write-Host "  Services (6) x Environments (3) = 18 build configs:"
Write-Host ""
foreach ($service in $services) {
    Write-Host "  $($service.name):"
    foreach ($env in $environments) {
        Write-Host "    - $($service.name)-$($env.name)  (branch: $($env.branch))"
    }
    Write-Host ""
}
Write-Host "=== Next Steps ===" -ForegroundColor Yellow
Write-Host "  1. Open TeamCity at $TeamCityUrl"
Write-Host "  2. Go to each build config and add the actual build steps (the script creates placeholders)"
Write-Host "  3. Set up GitHub branch protection rules"
Write-Host "  4. Create the dev, staging, and main branches in GitHub"