#!/bin/bash
# HATAN OS — تشغيل المثبّت الرسومي تلقائياً من ISO live

HAT_DIR="${HATAN_PROJECT_DIR:-/opt/hatan-os}"
PORT="${HATAN_INSTALL_PORT:-8766}"
URL="http://127.0.0.1:${PORT}"

export HATAN_ISO_LIVE=1
export HATAN_PROJECT_DIR="$HAT_DIR"
export DISPLAY="${DISPLAY:-:0}"

AUTO_INSTALL=0
grep -q 'hatan.autoinstall=1' /proc/cmdline 2>/dev/null && AUTO_INSTALL=1
export HATAN_AUTO_INSTALL="$AUTO_INSTALL"

log() { echo "[hatan-live] $*"; }

for i in $(seq 1 20); do
    nmcli -t -f STATE general 2>/dev/null | grep -qE 'connected|connecting' && break
    sleep 1
done

if command -v squeekboard &>/dev/null; then
    export GTK_IM_MODULE=squeekboard
    export QT_IM_MODULE=squeekboard
    export XMODIFIERS=@im=squeekboard
    eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
    squeekboard &
fi

fuser -k "${PORT}/tcp" 2>/dev/null || true
sleep 0.5

log "Starting installer server on $URL"
python3 "$HAT_DIR/installer/install-server.py" &
SERVER_PID=$!
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    log "GUI server failed — fallback: run hatan-install-now on tty1"
    echo ""
    echo "  HATAN OS: type: hatan-install-now"
    echo ""
    exec /sbin/agetty --noclear --autologin root tty1 linux
fi

[[ "$AUTO_INSTALL" == "1" ]] && URL="${URL}?autoinstall=1"

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
    --lang=ar
)

if command -v gamescope &>/dev/null; then
    exec gamescope -W 1280 -H 800 -f -r 60 -- "$BROWSER" "${CHROMIUM_FLAGS[@]}"
else
    exec "$BROWSER" "${CHROMIUM_FLAGS[@]}"
fi
