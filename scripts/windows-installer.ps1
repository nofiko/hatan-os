# HATAN OS - Windows USB installer (prepares USB + optional reboot)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$LogFile = Join-Path $env:TEMP 'hatan-installer.log'
function Write-Log([string]$Message) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

trap {
    Write-Err $_.Exception.Message
    Write-Log "FATAL: $($_.Exception.Message)"
    Wait-Exit
    exit 1
}

function Wait-Exit {
    Read-Host 'Press Enter to exit'
}

if (-not $PSScriptRoot) {
    Write-Err 'Script path error. Run install-hatan.bat from the project folder.'
    Wait-Exit
    exit 1
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:exitCode = 0
Write-Log "Started. Project=$ProjectRoot"
$ArchIsoName = 'archlinux-x86_64_VTGRUB2.iso'
$ArchIsoUrl  = 'https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso'
$ArchIsoMinBytes = 700MB
$ArchIsoMirrorUrls = @(
    'https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso'
    'https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso'
    'https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso'
)
$VentoyApi   = 'https://api.github.com/repos/ventoy/Ventoy/releases/latest'
$LiveInjUrl  = 'https://github.com/ventoy/LiveInjection/releases/download/1.0/live-injection-1.0.tar.gz'

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message){ Write-Host "[!] $Message" -ForegroundColor Yellow }
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

function Test-AdminElevation {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SteamDeckHost {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        return ($cs.Manufacturer -match 'Valve') -or ($cs.Model -match 'Steam Deck|Jupiter')
    } catch {
        return $false
    }
}

function Get-RemovableUsbDisks {
    $minBytes = 8 * 1GB
    $disks = @()
    try {
        $disks = @(Get-Disk -ErrorAction Stop)
    } catch {
        Write-Log "Get-Disk failed: $($_.Exception.Message)"
        throw 'Cannot list disks. Run as Administrator and ensure the Storage service is running.'
    }

    $result = @()
    foreach ($disk in $disks) {
        if ($disk.BusType -ne 'USB') { continue }
        if ($disk.Size -lt $minBytes) { continue }

        $letter = $null
        try {
            $letter = (Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter } |
                Sort-Object -Property Size -Descending |
                Select-Object -First 1).DriveLetter
        } catch {
            Write-Log "Get-Partition disk $($disk.Number): $($_.Exception.Message)"
        }

        if (-not $letter) { continue }

        $result += [PSCustomObject]@{
            DiskNumber = $disk.Number
            SizeGB     = [math]::Round($disk.Size / 1GB, 1)
            Letter     = $letter
            Friendly   = ('Disk {0} | {1} GB | {2}:' -f $disk.Number, [math]::Round($disk.Size / 1GB, 1), $letter)
        }
    }
    return $result
}

function Test-ValidArchIso {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $size = (Get-Item -LiteralPath $Path).Length
    Write-Log "ISO size check: $Path = $size bytes (min $ArchIsoMinBytes)"
    return $size -ge $ArchIsoMinBytes
}

function Invoke-PrepareArchIso {
    param([string]$IsoDir)

    $finalName = 'archlinux-x86_64_VTGRUB2.iso'
    $plainName = 'archlinux-x86_64.iso'
    $finalPath = Join-Path $IsoDir $finalName
    $plainPath = Join-Path $IsoDir $plainName

    foreach ($path in @($finalPath, $plainPath)) {
        if ((Test-Path -LiteralPath $path) -and -not (Test-ValidArchIso -Path $path)) {
            $mb = [math]::Round((Get-Item -LiteralPath $path).Length / 1MB, 1)
            Write-Warn "Removing bad ISO ($mb MB): $(Split-Path -Leaf $path)"
            Remove-Item -LiteralPath $path -Force
        }
    }

    if ((Test-Path -LiteralPath $plainPath) -and (Test-ValidArchIso -Path $plainPath)) {
        if (Test-Path -LiteralPath $finalPath) { Remove-Item -LiteralPath $finalPath -Force }
        Rename-Item -LiteralPath $plainPath -NewName $finalName
        Write-Ok 'Renamed archlinux-x86_64.iso -> archlinux-x86_64_VTGRUB2.iso (GRUB2 auto on Deck)'
        return $finalPath
    }

    if ((Test-Path -LiteralPath $finalPath) -and (Test-ValidArchIso -Path $finalPath)) {
        if (Test-Path -LiteralPath $plainPath) { Remove-Item -LiteralPath $plainPath -Force }
        $mb = [math]::Round((Get-Item -LiteralPath $finalPath).Length / 1MB, 0)
        Write-Ok "Arch ISO OK ($mb MB)"
        return $finalPath
    }

    Save-ArchIso -Destination $finalPath
    if (Test-Path -LiteralPath $plainPath) { Remove-Item -LiteralPath $plainPath -Force }
    return $finalPath
}

