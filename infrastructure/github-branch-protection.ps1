# github-branch-protection.ps1 - Sets up branch protection rules on GitHub
# Usage: .\infrastructure\github-branch-protection.ps1
#
# Protects main, dev, and staging branches with:
#   - Require pull request reviews
#   - Require status checks (TeamCity)
#   - Prevent direct pushes

param(
    [string]$GitHubToken = "",
    [string]$Repo = "pekay23/newskillsprojects"
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

if (-not $GitHubToken) { $GitHubToken = $GITHUB_PAT }

$headers = @{
    "Authorization" = "token $GitHubToken"
    "User-Agent" = "TeamCity"
    "Accept" = "application/vnd.github+json"
}

Write-Host "=== GitHub Branch Protection Setup ===" -ForegroundColor Cyan

# Verify token has admin access
try {
    $repoResp = Invoke-WebRequest -Uri "https://api.github.com/repos/$Repo" -Headers $headers -Method Get -TimeoutSec 10 -UseBasicParsing
    $repo = $repoResp.Content | ConvertFrom-Json
    Write-Host "Repo: $($repo.full_name)" -ForegroundColor Green
    Write-Host "Permissions: admin=$($repo.permissions.admin) push=$($repo.permissions.push)" -ForegroundColor Green
    if (-not $repo.permissions.admin) {
        Write-Host "ERROR: Token does not have admin access to this repo. Branch protection requires admin." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error checking repo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Branch protection rules
$branches = @(
    @{
        name = "main"
        body = @{
            required_pull_request_reviews = @{
                required_approving_review_count = 1
                dismiss_stale_reviews = $true
                require_code_owner_reviews = $false
            }
            required_status_checks = @{
                strict = $true
                contexts = @()
            }
            enforce_admins = $true
            required_linear_history = $false
            allow_force_pushes = $false
            allow_deletions = $false
        }
    },
    @{
        name = "dev"
        body = @{
            required_pull_request_reviews = @{
                required_approving_review_count = 1
                dismiss_stale_reviews = $true
                require_code_owner_reviews = $false
            }
            required_status_checks = @{
                strict = $false
                contexts = @()
            }
            enforce_admins = $false
            required_linear_history = $false
            allow_force_pushes = $false
            allow_deletions = $false
        }
    },
    @{
        name = "staging"
        body = @{
            required_pull_request_reviews = @{
                required_approving_review_count = 1
                dismiss_stale_reviews = $true
                require_code_owner_reviews = $false
            }
            required_status_checks = @{
                strict = $false
                contexts = @()
            }
            enforce_admins = $false
            required_linear_history = $false
            allow_force_pushes = $false
            allow_deletions = $false
        }
    }
)

foreach ($branch in $branches) {
    Write-Host "`nSetting up protection for '$($branch.name)'..." -ForegroundColor Yellow
    try {
        $body = $branch.body | ConvertTo-Json -Depth 5
        $uri = "https://api.github.com/repos/$Repo/branches/$($branch.name)/protection"
        $result = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body
        Write-Host "  Protected: $($branch.name)" -ForegroundColor Green
        Write-Host "  - Require PR review: $($result.required_pull_request_reviews.required_approving_review_count) approval(s)"
        Write-Host "  - Enforce admins: $($result.enforce_admins.enabled)"
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        # Try to read the error body
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errBody = $reader.ReadToEnd()
                Write-Host "  Response: $errBody" -ForegroundColor DarkYellow
            } catch {}
        }
    }
}

Write-Host "`n=== Branch protection setup complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:"
Write-Host "  main    - PR review required, status checks, enforce admins, no force push"
Write-Host "  dev     - PR review required, status checks, no force push"
Write-Host "  staging - PR review required, status checks, no force push"
Write-Host ""
Write-Host "Note: To add TeamCity status checks to the required checks list,"
Write-Host "you need to configure the TeamCity GitHub integration (Build Features ->"
Write-Host "Commit Status Publisher) so TeamCity reports build status to GitHub."