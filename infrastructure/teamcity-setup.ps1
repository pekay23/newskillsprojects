# teamcity-setup.ps1 - Creates the Dev/Staging/Prod build configurations in TeamCity
# Usage: .\infrastructure\teamcity-setup.ps1 -Username "pekay" -Password "yourpw"
#
# Creates build configs in the existing "Raymond Gray Platform" project.
# Optional: -GitHubToken "ghp_xxx" (if the repo is private, pass a PAT)

param(
    [string]$TeamCityUrl = "",
    [string]$Username = "",
    [string]$Password = "",
    [string]$GitHubUrl = "",
    [string]$GitHubToken = ""
)

$ErrorActionPreference = "Stop"

# ================================================================
# LOAD CREDENTIALS FROM .env FILE (gitignored, safe)
# ================================================================
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Write-Host "Loading credentials from $envFile..." -ForegroundColor Gray
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)="?(.+?)"?\s*$') {
            $name = $Matches[1]
            $value = $Matches[2]
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}

# Use .env values as defaults if params not provided
if (-not $TeamCityUrl) { $TeamCityUrl = $TEAMCITY_URL }
if (-not $Username) { $Username = $TEAMCITY_USERNAME }
if (-not $Password) { $Password = $TEAMCITY_PASSWORD }
if (-not $GitHubUrl) { $GitHubUrl = $GITHUB_REPO_URL }
if (-not $GitHubToken) { $GitHubToken = $GITHUB_PAT }

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

try {
    $server = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/server" -Headers $headers -Method Get
    Write-Host "Connected to TeamCity $($server.version)" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Target the existing project
$projectId = "RaymondGrayPlatform"
$projectName = "Raymond Gray Platform"
$vcsRootId = "newskillsprojects_github"
$vcsRootName = "newskillsprojects-github"

# ================================================================
# 1. CREATE VCS ROOT (in the existing project)
# ================================================================
Write-Host "`n[1/4] Creating VCS Root '$vcsRootName' in '$projectName'..." -ForegroundColor Yellow

$authMethod = "ANONYMOUS"
$vcsProps = @(
    @{ name = "url"; value = $GitHubUrl },
    @{ name = "authMethod"; value = $authMethod },
    @{ name = "branch"; value = "refs/heads/main" }
)

if (-not [string]::IsNullOrWhiteSpace($GitHubToken)) {
    Write-Host "  Using GitHub PAT for authentication" -ForegroundColor Gray
    $vcsProps = @(
        @{ name = "url"; value = $GitHubUrl },
        @{ name = "authMethod"; value = "PASSWORD" },
        @{ name = "username"; value = "pekay23" },
        @{ name = "password"; value = $GitHubToken },
        @{ name = "branch"; value = "refs/heads/main" }
    )
}

try {
    $vcsBody = @{
        id = $vcsRootId
        name = $vcsRootName
        vcsName = "jetbrains.git"
        project = @{ id = $projectId }
        properties = @{ property = $vcsProps }
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
# 2. CREATE BUILD CONFIG SHELLS
# ================================================================
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

Write-Host "`n[2/4] Creating build configuration shells..." -ForegroundColor Yellow

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env.name)"
        $btName = "$($service.name)-$($env.name)"
        $btDesc = "Builds and tests $($service.name) on the $($env.branch) branch. $($env.desc) environment."

        Write-Host "  Creating $btName..." -ForegroundColor Gray
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
            if ($_.Exception.Message -match "already exists") { Write-Host "    Already exists" -ForegroundColor Yellow }
            else { Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
}

# ================================================================
# 3. ATTACH VCS ROOT + ADD TRIGGERS + ADD STEPS
# ================================================================
Write-Host "`n[3/4] Attaching VCS, adding triggers and steps..." -ForegroundColor Yellow

# Build step definitions per service
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

        # Attach VCS root
        Write-Host "  ${btName}: attaching VCS..." -ForegroundColor Gray
        try {
            $vcsEntry = '{"vcs-root": {"id": "' + $vcsRootId + '"}}'
            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/vcs-root-entries" -Headers $headers -Method Post -Body $vcsEntry | Out-Null
            Write-Host "    VCS attached" -ForegroundColor Green
        } catch {
            Write-Host "    VCS error: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Add VCS trigger with branch filter
        Write-Host "  ${btName}: adding trigger..." -ForegroundColor Gray
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
            Write-Host "  ${btName}: adding step '$($step.name)'..." -ForegroundColor Gray
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
                Write-Host "    Step added" -ForegroundColor Green
            } catch {
                Write-Host "    Step error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host "`n[4/4] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "=== Created in project: $projectName ===" -ForegroundColor Cyan
Write-Host "  VCS Root: $vcsRootName -> $GitHubUrl"
Write-Host "  18 build configs (6 services x dev/staging/prod)"
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Yellow
Write-Host "  1. Open TeamCity at $TeamCityUrl"
Write-Host "  2. Go to each build config -> Build Steps -> set Working directory to the service folder"
Write-Host "  3. Create dev and staging branches in GitHub"
Write-Host "  4. Set up GitHub branch protection rules"