function Copy-UsbExtras {
    param([string]$UsbRoot)
    $usbInstaller = Join-Path $ProjectRoot 'installer\usb'
    $readme = Join-Path $usbInstaller 'ابدأ-هنا.txt'
    if (Test-Path $readme) {
        Copy-Item -Force $readme (Join-Path $UsbRoot 'ابدأ-هنا.txt')
    }
    foreach ($name in @(
            'hatan-install-from-files.sh',
            'تثبيت-HATAN-OS.desktop'
        )) {
        $src = Join-Path $usbInstaller $name
        if (Test-Path -LiteralPath $src) {
            Copy-Item -Force $src (Join-Path $UsbRoot $name)
        }
    }
    $launcher = Join-Path $UsbRoot 'hatan-install-from-files.sh'
    if (Test-Path -LiteralPath $launcher) {
        $content = [System.IO.File]::ReadAllText($launcher)
        $content = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($launcher, $content, (New-Object System.Text.UTF8Encoding($false)))
    }
    Write-Ok 'Deck Files launcher copied (تثبيت-HATAN-OS.desktop)'
}

function Test-UsbReady {
    param(
        [string]$UsbRoot,
        [string]$IsoPath
    )
    $errors = @()
    if (-not (Test-ValidArchIso -Path $IsoPath)) {
        $errors += 'Arch ISO missing or too small (need ~1.2 GB)'
    }
    $hatan = Join-Path $UsbRoot 'hatan-os\installer\live-install.sh'
    if (-not (Test-Path $hatan)) {
        $errors += 'hatan-os folder missing on USB'
    }
    $ventoyJson = Join-Path $UsbRoot 'ventoy\ventoy.json'
    if (-not (Test-Path $ventoyJson)) {
        $errors += 'ventoy\ventoy.json missing'
    }
    $injection = Join-Path $UsbRoot 'ventoy\live_injection.tar.gz'
    if (-not (Test-Path $injection)) {
        $errors += 'ventoy\live_injection.tar.gz missing (auto-install)'
    }
    if ($errors.Count -gt 0) {
        throw ("USB verification failed:`n- " + ($errors -join "`n- "))
    }
    Write-Ok 'USB verification passed (ISO mode)'
}

function Copy-VentoyConfig {
    param(
        [string]$UsbRoot,
        [ValidateSet('File', 'Iso')]
        [string]$Mode
    )
    $ventoyDir = Join-Path $UsbRoot 'ventoy'
    New-Item -ItemType Directory -Force -Path $ventoyDir | Out-Null
    $name = if ($Mode -eq 'Iso') { 'ventoy-iso.json' } else { 'ventoy.json' }
    $src = Join-Path $ProjectRoot "installer\ventoy\$name"
    Copy-Item -Force $src (Join-Path $ventoyDir 'ventoy.json')
    if (Get-Command Write-Ok -ErrorAction SilentlyContinue) {
        Write-Ok ("ventoy.json ($Mode mode)")
    }
}

