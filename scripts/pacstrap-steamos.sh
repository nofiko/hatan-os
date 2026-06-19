#!/bin/bash
# HATAN OS — pacstrap بأساس SteamOS (مستودعات Valve *-main)
set -euo pipefail

MNT="${1:?mount point}"
PKG_FILE="${2:?package list}"
PROJECT_DIR="${3:-/opt/hatan-os}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SteamOS base]${NC} $1"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $1"; }
err()  { echo -e "${RED}[خطأ]${NC} $1"; exit 1; }

[[ -d "$MNT" ]] || err "نقطة mount غير موجودة: $MNT"
[[ -f "$PKG_FILE" ]] || err "قائمة الحزم غير موجودة: $PKG_FILE"

PACMAN_BOOT="${PROJECT_DIR}/base/pacman-bootstrap.conf"
[[ -f "$PACMAN_BOOT" ]] || PACMAN_BOOT="${PROJECT_DIR}/base/pacman.conf"
[[ -f "$PACMAN_BOOT" ]] || err "pacman-bootstrap.conf غير موجود في $PROJECT_DIR"

ensure_internet() {
    if ping -c1 -W3 steamdeck-packages.steamos.cloud >/dev/null 2>&1; then
        return 0
    fi
    if ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
        return 0
    fi
    err "لا يوجد إنترنت — اتصل بالواي فاي ثم أعد المحاولة"
}

prepare_chroot_network() {
    if [[ -f /etc/resolv.conf ]]; then
        mkdir -p "$MNT/etc"
        cp -f /etc/resolv.conf "$MNT/etc/resolv.conf"
    fi
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
        mkdir -p "$MNT/etc/pacman.d"
        cp -f /etc/pacman.d/mirrorlist "$MNT/etc/pacman.d/mirrorlist"
    fi
}

packages=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    packages+=("$line")
done < "$PKG_FILE"

[[ ${#packages[@]} -gt 0 ]] || err "قائمة pacstrap فارغة"

ensure_internet
prepare_chroot_network

mkdir -p "$MNT/etc/pacman.d"
cp -f "$PACMAN_BOOT" "$MNT/etc/pacman.conf"

log "مزامنة قواعد pacman (اختبار)..."
if ! pacman -Sy --config "$PACMAN_BOOT" --root "$MNT" 2>&1; then
    warn "فشلت مزامنة بعض المستودعات — متابعة pacstrap..."
fi

log "pacstrap SteamOS: ${#packages[@]} حزمة"
if ! pacstrap -C "$PACMAN_BOOT" "$MNT" "${packages[@]}" 2>&1; then
    err "فشل pacstrap (failed to install packages to new root) — تحقق من الإنترنت ومستودعات Valve"
fi

log "اكتمل pacstrap بنجاح"
