# HATAN OS - مزامنة الأصول
$Root = Split-Path -Parent $PSScriptRoot

New-Item -ItemType Directory -Force -Path "$Root\ui\shell\assets\audio", "$Root\ui\installer\assets", "$Root\ui\installer\css" | Out-Null

# الشعار: الأولوية لـ themes/icons ثم splash
$LogoSources = @(
    "$Root\themes\icons\logo.png",
    "$Root\themes\icons\logo.svg",
    "$Root\themes\splash\HATAN OS.png",
    "$Root\themes\splash\boot.png"
)
$LogoSrc = $LogoSources | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($LogoSrc) {
    Copy-Item $LogoSrc "$Root\themes\splash\boot.png" -Force
    Copy-Item $LogoSrc "$Root\ui\shell\assets\boot.png" -Force
    Copy-Item $LogoSrc "$Root\ui\installer\assets\boot.png" -Force
    Copy-Item $LogoSrc "$Root\themes\plymouth\boot.png" -Force
    Write-Host "  + شعار: $(Split-Path $LogoSrc -Leaf)" -ForegroundColor Cyan
} else {
    Write-Host "  ! لم يُعثر على شعار في themes/icons أو themes/splash" -ForegroundColor Yellow
}

Copy-Item "$Root\themes\custom\theme.css" "$Root\ui\shell\css\theme.css" -Force -ErrorAction SilentlyContinue
Copy-Item "$Root\themes\custom\theme.css" "$Root\ui\installer\css\theme.css" -Force -ErrorAction SilentlyContinue
Copy-Item "$Root\themes\custom\theme.css" "$Root\ui\installer\css\theme.css" -Force -ErrorAction SilentlyContinue

if ($LogoSrc) {
    Copy-Item $LogoSrc "$Root\ui\installer\assets\boot.png" -Force
}

foreach ($file in @('startup-sound.mp3', 'welcom.mp3', 'select.mp3', 'DIS.mp3')) {
    $src = "$Root\themes\audio\$file"
    $dst = "$Root\ui\shell\assets\audio\$file"
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "  + $file" -ForegroundColor Cyan
    }
}

$PressSrc = "$Root\themes\audio\press music.mp3"
if (Test-Path $PressSrc) {
    Copy-Item $PressSrc "$Root\ui\shell\assets\audio\press-music.mp3" -Force
    Write-Host "  + press-music.mp3" -ForegroundColor Cyan
}

Write-Host "[HATAN OS] تمت مزامنة الأصول" -ForegroundColor Green
