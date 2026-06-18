#!/bin/bash
# HATAN OS — تشغيل المثبّت من ISO live (Steam Deck)
set -uo pipefail

HAT_DIR="${HATAN_PROJECT_DIR:-/opt/hatan-os}"
PORT="${HATAN_INSTALL_PORT:-8766}"
URL="http://127.0.0.1:${PORT}"

export HATAN_ISO_LIVE=1
export HATAN_PROJECT_DIR="$HAT_DIR"

log() { echo "[hatan-live] $*"; }

for i in $(seq 1 30); do
    nmcli -t -f STATE general 2>/dev/null | grep -qE 'connected|connecting' && break
    sleep 1
done

fuser -k "${PORT}/tcp" 2>/dev/null || true
sleep 0.5

log "Starting installer server on $URL"
python3 "$HAT_DIR/installer/install-server.py" &
SERVER_PID=$!
sleep 2

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    log "GUI server failed — starting terminal install"
    exec bash /usr/local/bin/hatan-install-now
fi

grep -q 'hatan.autoinstall=1' /proc/cmdline 2>/dev/null && URL="${URL}?autoinstall=1"

BROWSER="chromium"
command -v chromium &>/dev/null || BROWSER="firefox"

CHROMIUM_FLAGS=(
    --kiosk
    "--app=$URL"
    --ozone-platform=x11
    --disable-translate
    --no-first-run
    --disable-infobars
    --noerrdialogs
    --touch-events=enabled
    --lang=ar
)

log "Opening installer UI ($BROWSER x11)"
if ! exec "$BROWSER" "${CHROMIUM_FLAGS[@]}"; then
    log "Browser failed — terminal install"
    exec bash /usr/local/bin/hatan-install-now
fi
