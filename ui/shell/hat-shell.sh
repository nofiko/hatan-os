#!/bin/bash
# HATAN OS Shell - مشغّل الواجهة على Steam Deck

SHELL_DIR="/opt/hatan-os/ui/shell"
PORT=8765

sync_assets() {
    local root="/opt/hatan-os"
    [[ -f "$root/scripts/sync-assets.sh" ]] && bash "$root/scripts/sync-assets.sh"
}

start_shell() {
    sync_assets
    cd "$SHELL_DIR"

    if command -v python3 &>/dev/null; then
        python3 "$SHELL_DIR/hat-server.py" &
    elif command -v python &>/dev/null; then
        python "$SHELL_DIR/hat-server.py" &
    else
        echo "خطأ: يحتاج python3"
        exit 1
    fi

    SERVER_PID=$!
    sleep 1

    local url="http://127.0.0.1:$PORT"
    local -a browser_cmd

    if flatpak info com.brave.Browser &>/dev/null; then
        browser_cmd=(flatpak run com.brave.Browser --app="$url"
            --disable-translate --no-first-run --disable-infobars
            --noerrdialogs --disable-features=TranslateUI)
    elif command -v chromium &>/dev/null; then
        browser_cmd=(chromium --kiosk --app="$url"
            --disable-translate --no-first-run --disable-infobars
            --disable-session-crashed-bubble --noerrdialogs --disable-features=TranslateUI)
    else
        browser_cmd=(google-chrome-stable --kiosk --app="$url")
    fi

    if command -v gamescope &>/dev/null; then
        gamescope -W 1280 -H 800 -f -r 60 -- "${browser_cmd[@]}"
    else
        "${browser_cmd[@]}"
    fi

    kill "$SERVER_PID" 2>/dev/null
}

launch_app() {
    case "$1" in
        steam)               steam & ;;
        steam-game)          steam -applaunch "$2" & ;;
        xbox)                flatpak run io.github.unknownskl.greenlight & ;;
        microsoft-store|msstore)
            flatpak run com.microsoft.Edge --new-window https://apps.microsoft.com/store/apps & ;;
        brave)               flatpak run com.brave.Browser & ;;
        files|dolphin)       dolphin ~/ & ;;
        settings)            ;; # يُفتح داخل واجهة HATAN Shell
        capture)             ;; # يُفتح داخل واجهة HATAN Shell
        exe|lutris)          lutris & ;;
        startplasma-wayland) startplasma-wayland & ;;
        chromium)            chromium & ;;
        flatpak)             flatpak & ;;
        dolphin)             dolphin & ;;
        *)                   eval "$1" & ;;
    esac
}

case "${1:-start}" in
    start)  start_shell ;;
    launch) launch_app "$2" ;;
    *)      echo "الاستخدام: hatan-shell [start|launch <cmd>]" ;;
esac
