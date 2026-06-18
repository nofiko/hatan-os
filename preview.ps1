# HATAN OS - in-app preview window (no browser)
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$App = Join-Path $Root "preview-app.py"
$Port = 8765

Write-Host ""
Write-Host "  HATAN OS - In-app preview" -ForegroundColor Cyan
Write-Host ""

Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "Error: Install Python from python.org" -ForegroundColor Red
    Read-Host "Press Enter"
    exit 1
}

$env:HATAN_BOOT_PORT = "$Port"
& python $App
$code = $LASTEXITCODE
if ($code -and $code -ne 0) {
    Write-Host ""
    Write-Host "Preview failed (exit $code)" -ForegroundColor Red
    Read-Host "Press Enter"
    exit $code
}
