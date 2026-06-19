#!/bin/bash
# HATAN OS — إعداد أساس SteamOS بعد تثبيت الحزم (داخل النظام المثبت)
set -uo pipefail

HAT_DIR="${HAT_DIR:-/opt/hatan-os}"
warn() { echo "[تحذير SteamOS] $*" >&2; }
log()  { echo "[SteamOS base] $*"; }

# ── holo-keyring + إعدادات Holo ─────────────────────────
for pkg in holo-keyring holo-wireplumber; do
    pacman -S --noconfirm "holo-main/$pkg" 2>/dev/null || \
        pacman -S --noconfirm "$pkg" 2>/dev/null || warn "تعذّر تثبيت $pkg"
done

# ── stub لـ steamos-update (مطلوب خارج SteamOS الرسمي) ──
if [[ ! -x /usr/bin/steamos-update ]] || grep -q 'HATAN OS stub' /usr/bin/steamos-update 2>/dev/null; then
    cat > /usr/bin/steamos-update << 'STUB'
#!/bin/bash
# HATAN OS stub — التحديثات عبر pacman + مستودعات Valve
echo "تحديثات SteamOS على HATAN OS: sudo pacman -Syu"
exit 0
STUB
    chmod 755 /usr/bin/steamos-update
fi

# ── هوية النظام ─────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
    if ! grep -q 'HATAN OS' /etc/os-release 2>/dev/null; then
        {
            echo 'NAME="HATAN OS"'
            echo 'PRETTY_NAME="HATAN OS (SteamOS Holo)"'
            echo 'ID=hatan-os'
            echo 'ID_LIKE=steamos arch'
            echo 'BUILD_ID=steamos-holo'
            grep -E '^(VERSION|VERSION_ID|ARCH)=' /etc/os-release 2>/dev/null || true
        } > /etc/os-release.hatan
        cat /etc/os-release.hatan > /etc/os-release
        rm -f /etc/os-release.hatan
    fi
fi

# ── mkinitcpio لنواة neptune ─────────────────────────────
if [[ "${HATAN_SKIP_MKINITCPIO:-0}" != "1" ]]; then
    if pacman -Q linux-neptune &>/dev/null; then
        mkinitcpio -p linux-neptune 2>/dev/null || mkinitcpio -P 2>/dev/null || warn "mkinitcpio"
    fi
fi

# ── خدمات Deck ──────────────────────────────────────────
systemctl enable jupiter-fan-control.service 2>/dev/null || true
systemctl enable steamdeck-dsp.service 2>/dev/null || true

log "اكتمل إعداد أساس SteamOS"
