# HATAN OS — إصلاح USB بدون مسح Ventoy (لمن جهّز USB مسبقاً)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'windows-installer.ps1') -ErrorAction SilentlyContinue

# Re-load only needed helpers if dot-sourcing runs main block — use standalone copy
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Err([string]$Message)  { Write-Host "[X] $Message" -ForegroundColor Red }

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

$ArchIsoMinBytes = 700MB

function Test-ValidArchIsoLocal {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    return (Get-Item -LiteralPath $Path).Length -ge $ArchIsoMinBytes
}

Write-Host ''
Write-Host '  HATAN OS - USB Fix (no Ventoy reinstall)' -ForegroundColor Cyan
Write-Host ''

$letter = Read-Host 'USB drive letter (e.g. E)'
$letter = $letter.Trim().TrimEnd(':').ToUpper()
$usbRoot = "${letter}:\"

if (-not (Test-Path $usbRoot)) {
    Write-Err "Drive ${letter}: not found"
    Read-Host 'Press Enter'
    exit 1
}

$isoDir = Join-Path $usbRoot 'ISO'
New-Item -ItemType Directory -Force -Path $isoDir | Out-Null

$plain = Join-Path $isoDir 'archlinux-x86_64.iso'
$final = Join-Path $isoDir 'archlinux-x86_64_VTGRUB2.iso'

foreach ($p in @($plain, $final)) {
    if ((Test-Path -LiteralPath $p) -and -not (Test-ValidArchIsoLocal $p)) {
        Remove-Item -LiteralPath $p -Force
        Write-Host "Removed corrupt: $(Split-Path -Leaf $p)"
    }
}

if ((Test-Path -LiteralPath $plain) -and (Test-ValidArchIsoLocal $plain)) {
    if (Test-Path -LiteralPath $final) { Remove-Item -LiteralPath $final -Force }
    Rename-Item -LiteralPath $plain -NewName 'archlinux-x86_64_VTGRUB2.iso'
    Write-Ok 'ISO renamed to archlinux-x86_64_VTGRUB2.iso'
} elseif (-not (Test-ValidArchIsoLocal $final)) {
    Write-Err 'No valid Arch ISO on USB. Put archlinux-x86_64.iso in ISO\ folder (~1.2 GB) and run again.'
    Read-Host 'Press Enter'
    exit 1
} else {
    Write-Ok 'ISO already correct'
}

Write-Step 'Updating hatan-os + ventoy config'
$dest = Join-Path $usbRoot 'hatan-os'
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$dirs = @('ui', 'themes', 'config', 'base', 'scripts', 'installer', 'build')
foreach ($name in $dirs) {
    $srcDir = Join-Path $ProjectRoot $name
    if (Test-Path $srcDir) {
        $null = robocopy $srcDir (Join-Path $dest $name) /E /NFL /NDL /NJH /NJS /nc /ns /np
    }
}
Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'installer')
Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'scripts')

$ventoyDir = Join-Path $usbRoot 'ventoy'
New-Item -ItemType Directory -Force -Path $ventoyDir | Out-Null
Copy-Item -Force (Join-Path $ProjectRoot 'installer\ventoy\ventoy.json') (Join-Path $ventoyDir 'ventoy.json')

$readme = Join-Path $ProjectRoot 'installer\usb\ابدأ-هنا.txt'
if (Test-Path $readme) { Copy-Item -Force $readme (Join-Path $usbRoot 'ابدأ-هنا.txt') }

Write-Ok 'USB fixed. Boot Deck from USB -> HATAN OS - Auto Install -> Enter'
explorer.exe $usbRoot
Read-Host 'Press Enter'
