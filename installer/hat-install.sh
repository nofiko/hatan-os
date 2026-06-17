#!/bin/bash
# HATAN OS — تشغيل المثبّت الرسومي

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PORT="${HATAN_INSTALL_PORT:-8766}"
URL="http://127.0.0.1:${PORT}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║   HATAN OS — المثبّت الرسومي        ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════╝${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}  ⚠ شغّل بصلاحيات root:${NC}"
    echo "     sudo $0"
    echo ""
    exit 1
fi

# مزامنة الأصول
bash "$PROJECT_DIR/scripts/sync-assets.sh" 2>/dev/null || true

# إيقاف خادم سابق
if command -v fuser &>/dev/null; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
elif command -v ss &>/dev/null; then
    pid=$(ss -tlnp "sport = :${PORT}" 2>/dev/null | grep -oP 'pid=\K[0-9]+' | head -1)
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
fi
sleep 0.5

echo -e "${GREEN}  →${NC} تشغيل الخادم على ${URL}"

python3 "$SCRIPT_DIR/install-server.py" &
SERVER_PID=$!
sleep 1

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo -e "${RED}  ✗ فشل تشغيل الخادم${NC}"
    exit 1
fi

BROWSER="chromium"
command -v chromium &>/dev/null || BROWSER="google-chrome-stable"
command -v "$BROWSER" &>/dev/null || BROWSER="firefox"

if command -v gamescope &>/dev/null; then
    gamescope -W 1280 -H 800 -f -r 60 -- \
        "$BROWSER" --kiosk --app="$URL" \
        --disable-translate --no-first-run \
        --disable-infobars --noerrdialogs &
else
    "$BROWSER" --kiosk --app="$URL" &
fi

BROWSER_PID=$!

echo -e "${GREEN}  ✓${NC} المثبّت يعمل — أغلق المتصفح لإيقاف الخادم"
echo ""

cleanup() {
    kill "$BROWSER_PID" 2>/dev/null || true
    kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait "$BROWSER_PID" 2>/dev/null || wait "$SERVER_PID"
