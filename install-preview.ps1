# HATAN OS - Installer preview on Windows (demo mode)
$ErrorActionPreference = "Stop"
$Port = 8767
$Root = $PSScriptRoot
$ServerScript = Join-Path $Root "installer\install-server.py"

Write-Host ""
Write-Host "  HATAN OS - Installer preview..." -ForegroundColor Cyan
Write-Host "  http://localhost:$Port" -ForegroundColor Yellow
Write-Host "  Demo only - real install runs on Steam Deck with sudo" -ForegroundColor DarkGray
Write-Host ""

Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "Error: Python is not installed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$env:HATAN_INSTALL_PORT = "$Port"
$server = Start-Process python -ArgumentList $ServerScript `
    -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 1
Start-Process "http://localhost:$Port"

Write-Host "  Preview running. Close this window to stop the server." -ForegroundColor Green
Write-Host ""

try {
    Wait-Process -Id $server.Id
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
