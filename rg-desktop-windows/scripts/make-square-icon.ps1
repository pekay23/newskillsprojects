# make-square-icon.ps1 - Creates a square app icon from a non-square source
# Usage: .\scripts\make-square-icon.ps1
#
# Pads a non-square image onto a transparent square canvas so Tauri can use it.

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot "..\src-tauri\icons\icon-mark.png"
$outputPath = Join-Path $PSScriptRoot "..\src-tauri\icons\icon-square.png"

Write-Host "Creating square icon from: $sourcePath" -ForegroundColor Yellow

$src = [System.Drawing.Image]::FromFile($sourcePath)
Write-Host "  Source: $($src.Width)x$($src.Height)"

$size = [Math]::Max($src.Width, $src.Height)
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$x = [int](($size - $src.Width) / 2)
$y = [int](($size - $src.Height) / 2)
$g.DrawImage($src, $x, $y, $src.Width, $src.Height)
$bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()
$src.Dispose()

Write-Host "  Square icon saved: $outputPath" -ForegroundColor Green