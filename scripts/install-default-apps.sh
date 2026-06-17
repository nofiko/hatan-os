#!/bin/bash
# HATAN OS - تثبيت التطبيقات الافتراضية

set -euo pipefail

HAT_DIR="${HAT_DIR:-/opt/hatan-os}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $1"; }
step() { echo -e "${CYAN}==>${NC} $1"; }

FLATHUB="https://dl.flathub.org/repo/flathub.flatpakrepo"
STEAM_PKG="jupiter-main/steam-jupiter-stable"
XBOX_APP="io.github.unknownskl.greenlight"
EDGE_APP="com.microsoft.Edge"
BRAVE_APP="com.brave.Browser"

ensure_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        step "تثبيت Flatpak..."
        pacman -S --noconfirm flatpak || warn "تعذّر تثبيت flatpak"
    fi

    if ! flatpak remote-list --system 2>/dev/null | grep -q '^flathub'; then
        step "إضافة مستودع Flathub..."
        flatpak remote-add --if-not-exists --system flathub "$FLATHUB" || warn "تعذّر إضافة Flathub"
    fi
}

install_flatpak_app() {
    local app_id="$1"
    local label="$2"

    step "تثبيت $label..."
    if flatpak --system info "$app_id" &>/dev/null; then
        log "موجود مسبقاً: $label"
        return 0
    fi

    flatpak install -y --system flathub "$app_id" || {
        warn "فشل تثبيت $label"
        return 1
    }
}

install_pacman_app() {
    local pkg="$1"
    local label="$2"

    step "تثبيت $label..."
    pacman -S --noconfirm "$pkg" || warn "فشل تثبيت $label"
}

install_steam() {
    step "تثبيت Steam..."
    if pacman -Q steam-jupiter-stable &>/dev/null; then
        log "Steam جاهز"
        return 0
    fi
    pacman -S --noconfirm "$STEAM_PKG" || warn "فشل تثبيت Steam"
}

install_system_apps() {
    step "تثبيت تطبيقات النظام..."
    install_pacman_app dolphin "الملفات"
    install_pacman_app systemsettings "الإعدادات"
    install_pacman_app wine "ملفات EXE"
    install_pacman_app winetricks "ملفات EXE"
    install_pacman_app lutris "ملفات EXE"
}

configure_edge_for_deck() {
    step "إعداد Microsoft Store..."
    flatpak override --system --filesystem=/run/udev:ro "$EDGE_APP" 2>/dev/null || \
        flatpak override --user --filesystem=/run/udev:ro "$EDGE_APP" 2>/dev/null || \
        warn "تعذّر ضبط Microsoft Store"
}

set_brave_default() {
    step "تعيين Brave كمتصفح افتراضي..."
    if flatpak --system info "$BRAVE_APP" &>/dev/null; then
        xdg-settings set default-web-browser com.brave.Browser.desktop 2>/dev/null || \
            warn "تعذّر تعيين Brave كمتصفح افتراضي"
    fi
}

register_exe_handler() {
    step "تفعيل دعم ملفات exe..."
    local mime="/usr/share/applications/wine-extension-exe.desktop"
    if [[ -f "$mime" ]]; then
        xdg-mime default wine-extension-exe.desktop application/x-ms-dos-executable 2>/dev/null || true
    fi
}

install_desktop_entries() {
    local apps_dir="$HAT_DIR/config/applications"
    [[ -d "$apps_dir" ]] || return 0

    step "إعداد اختصارات التطبيقات..."
    mkdir -p /usr/share/applications
    cp "$apps_dir/"*.desktop /usr/share/applications/ 2>/dev/null || true
    update-desktop-database /usr/share/applications 2>/dev/null || true
}

echo ""
step "تثبيت التطبيقات الافتراضية..."

install_system_apps
install_steam
ensure_flatpak
install_flatpak_app "$XBOX_APP" "Xbox"
install_flatpak_app "$EDGE_APP" "Microsoft Store"
install_flatpak_app "$BRAVE_APP" "Brave"
configure_edge_for_deck
set_brave_default
register_exe_handler
install_desktop_entries

log "✅ التطبيقات جاهزة"
