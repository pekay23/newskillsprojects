# Builds the Go sync agent into a standalone .exe
# that the desktop app (Tauri/Rust) spawns as a child process.
# Run from the repo root:  powershell -File rg-sync-agent/build.ps1

$ErrorActionPreference = "Stop"

# Ensure Go is on PATH
$goBin = "C:\Program Files\Go\bin"
if (-not (Test-Path (Join-Path $goBin "go.exe"))) {
    Write-Error "Go not found at $goBin. Install via: winget install GoLang.Go"
    exit 1
}
$env:Path = "$goBin;$env:Path"

# Build the sync agent
Push-Location (Join-Path $PSScriptRoot "..\rg-sync-agent")
try {
    Write-Host "Resolving Go dependencies..."
    go mod tidy

    Write-Host "Building rg-sync-agent.exe..."
    go build -o rg-sync-agent.exe ./cmd/syncagent

    if (Test-Path "rg-sync-agent.exe") {
        $size = (Get-Item "rg-sync-agent.exe").Length
        Write-Host "Built rg-sync-agent.exe ($([math]::Round($size/1MB, 1)) MB)"
        Write-Host "The desktop app will find it at: $((Resolve-Path 'rg-sync-agent.exe').Path)"
    } else {
        Write-Error "Build failed - rg-sync-agent.exe not produced"
        exit 1
    }
} finally {
    Pop-Location
}
