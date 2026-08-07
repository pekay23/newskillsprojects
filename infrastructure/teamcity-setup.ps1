# teamcity-setup.ps1 - Creates the Dev/Staging/Prod build configurations in TeamCity
# Usage: .\infrastructure\teamcity-setup.ps1 -Username "pekay" -Password "yourpw"
#
# Optional: -GitHubToken "ghp_xxx" (if the repo is private, pass a PAT)
#
# This script creates:
#   - Project: Raymond Gray IFM
#   - VCS Root: newskillsprojects-github
#   - Build configs for 6 services x 3 environments (dev/staging/prod)

param(
    [string]$TeamCityUrl = "http://localhost:8111",
    [string]$Username = "pekay",
    [string]$Password = "",
    [string]$GitHubUrl = "https://github.com/pekay23/newskillsprojects.git",
    [string]$GitHubToken = ""
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

try {
    $server = Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/server" -Headers $headers -Method Get
    Write-Host "Connected to TeamCity $($server.version)" -ForegroundColor Green
} catch {
    Write-Host "Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$projectId = "RaymondGrayIFM"
$projectName = "Raymond Gray IFM"
$vcsRootId = "newskillsprojects_github"
$vcsRootName = "newskillsprojects-github"

# ================================================================
# 1. CREATE PROJECT
# ================================================================
Write-Host "`n[1/5] Creating project '$projectName'..." -ForegroundColor Yellow
try {
    $projectBody = @{ id = $projectId; name = $projectName; description = "Raymond Gray IFM - polyglot microservices platform" } | ConvertTo-Json
    Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/projects" -Headers $headers -Method Post -Body $projectBody | Out-Null
    Write-Host "  Project created" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "already exists") { Write-Host "  Project already exists" -ForegroundColor Yellow }
    else { Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red }
}

# ================================================================
# 2. CREATE VCS ROOT
# ================================================================
Write-Host "`n[2/5] Creating VCS Root '$vcsRootName'..." -ForegroundColor Yellow

# Decide auth method: use PAT if provided, otherwise anonymous (public repo)
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
        # Continue anyway - build configs can still reference it if it exists
    }
}

# ================================================================
# 3. CREATE BUILD CONFIG SHELLS (no steps/triggers yet)
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

Write-Host "`n[3/5] Creating build configuration shells..." -ForegroundColor Yellow

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
            elseif ($_.Exception.Message -match "400") {
                Write-Host "    Bad request - body: $btBody" -ForegroundColor DarkYellow
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            }
            else { Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
}

# ================================================================
# 4. ATTACH VCS ROOT TO EACH BUILD CONFIG
# ================================================================
Write-Host "`n[4/5] Attaching VCS root to build configs..." -ForegroundColor Yellow

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env.name)"
        $btName = "$($service.name)-$($env.name)"

        Write-Host "  Attaching VCS to $btName..." -ForegroundColor Gray
        try {
            $vcsEntry = '{"vcs-root": {"id": "' + $vcsRootId + '"}}'
            Invoke-RestMethod -Uri "$TeamCityUrl/app/rest/buildTypes/$btId/vcs-root-entries" -Headers $headers -Method Post -Body $vcsEntry | Out-Null
            Write-Host "    VCS attached" -ForegroundColor Green
        } catch {
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ================================================================
# 5. ADD TRIGGERS (VCS trigger with branch filter)
# ================================================================
Write-Host "`n[5/5] Adding VCS triggers..." -ForegroundColor Yellow

foreach ($service in $services) {
    foreach ($env in $environments) {
        $btId = "$($service.name -replace '-', '_')_$($env.name)"
        $btName = "$($service.name)-$($env.name)"

        Write-Host "  Adding trigger to $btName..." -ForegroundColor Gray
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
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host "`n=== Setup complete! ===" -ForegroundColor Green
Write-Host "  Project: $projectName"
Write-Host "  VCS Root: $vcsRootName -> $GitHubUrl"
Write-Host "  18 build configs created (6 services x dev/staging/prod)"
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Yellow
Write-Host "  1. Open TeamCity at $TeamCityUrl"
Write-Host "  2. Go to each build config -> Build Steps -> add the actual build commands"
Write-Host "     e.g. go: 'go build -o bin/server ./cmd/server' (working dir: rg-workorder-service)"
Write-Host "  3. If the repo is private, set the GitHub PAT in the VCS root settings"
Write-Host "  4. Create dev and staging branches in GitHub"
Write-Host "  5. Set up GitHub branch protection rules"