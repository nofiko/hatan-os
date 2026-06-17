#!/bin/bash
# HATAN OS — تشغيل المثبّت الرسومي تلقائياً من ISO live

set -euo pipefail

HAT_DIR="${HATAN_PROJECT_DIR:-/opt/hatan-os}"
PORT="${HATAN_INSTALL_PORT:-8766}"
URL="http://127.0.0.1:${PORT}"

export HATAN_ISO_LIVE=1
export HATAN_PROJECT_DIR="$HAT_DIR"
export DISPLAY="${DISPLAY:-:0}"

log() { echo "[hatan-live] $*"; }

# انتظر الشبكة (WiFi)
for i in $(seq 1 30); do
    if nmcli -t -f STATE general 2>/dev/null | grep -qE 'connected|connecting'; then
        break
    fi
    sleep 1
done

# لوحة لمسية — squeekboard (Wayland، من مستودعات Arch)
if command -v squeekboard &>/dev/null; then
    export GTK_IM_MODULE=squeekboard
    export QT_IM_MODULE=squeekboard
    export XMODIFIERS=@im=squeekboard
    eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
    squeekboard &
fi

# إيقاف خادم سابق
fuser -k "${PORT}/tcp" 2>/dev/null || true
sleep 0.5

log "Starting installer server on $URL"
python3 "$HAT_DIR/installer/install-server.py" &
SERVER_PID=$!
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    log "ERROR: install server failed"
    exit 1
fi

BROWSER="chromium"
command -v chromium &>/dev/null || BROWSER="firefox"

CHROMIUM_FLAGS=(
    --kiosk
    "--app=$URL"
    --ozone-platform=wayland
    --enable-wayland-ime
    --disable-translate
    --no-first-run
    --disable-infobars
    --noerrdialogs
    --touch-events=enabled
    --enable-features=TouchpadAndWheelScrollLatching
    --lang=ar
)

if command -v gamescope &>/dev/null; then
    exec gamescope -W 1280 -H 800 -f -r 60 -- \
        "$BROWSER" "${CHROMIUM_FLAGS[@]}"
else
    exec "$BROWSER" "${CHROMIUM_FLAGS[@]}"
fi
