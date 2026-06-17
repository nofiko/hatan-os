# HATAN OS - تشغيل معاينة الواجهة على Windows
$ErrorActionPreference = "Stop"
$Port = 8765
$Root = $PSScriptRoot
$ShellDir = Join-Path $Root "ui\shell"

Write-Host ""
Write-Host "  HATAN OS - جاري تشغيل المعاينة..." -ForegroundColor Cyan
Write-Host "  http://localhost:$Port" -ForegroundColor Yellow
Write-Host ""

# إيقاف أي خادم سابق على نفس المنفذ
Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "خطأ: Python غير مثبت. ثبّته من python.org" -ForegroundColor Red
    Read-Host "اضغط Enter للخروج"
    exit 1
}

$env:HATAN_DIR = $Root
$server = Start-Process python -ArgumentList "$ShellDir\hat-server.py" `
    -WorkingDirectory $ShellDir -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 1
Start-Process "http://localhost:$Port"

Write-Host "  المعاينة تعمل. أغلق هذه النافذة لإيقاف الخادم." -ForegroundColor Green
Write-Host ""
Write-Host "  التحكم:" -ForegroundColor White
Write-Host "    Enter  = تشغيل Steam"
Write-Host "    زر A   = تشغيل Steam"
Write-Host ""

try {
    Wait-Process -Id $server.Id
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
