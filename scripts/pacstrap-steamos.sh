#!/bin/bash
# HATAN OS — pacstrap بأساس SteamOS (مستودعات Valve *-main)
set -euo pipefail

MNT="${1:?mount point}"
PKG_FILE="${2:?package list}"
PROJECT_DIR="${3:-/opt/hatan-os}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${GREEN}[SteamOS base]${NC} $1"; }
err()  { echo -e "${RED}[خطأ]${NC} $1"; exit 1; }

[[ -d "$MNT" ]] || err "نقطة mount غير موجودة: $MNT"
[[ -f "$PKG_FILE" ]] || err "قائمة الحزم غير موجودة: $PKG_FILE"
[[ -f "$PROJECT_DIR/base/pacman.conf" ]] || err "pacman.conf غير موجود في $PROJECT_DIR"

mkdir -p "$MNT/etc/pacman.d"
cp "$PROJECT_DIR/base/pacman.conf" "$MNT/etc/pacman.conf"

packages=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    packages+=("$line")
done < "$PKG_FILE"

[[ ${#packages[@]} -gt 0 ]] || err "قائمة pacstrap فارغة"

log "pacstrap SteamOS: ${#packages[@]} حزمة"
pacstrap -C "$PROJECT_DIR/base/pacman.conf" "$MNT" "${packages[@]}"
