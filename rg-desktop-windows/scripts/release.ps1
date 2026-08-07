# release.ps1 - Build, sign, and prepare a Tauri desktop app release
# Usage: .\scripts\release.ps1 -Version "1.1.0" -SigningKey "path\to\private.key"
#
# Prerequisites:
#   - Rust toolchain + MSVC Build Tools (for tauri build)
#   - Tauri signing key pair (generate with: tauri signer generate -w ~/.tauri/myapp.key)
#   - GitHub CLI (gh) for creating releases

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [Parameter(Mandatory=$true)]
    [string]$SigningKey,
    [string]$Repo = "pekay23/newskillsprojects"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

Write-Host "=== Raymond Gray IFM Desktop Release v$Version ===" -ForegroundColor Cyan

# 1. Update version in package.json and tauri.conf.json
Write-Host "`n[1/6] Updating version to $Version..." -ForegroundColor Yellow
$pkg = Get-Content package.json | ConvertFrom-Json
$pkg.version = $Version
$pkg | ConvertTo-Json -Depth 10 | Set-Content package.json

$tauriConf = Get-Content src-tauri/tauri.conf.json | ConvertFrom-Json
$tauriConf.version = $Version
$tauriConf | ConvertTo-Json -Depth 10 | Set-Content src-tauri/tauri.conf.json

# 2. Build the frontend
Write-Host "`n[2/6] Building frontend (TypeScript + Vite)..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) { throw "Frontend build failed" }

# 3. Build the Tauri bundle
Write-Host "`n[3/6] Building Tauri desktop bundle..." -ForegroundColor Yellow
npm run tauri build
if ($LASTEXITCODE -ne 0) { throw "Tauri build failed" }

# 4. Sign the installer
Write-Host "`n[4/6] Signing installer..." -ForegroundColor Yellow
$installer = Get-ChildItem "src-tauri/target/release/bundle/msi/*.msi" | Select-Object -First 1
if (-not $installer) {
    $installer = Get-ChildItem "src-tauri/target/release/bundle/nsis/*.exe" | Select-Object -First 1
}
if (-not $installer) { throw "No installer found in bundle output" }

Write-Host "  Installer: $($installer.FullName)"
$sigFile = "$($installer.FullName).sig"
& "$env:USERPROFILE\.cargo\bin\tauri" signer sign -k $SigningKey $installer.FullName
if ($LASTEXITCODE -ne 0) { throw "Signing failed" }

# 5. Generate latest.json manifest
Write-Host "`n[5/6] Generating latest.json..." -ForegroundColor Yellow
$installerName = $installer.Name
$installerSize = (Get-Item $installer.FullName).Length
$signature = (Get-Content $sigFile -Raw).Trim()

$latestJson = @{
    version = $Version
    notes = "Raymond Gray IFM v$Version"
    pub_date = (Get-Date).ToUniversalTime().ToString("o")
    platforms = @{
        "windows-x86_64" = @{
            signature = $signature
            url = "https://github.com/$Repo/releases/latest/download/$installerName"
        }
    }
} | ConvertTo-Json -Depth 10

$latestJsonPath = Join-Path $ProjectRoot "latest.json"
$latestJson | Set-Content $latestJsonPath
Write-Host "  Manifest: $latestJsonPath"

# 6. Create GitHub release and upload assets
Write-Host "`n[6/6] Publishing to GitHub Releases..." -ForegroundColor Yellow
gh release create "v$Version" `
    --repo $Repo `
    --title "Raymond Gray IFM v$Version" `
    --notes "Release v$Version of the Raymond Gray IFM desktop app." `
    $installer.FullName `
    $sigFile `
    $latestJsonPath

if ($LASTEXITCODE -ne 0) { throw "GitHub release failed" }

Write-Host "`n=== Release v$Version published successfully! ===" -ForegroundColor Green
Write-Host "Clients will auto-update on next app launch."