function Save-ArchIso {
    param([string]$Destination)

    if (Test-ValidArchIso -Path $Destination) {
        $mb = [math]::Round((Get-Item -LiteralPath $Destination).Length / 1MB, 0)
        Write-Ok "Arch ISO valid ($mb MB) - skipping download"
        return
    }

    if (Test-Path $Destination) {
        $mb = [math]::Round((Get-Item -LiteralPath $Destination).Length / 1MB, 1)
        Write-Warn "Corrupt/incomplete ISO ($mb MB) - will re-download (~1.2 GB)"
        Remove-Item -LiteralPath $Destination -Force
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    $lastError = ''

    foreach ($url in $ArchIsoMirrorUrls) {
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            Write-Step "Downloading Arch ISO (~1.2 GB) - mirror $attempt..."
            Write-Host '  This may take 10-30 minutes depending on your connection.' -ForegroundColor Gray
            try {
                if ($curl) {
                    & curl.exe -L -f --retry 5 --retry-delay 3 --connect-timeout 30 `
                        -o $Destination $url
                    if ($LASTEXITCODE -ne 0) { throw "curl exit code $LASTEXITCODE" }
                } else {
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $url -OutFile $Destination -UseBasicParsing
                }

                if (Test-ValidArchIso -Path $Destination) {
                    $mb = [math]::Round((Get-Item -LiteralPath $Destination).Length / 1MB, 0)
                    Write-Ok "Arch ISO downloaded successfully ($mb MB)"
                    return
                }

                $got = if (Test-Path $Destination) { (Get-Item -LiteralPath $Destination).Length } else { 0 }
                $lastError = "Downloaded file too small ($got bytes) from $url"
                Write-Warn $lastError
                Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            } catch {
                $lastError = $_.Exception.Message
                Write-Warn "Download failed: $lastError"
                Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            }
        }
    }

    throw @"
Arch ISO download failed.

The file must be about 1.2 GB. Your file was only ~119 MB (incomplete).

Fix manually:
  1. Download from https://archlinux.org/download/
  2. Copy the file to USB\ISO\archlinux-x86_64.iso
  3. Boot from USB again

Last error: $lastError
"@
}

function Save-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination
    )
    Write-Step ('Downloading: {0}' -f (Split-Path -Leaf $Destination))
    if (Test-Path $Destination) {
        Write-Ok 'File already exists - skipping download'
        return
    }
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    Write-Ok 'Download complete'
}

function Expand-ArchiveFile {
    param([string]$Archive, [string]$Destination)
    if ($Archive -match '\.zip$') {
        Expand-Archive -Path $Archive -DestinationPath $Destination -Force
    } elseif ($Archive -match '\.tar\.gz$') {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        tar -xzf $Archive -C $Destination
    } else {
        throw "Unsupported archive: $Archive"
    }
}

function Invoke-VentoyInstall {
    param(
        [string]$VentoyExe,
        [string]$DriveLetter
    )
    Write-Step ('Installing Ventoy on drive {0}:' -f $DriveLetter)
    $cliArgs = @('/I', '/GPT', '/Y', ('/D={0}' -f $DriveLetter))
    $proc = Start-Process -FilePath $VentoyExe -ArgumentList $cliArgs -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        throw "Ventoy2Disk failed (exit $($proc.ExitCode))"
    }
    Start-Sleep -Seconds 4
    Write-Ok 'Ventoy installed'
}

function Copy-HatanPayload {
    param([string]$UsbRoot)
    $dest = Join-Path $UsbRoot 'hatan-os'
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $dirs = @('ui', 'themes', 'config', 'base', 'scripts', 'installer', 'build')
    foreach ($name in $dirs) {
        $srcDir = Join-Path $ProjectRoot $name
        if (-not (Test-Path $srcDir)) { continue }
        $null = robocopy $srcDir (Join-Path $dest $name) /E /XD .git /NFL /NDL /NJH /NJS /nc /ns /np
        if ($LASTEXITCODE -ge 8) { throw "Failed to copy $name" }
    }
    Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'installer')
    Normalize-ShellScriptsToLf -RootPath (Join-Path $dest 'scripts')
    Write-Ok 'HATAN files copied to USB'
}

function New-LiveInjectionArchive {
    param([string]$UsbRoot)

    Write-Step 'Building auto-install injection package'
    $work = Join-Path $env:TEMP "hatan-liveinj-$(Get-Random)"
    $liTar = Join-Path $env:TEMP 'live-injection-1.0.tar.gz'
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    Save-FileWithProgress -Url $LiveInjUrl -Destination $liTar
    Expand-ArchiveFile -Archive $liTar -Destination $work

    $liRoot = Get-ChildItem -Path $work -Directory | Select-Object -First 1
    if (-not $liRoot) {
        $liRoot = Get-Item $work
    }

    $sysroot = Join-Path $liRoot.FullName 'sysroot'
    if (Test-Path $sysroot) { Remove-Item -Recurse -Force $sysroot }
    Copy-Item -Recurse -Force (Join-Path $ProjectRoot 'installer\ventoy\live-sysroot') $sysroot

    $wants = Join-Path $sysroot 'etc\systemd\system\multi-user.target.wants'
    New-Item -ItemType Directory -Force -Path $wants | Out-Null
    $svc = Join-Path $sysroot 'etc\systemd\system\hatan-autoinstall.service'
    Copy-Item -Force $svc (Join-Path $wants 'hatan-autoinstall.service')

    $packBat = Join-Path $liRoot.FullName 'pack.bat'
    if (-not (Test-Path $packBat)) { throw 'pack.bat not found in LiveInjection package' }
    (Get-Content $packBat -Raw) -replace '\r?\npause\r?\n', "`n" | Set-Content $packBat -Encoding ASCII
    $null = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'pack.bat' -Wait -PassThru -NoNewWindow -WorkingDirectory $liRoot.FullName

    $archive = Join-Path $liRoot.FullName 'live_injection.tar.gz'
    if (-not (Test-Path $archive)) { throw 'Failed to create live_injection.tar.gz' }

    $ventoyDir = Join-Path $UsbRoot 'ventoy'
    New-Item -ItemType Directory -Force -Path $ventoyDir | Out-Null
    Copy-Item -Force $archive (Join-Path $ventoyDir 'live_injection.tar.gz')
    Copy-VentoyConfig -UsbRoot $UsbRoot -Mode Iso
    Write-Ok 'Auto-install package ready'
}

function Start-FirmwareReboot {
    param([int]$Seconds = 45)
    Write-Step "Rebooting in $Seconds seconds..."
    Write-Warn 'Select USB boot in the UEFI menu'
    shutdown.exe /r /fw /t $Seconds /c 'HATAN OS - reboot and boot from USB'
}

try {
    Clear-Host
    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor Cyan
    Write-Host '       HATAN OS - Windows Installer' -ForegroundColor Cyan
    Write-Host '  ==============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Prepares USB, then reboots for automatic install.'
    Write-Host '  WARNING: Internal Steam Deck disk will be erased when booting from USB.'
    Write-Host ''
    Write-Host '  Boot mode:'
    Write-Host '    [1] Boot from file — no ISO on USB (recommended)' -ForegroundColor Green
    Write-Host '    [2] Classic — Arch ISO file on USB (Ventoy ISO mode)'
    Write-Host ''
    $bootPick = Read-Host 'Mode (1 or 2, Enter=1)'
    if ($env:HATAN_BOOT_MODE -eq 'File') {
        $script:BootMode = 'File'
    } elseif ($env:HATAN_BOOT_MODE -eq 'Iso') {
        $script:BootMode = 'Iso'
    } elseif ($bootPick -eq '2') {
        $script:BootMode = 'Iso'
    } else {
        $script:BootMode = 'File'
    }
    Write-Host ''
    Write-Host "  Log: $LogFile"
    Write-Host ''

    . (Join-Path $PSScriptRoot 'prepare-ventoy-fileboot.ps1')

    if (-not (Test-AdminElevation)) {
        throw 'Run as Administrator (right-click install-hatan.bat -> Run as administrator)'
    }

    $isDeck = Get-SteamDeckHost
    if ($isDeck) {
        Write-Warn 'Steam Deck detected - device will reboot after USB is ready'
    } else {
        Write-Host '  PC mode: USB only (no auto reboot)' -ForegroundColor Gray
    }

    $usbList = @(Get-RemovableUsbDisks)
    Write-Log "USB drives found: $($usbList.Count)"
    if ($usbList.Count -eq 0) {
        throw @'
No USB drive found.

- Insert a USB flash drive (8 GB or larger)
- Make sure Windows shows it in File Explorer with a drive letter (e.g. E:)
- Unplug and replug the USB, then run this installer again
'@
    }

    Write-Host ''
    Write-Host '  Select USB (ALL data on it will be erased):' -ForegroundColor Yellow
    for ($i = 0; $i -lt $usbList.Count; $i++) {
        Write-Host ('    [{0}] {1}' -f ($i + 1), $usbList[$i].Friendly)
    }
    Write-Host ''
    $pick = Read-Host 'USB number'
    if ($pick -notmatch '^\d+$') {
        throw 'Invalid selection - enter a number from the list'
    }
    $idx = [int]$pick - 1
    if ($idx -lt 0 -or $idx -ge $usbList.Count) {
        throw 'Invalid selection - number out of range'
    }

    $target = $usbList[$idx]
    $letter = $target.Letter
    Write-Warn "USB ${letter}: will be completely erased!"
    $confirm = Read-Host 'Type YES to continue'
    if ($confirm -ne 'YES') {
        Write-Host 'Cancelled.'
        return
    }

    $temp = Join-Path $env:TEMP "hatan-setup-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $temp | Out-Null

    Write-Step 'Downloading Ventoy'
    $release = Invoke-RestMethod -Uri $VentoyApi -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -match 'windows\.zip$' } | Select-Object -First 1
    if (-not $asset) { throw 'Ventoy Windows zip not found' }
    $ventoyZip = Join-Path $temp 'ventoy.zip'
    Save-FileWithProgress -Url $asset.browser_download_url -Destination $ventoyZip
    $ventoyDir = Join-Path $temp 'ventoy'
    Expand-Archive -Path $ventoyZip -DestinationPath $ventoyDir -Force
    $ventoyExe = Get-ChildItem -Path $ventoyDir -Recurse -Filter 'Ventoy2Disk.exe' | Select-Object -First 1
    if (-not $ventoyExe) { throw 'Ventoy2Disk.exe not found' }

    Invoke-VentoyInstall -VentoyExe $ventoyExe.FullName -DriveLetter $letter

    $usbRoot = "${letter}:\"
    if (-not (Test-Path $usbRoot)) {
        Start-Sleep -Seconds 3
        $usbRoot = "${letter}:\"
    }
    if (-not (Test-Path $usbRoot)) { throw "USB drive ${letter}: not mounted" }

    $tempIso = Join-Path $temp 'archlinux-x86_64.iso'
    Save-ArchIso -Destination $tempIso

    if ($script:BootMode -eq 'File') {
        Invoke-PrepareFileBootUsb -UsbRoot $usbRoot -IsoPath $tempIso
        Copy-HatanPayload -UsbRoot $usbRoot
        Copy-VentoyConfig -UsbRoot $usbRoot -Mode File
        Copy-UsbExtras -UsbRoot $usbRoot
        Test-FileBootUsbReady -UsbRoot $usbRoot
        $bootHint = 'HATAN OS - Auto Install (Boot from file)'
        $isoPath = '(none — hatan-live\ on USB)'
    } else {
        $isoDir = Join-Path $usbRoot 'ISO'
        New-Item -ItemType Directory -Force -Path $isoDir | Out-Null
        $finalIso = Join-Path $isoDir 'archlinux-x86_64_VTGRUB2.iso'
        if (Test-Path -LiteralPath $finalIso) { Remove-Item -LiteralPath $finalIso -Force }
        Copy-Item -LiteralPath $tempIso -Destination $finalIso -Force
        if (-not (Test-ValidArchIso -Path $finalIso)) { throw 'Failed to copy Arch ISO to USB' }
        Write-Ok 'Arch ISO copied to USB\ISO\'
        $isoPath = $finalIso
        Copy-HatanPayload -UsbRoot $usbRoot
        New-LiveInjectionArchive -UsbRoot $usbRoot
        Copy-UsbExtras -UsbRoot $usbRoot
        Test-UsbReady -UsbRoot $usbRoot -IsoPath $isoPath
        $bootHint = 'HATAN OS - Auto Install (ISO)'
    }

    Write-Host ''
    Write-Host '  ==============================================' -ForegroundColor Green
    Write-Host '       USB is ready!' -ForegroundColor Green
    Write-Host '  ==============================================' -ForegroundColor Green
    Write-Host ''
    Write-Host "  Boot:     $bootHint"
    Write-Host '  HATAN:    hatan-os\'
    if ($script:BootMode -eq 'File') {
        Write-Host '  Live:     hatan-live\  (kernel + initrd, no ISO file)'
    } else {
        Write-Host "  Arch ISO: $isoPath"
    }
    Write-Host '  On Deck: Volume+ + Power -> Boot Manager -> USB'
    Write-Host '  Read: USB\ابدأ-هنا.txt'
    Write-Host ''
    Write-Host '  Login after install: deck / deck'
    Write-Host ''

    if ($isDeck) {
        $go = Read-Host 'Reboot now? (Y/n)'
        if ($go -eq '' -or $go -match '^[Yy]') {
            Start-FirmwareReboot -Seconds 45
            Write-Ok 'Rebooting - select USB in boot menu'
        } else {
            Write-Warn 'Reboot manually: Volume+ + Power -> Boot Manager -> USB'
        }
    } else {
        Write-Ok 'Eject USB, plug into Steam Deck, boot from USB'
        Write-Host '  On Deck: Volume+ + Power -> Boot Manager -> USB'
        explorer.exe $usbRoot
    }
} catch {
    Write-Err $_.Exception.Message
    Write-Log "ERROR: $($_.Exception.Message)"
    $script:exitCode = 1
} finally {
    Wait-Exit
}

if ($script:exitCode) { exit $script:exitCode }
