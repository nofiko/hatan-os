#!/bin/bash
# HATAN OS — شاشة الإقلاع (اختيار Windows / SteamOS) ثم الدخول للواجهة

set -euo pipefail

BOOT_DIR="/opt/hatan-os/ui/boot"
SHELL_DIR="/opt/hatan-os/ui/shell"
BOOT_PORT="${HATAN_BOOT_PORT:-8766}"
SHELL_PORT="${HATAN_SHELL_PORT:-8765}"
BOOT_PID=""
SHELL_PID=""

cleanup() {
    [[ -n "$BOOT_PID" ]] && kill "$BOOT_PID" 2>/dev/null || true
    [[ -n "$SHELL_PID" ]] && kill "$SHELL_PID" 2>/dev/null || true
}
trap cleanup EXIT

start_boot_server() {
    cd "$BOOT_DIR"
    export HATAN_BOOT_PORT="$BOOT_PORT"
    export HATAN_OS_PROGRESS="${HATAN_OS_PROGRESS:-/tmp/hatan-os-progress.json}"
    python3 "$BOOT_DIR/boot-server.py" &
    BOOT_PID=$!
    sleep 0.8
}

open_boot_ui() {
    local url="http://127.0.0.1:${BOOT_PORT}/index.html"
    local -a browser_cmd

    if command -v chromium &>/dev/null; then
        browser_cmd=(chromium --kiosk --app="$url"
            --disable-translate --no-first-run --disable-infobars
            --noerrdialogs --disable-features=TranslateUI)
    elif flatpak info com.brave.Browser &>/dev/null; then
        browser_cmd=(flatpak run com.brave.Browser --app="$url"
            --disable-translate --no-first-run)
    else
        browser_cmd=(google-chrome-stable --kiosk --app="$url")
    fi

    if command -v gamescope &>/dev/null; then
        gamescope -W 1280 -H 800 -f -r 60 -- "${browser_cmd[@]}"
    else
        "${browser_cmd[@]}"
    fi
}

start_shell() {
    exec "$SHELL_DIR/hat-shell.sh" start
}

main() {
    [[ -d "$BOOT_DIR" ]] || { start_shell; exit 0; }

    start_boot_server
    open_boot_ui
    start_shell
}

main "$@"
