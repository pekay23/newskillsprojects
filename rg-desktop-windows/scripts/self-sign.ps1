# self-sign.ps1 - Creates a self-signed certificate and signs the Tauri Windows installer
# Usage: .\scripts\self-sign.ps1
#
# This creates a self-signed code-signing cert and uses it to sign the built
# installer so Windows SmartScreen shows "Unknown publisher" instead of blocking.
# NOTE: Self-signed certs still show a warning - only a trusted CA cert removes it.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

Write-Host "=== Self-Sign Windows Installer ===" -ForegroundColor Cyan

# 1. Create a self-signed code-signing certificate
$certName = "Raymond Gray IFM"
$certPath = Join-Path $ProjectRoot "src-tauri\codesign.pfx"

Write-Host "`n[1/3] Creating self-signed certificate..." -ForegroundColor Yellow
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject "CN=$certName" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(3)

# Export to PFX (needs a password)
$password = Read-Host "Enter a password to protect the PFX file" -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $password | Out-Null
Write-Host "  Certificate created: $certPath" -ForegroundColor Green
Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# 2. Find the built installer
Write-Host "`n[2/3] Finding installer..." -ForegroundColor Yellow
$installer = Get-ChildItem "src-tauri\target\release\bundle\msi\*.msi" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $installer) {
    $installer = Get-ChildItem "src-tauri\target\release\bundle\nsis\*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $installer) {
    Write-Host "  No installer found. Run 'npm run tauri build' first." -ForegroundColor Red
    exit 1
}
Write-Host "  Installer: $($installer.FullName)" -ForegroundColor Green

# 3. Sign the installer with signtool
Write-Host "`n[3/3] Signing installer..." -ForegroundColor Yellow
$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"
if (-not (Test-Path $signtool)) {
    # Try to find signtool in the Windows SDK
    $signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $signtool) {
    Write-Host "  signtool not found. Install Windows SDK." -ForegroundColor Red
    exit 1
}

& $signtool sign /f $certPath /p $password /fd SHA256 /t http://timestamp.digicert.com $installer.FullName
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Installer signed successfully!" -ForegroundColor Green
} else {
    Write-Host "  Signing failed with exit code $LASTEXITCODE" -ForegroundColor Red
}

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "  Signed installer: $($installer.FullName)"
Write-Host "  Certificate: $certPath (keep this safe - needed for future builds)"
Write-Host ""
Write-Host "NOTE: Self-signed certs still show a SmartScreen warning."
Write-Host "To remove the warning entirely, buy a cert from a trusted CA (DigiCert, Sectigo)."