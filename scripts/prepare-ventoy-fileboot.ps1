# HATAN OS — تجهيز USB للإقلاع من ملفات (بدون ISO على الفلاش)

function Get-ArchIsoVolumeLabel {
    param([string]$IsoPath)
    $mount = $null
    try {
        $mount = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 2
        $vol = $mount | Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | Select-Object -First 1
        if ($vol -and $vol.FileSystemLabel) {
            return $vol.FileSystemLabel
        }
    } finally {
        if ($mount) {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
        }
    }
    return 'ARCH_000000'
}

function Copy-ArchIsoContents {
    param(
        [string]$IsoPath,
        [string]$LiveDir
    )

    if (Test-Path $LiveDir) { Remove-Item -Recurse -Force $LiveDir }
    New-Item -ItemType Directory -Force -Path $LiveDir | Out-Null

    $mounted = $false
    $driveLetter = $null
    try {
        $img = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 3
        $vol = $img | Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | Select-Object -First 1
        if (-not $vol -or -not $vol.DriveLetter) {
            throw 'Could not mount Arch ISO — no drive letter'
        }
        $mounted = $true
        $driveLetter = $vol.DriveLetter
        $srcRoot = "${driveLetter}:\"

        $archDir = Join-Path $srcRoot 'arch'
        if (-not (Test-Path $archDir)) {
            throw 'Invalid Arch ISO — arch\ folder not found'
        }

        Write-Step 'Copying arch live files to hatan-live\ (5-15 min)...'
        $null = robocopy $archDir $LiveDir /E /NFL /NDL /NJH /NJS /nc /ns /np
        if ($LASTEXITCODE -ge 8) { throw 'robocopy failed while extracting Arch ISO' }

        $vmlinuz = Join-Path $LiveDir 'boot\x86_64\vmlinuz-linux'
        $initrd = Join-Path $LiveDir 'boot\x86_64\initramfs-linux.img'
        $sfs = Join-Path $LiveDir 'x86_64\airootfs.sfs'
        foreach ($f in @($vmlinuz, $initrd, $sfs)) {
            if (-not (Test-Path -LiteralPath $f)) {
                throw "Missing after extract: $f"
            }
        }
        Write-Ok 'Arch live files extracted to hatan-live\'
    } finally {
        if ($mounted) {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Write-VentoyGrubCfg {
    param(
        [string]$UsbRoot,
        [string]$ArchIsoLabel
    )
    $template = Join-Path $ProjectRoot 'installer\ventoy\ventoy_grub.cfg.template'
    $ventoyDir = Join-Path $UsbRoot 'ventoy'
    New-Item -ItemType Directory -Force -Path $ventoyDir | Out-Null
    $dest = Join-Path $ventoyDir 'ventoy_grub.cfg'
    $text = Get-Content -LiteralPath $template -Raw -Encoding UTF8
    $text = $text -replace '__ARCHISO_LABEL__', $ArchIsoLabel
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok "ventoy\ventoy_grub.cfg (label=$ArchIsoLabel)"
}

function Test-WslReady {
    try {
        $null = & wsl.exe -e true 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Invoke-LiveSysrootInjection {
    param(
        [string]$UsbRoot
    )
    $liveDir = Join-Path $UsbRoot 'hatan-live'
    $sysroot = Join-Path $ProjectRoot 'installer\ventoy\live-sysroot'
    $injectSh = Join-Path $ProjectRoot 'scripts\inject-live-sysroot.sh'

    if (-not (Test-WslReady)) {
        Write-Warn 'WSL not available — auto-install injection skipped'
        Write-Warn 'After boot: login root (no password) then run: hatan-install-now'
        return $false
    }

    Write-Step 'Injecting auto-install into airootfs.sfs (WSL, 3-10 min)...'
    $wslLive = (& wsl.exe wslpath -a $liveDir).Trim()
    $wslSys = (& wsl.exe wslpath -a $sysroot).Trim()
    $wslSh = (& wsl.exe wslpath -a $injectSh).Trim()

    & wsl.exe -e bash -lc "command -v unsquashfs >/dev/null || sudo pacman -Sy --noconfirm squashfs-tools"
    & wsl.exe -e bash "$wslSh" "$wslLive" "$wslSys"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn 'Injection failed — use hatan-install-now after boot'
        return $false
    }
    Write-Ok 'Auto-install enabled (no ISO needed)'
    return $true
}

function Invoke-PrepareFileBootUsb {
    param(
        [string]$UsbRoot,
        [string]$IsoPath
    )

    $liveDir = Join-Path $UsbRoot 'hatan-live'
    $label = Get-ArchIsoVolumeLabel -IsoPath $IsoPath
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log "Arch ISO label: $label"
    }

    Copy-ArchIsoContents -IsoPath $IsoPath -LiveDir $liveDir
    Write-VentoyGrubCfg -UsbRoot $UsbRoot -ArchIsoLabel $label
    Invoke-LiveSysrootInjection -UsbRoot $UsbRoot | Out-Null

    $isoOnUsb = Join-Path $UsbRoot 'ISO'
    if (Test-Path $isoOnUsb) {
        Write-Step 'Removing ISO folder from USB (boot-from-file mode)'
        Remove-Item -Recurse -Force $isoOnUsb -ErrorAction SilentlyContinue
        Write-Ok 'USB has no ISO — boots from hatan-live\ files only'
    }
}

function Test-FileBootUsbReady {
    param([string]$UsbRoot)
    $errors = @()
    $vmlinuz = Join-Path $UsbRoot 'hatan-live\boot\x86_64\vmlinuz-linux'
    $initrd = Join-Path $UsbRoot 'hatan-live\boot\x86_64\initramfs-linux.img'
    $sfs = Join-Path $UsbRoot 'hatan-live\x86_64\airootfs.sfs'
    foreach ($f in @($vmlinuz, $initrd, $sfs)) {
        if (-not (Test-Path -LiteralPath $f)) {
            $errors += "Missing: $f"
        }
    }
    $grub = Join-Path $UsbRoot 'ventoy\ventoy_grub.cfg'
    if (-not (Test-Path -LiteralPath $grub)) {
        $errors += 'ventoy\ventoy_grub.cfg missing'
    }
    $hatan = Join-Path $UsbRoot 'hatan-os\installer\live-install.sh'
    if (-not (Test-Path -LiteralPath $hatan)) {
        $errors += 'hatan-os folder missing on USB'
    }
    if ($errors.Count -gt 0) {
        throw ("USB verification failed (file boot):`n- " + ($errors -join "`n- "))
    }
    Write-Ok 'USB verification passed (boot from file)'
}
