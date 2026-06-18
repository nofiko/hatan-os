# HATAN OS — إقلاع مثبت / استعادة SteamOS من partsets
param(
    [Parameter(Mandatory = $true)][string]$Partsets,
    [string]$Efi = ""
)

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Path -LiteralPath (Join-Path $Partsets 'self'))) {
    Write-Error "Invalid partsets: $Partsets"
    exit 1
}

Write-Host "[HATAN] SteamOS partsets: $Partsets"

if (-not $Efi) {
    $root = Split-Path (Split-Path $Partsets -Parent) -Parent
    $Efi = Join-Path $root 'EFI\steamos\grubx64.efi'
}

if (-not (Test-Path -LiteralPath $Efi)) {
    Write-Error "EFI bootloader missing: $Efi"
    exit 1
}

if (-not (Test-Admin)) {
    Write-Host "[HATAN] Requesting administrator..."
    $argList = @('-Partsets', $Partsets)
    if ($Efi) { $argList += @('-Efi', $Efi) }
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    ) + $argList
    exit 0
}

$fw = bcdedit /enum firmware 2>&1 | Out-String
$guid = $null
$prev = ''
foreach ($line in ($fw -split "`n")) {
    if ($line -match '^\{[0-9a-fA-F-]+\}') { $prev = $matches[0] }
    if ($prev -and $line -match 'Steam|steamos') { $guid = $prev; break }
}

if (-not $guid) {
    Write-Host "[HATAN] Creating firmware boot entry for SteamOS..."
    $copy = bcdedit /copy '{00000000-0000-0000-0000-000000000000}' /d 'HATAN SteamOS' 2>&1 | Out-String
    if ($copy -match '(\{[0-9a-fA-F-]+\})') {
        $guid = $matches[1]
        bcdedit /set $guid device partition=$($Efi.Substring(0,2)) | Out-Null
        bcdedit /set $guid path '\EFI\steamos\grubx64.efi' | Out-Null
    }
}

if (-not $guid) {
    Write-Error 'Could not create SteamOS firmware boot entry'
    exit 1
}

bcdedit /set '{fwbootmgr}' bootsequence $guid /addfirst | Out-Null
Write-Host "[HATAN] Rebooting to SteamOS installer in 8 seconds..."
shutdown /r /t 8 /c 'HATAN OS — تثبيت SteamOS'
exit 0
