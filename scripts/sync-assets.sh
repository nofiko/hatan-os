#!/bin/bash
# HATAN OS - مزامنة الأصول
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$ROOT/ui/shell/assets/audio" "$ROOT/ui/installer/assets" "$ROOT/ui/installer/css"

LOGO_SRC=""
for candidate in \
    "$ROOT/themes/icons/logo.png" \
    "$ROOT/themes/icons/logo.svg" \
    "$ROOT/themes/splash/HATAN OS.png" \
    "$ROOT/themes/splash/boot.png"; do
    if [[ -f "$candidate" ]]; then
        LOGO_SRC="$candidate"
        break
    fi
done

if [[ -n "$LOGO_SRC" ]]; then
    cp "$LOGO_SRC" "$ROOT/themes/splash/boot.png"
    cp "$LOGO_SRC" "$ROOT/ui/shell/assets/boot.png"
    cp "$LOGO_SRC" "$ROOT/ui/installer/assets/boot.png"
    cp "$LOGO_SRC" "$ROOT/themes/plymouth/boot.png"
    echo "  + شعار: $(basename "$LOGO_SRC")"
else
    echo "  ! لم يُعثر على شعار في themes/icons أو themes/splash"
fi

cp "$ROOT/themes/custom/theme.css" "$ROOT/ui/shell/css/theme.css" 2>/dev/null || true
cp "$ROOT/themes/custom/theme.css" "$ROOT/ui/installer/css/theme.css" 2>/dev/null || true

for f in startup-sound.mp3 welcom.mp3 select.mp3 DIS.mp3; do
    [[ -f "$ROOT/themes/audio/$f" ]] && cp "$ROOT/themes/audio/$f" "$ROOT/ui/shell/assets/audio/$f"
done

[[ -f "$ROOT/themes/audio/press music.mp3" ]] && \
    cp "$ROOT/themes/audio/press music.mp3" "$ROOT/ui/shell/assets/audio/press-music.mp3"

echo "[HATAN OS] تمت مزامنة الأصول"
