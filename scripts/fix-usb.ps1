# HATAN OS — إصلاح USB بدون مسح Ventoy

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Err([string]$Message)  { Write-Host "[X] $Message" -ForegroundColor Red }
function Write-Warn([string]$Message) { Write-Host "[!] $Message" -ForegroundColor Yellow }

function Convert-ToLf {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

function Normalize-ShellScriptsToLf {
    param([string]$RootPath)
    if (-not (Test-Path -LiteralPath $RootPath)) { return }
    Get-ChildItem -Path $RootPath -Recurse -File -Include *.sh | ForEach-Object {
        Convert-ToLf -Path $_.FullName
    }
}

function Copy-HatanPayloadFix {
    param([string]$UsbRoot)
    $dest = Join-Path $UsbRoot 'hatan-os'
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($name in @('ui', 'themes', 'config', 'base', 'scripts', 'installer', 'build')) {
        $srcDir = Join-Path $ProjectRoot $name
        if (Test-Path $srcDir) {
            $null = robocopy $srcDir (Join-Path $dest $name) /E /NFL /NDL /NJH /NJS /nc /ns /np
        }
    }
    Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'installer')
    Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'scripts')
    Write-Ok 'hatan-os updated'
}

Write-Host ''
Write-Host '  HATAN OS - USB Fix (no Ventoy reinstall)' -ForegroundColor Cyan
Write-Host ''
Write-Host '  [1] Boot from file (hatan-live\, no ISO) — recommended'
Write-Host '  [2] Classic ISO mode'
Write-Host ''
$modePick = Read-Host 'Mode (Enter=1)'
$useFile = ($modePick -ne '2')

$letter = Read-Host 'USB drive letter (e.g. E)'
$letter = $letter.Trim().TrimEnd(':').ToUpper()
$usbRoot = "${letter}:\"

if (-not (Test-Path $usbRoot)) {
    Write-Err "Drive ${letter}: not found"
    Read-Host 'Press Enter'
    exit 1
}

. (Join-Path $PSScriptRoot 'prepare-ventoy-fileboot.ps1')

if ($useFile) {
    $tempIso = Join-Path $env:TEMP 'hatan-arch-fix.iso'
    Write-Step 'Need Arch ISO once (~1.2 GB) to refresh hatan-live\'
    Write-Host '  Download from https://archlinux.org/download/ or use existing file path'
    $isoInput = Read-Host 'Path to archlinux-x86_64.iso (or Enter to skip rebuild)'
    if ($isoInput -and (Test-Path -LiteralPath $isoInput)) {
        Invoke-PrepareFileBootUsb -UsbRoot $usbRoot -IsoPath $isoInput
    } else {
        Write-Warn 'Skipped hatan-live rebuild — updating config only'
    }
    Copy-Item -Force (Join-Path $ProjectRoot 'installer\ventoy\ventoy.json') (Join-Path $usbRoot 'ventoy\ventoy.json')
} else {
    Copy-Item -Force (Join-Path $ProjectRoot 'installer\ventoy\ventoy-iso.json') (Join-Path $usbRoot 'ventoy\ventoy.json')
    Write-Ok 'ventoy.json (ISO mode)'
}

Copy-HatanPayloadFix -UsbRoot $usbRoot
$usbInstaller = Join-Path $ProjectRoot 'installer\usb'
foreach ($name in @('hatan-install-from-files.sh', 'تثبيت-HATAN-OS.desktop', 'ابدأ-هنا.txt')) {
    $src = Join-Path $usbInstaller $name
    if (Test-Path -LiteralPath $src) { Copy-Item -Force $src (Join-Path $usbRoot $name) }
}

Write-Ok 'USB fixed'
explorer.exe $usbRoot
Read-Host 'Press Enter'
