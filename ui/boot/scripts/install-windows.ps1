# HATAN OS — تشغيل مثبت Windows من D:\
param(
    [Parameter(Mandatory = $true)][string]$Setup,
    [string]$Source = ""
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Setup)) {
    Write-Error "setup.exe not found: $Setup"
    exit 1
}

Write-Host "[HATAN] Windows source: $Source"
Write-Host "[HATAN] Launching installer (admin required)..."

$args = @()
if ($Source) {
    $args += "/InstallFrom", $Source
}

Start-Process -FilePath $Setup -ArgumentList $args -Verb RunAs
exit 0
