#!/bin/bash
# HATAN OS — تثبيت حزم Steam Deck / Valve مع معالجة تعارض Python
set -uo pipefail

PKG_FILE="${1:?package list file}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $1"; }

install_python_compat() {
    local p
    for p in python313 python312 python311 python; do
        if pacman -Si "$p" &>/dev/null 2>&1; then
            log "Python: $p"
            if pacman -S --noconfirm "$p"; then
                return 0
            fi
        fi
    done
    warn "تعذّر تثبيت Python — بعض حزم Jupiter قد تُتخطى"
    return 1
}

install_one() {
    local pkg="$1"
    if pacman -S --noconfirm "$pkg"; then
        return 0
    fi
    warn "فشل: $pkg"
    return 1
}

[[ -f "$PKG_FILE" ]] || { warn "ملف الحزم غير موجود: $PKG_FILE"; exit 1; }

install_python_compat || true

while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    [[ "$pkg" =~ ^python ]] && continue
    install_one "$pkg" || true
done < "$PKG_FILE"

log "انتهى تثبيت حزم Deck"
