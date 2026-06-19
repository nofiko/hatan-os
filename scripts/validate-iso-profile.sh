#!/bin/bash
# HATAN OS — فحص ملف تعريف ISO قبل البناء
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="$PROJECT_DIR/build/iso-profile"
LOG="${HATAN_VALIDATE_LOG:-$PROJECT_DIR/build/iso-validate.log}"

ERRORS=0
WARNS=0

log()  { echo "[OK]   $*" | tee -a "$LOG"; }
warn() { echo "[WARN] $*" | tee -a "$LOG"; WARNS=$((WARNS + 1)); }
fail() { echo "[FAIL] $*" | tee -a "$LOG"; ERRORS=$((ERRORS + 1)); }

require_file() {
    [[ -f "$1" ]] || fail "ملف ناقص: $1"
}

require_grep() {
    local file="$1" pattern="$2" msg="$3"
    grep -qE "$pattern" "$file" 2>/dev/null || fail "$msg ($file)"
}

: > "$LOG"
echo "HATAN OS ISO profile validation — $(date -Iseconds)" | tee -a "$LOG"
echo "Profile: $PROFILE" | tee -a "$LOG"
echo "" | tee -a "$LOG"

# ── ملفات إلزامية ────────────────────────────────────────
for f in profiledef.sh pacman.conf packages.x86_64 bootstrap_packages \
         grub/grub.cfg grub/loopback.cfg \
         airootfs/root/customize_airootfs.sh \
         airootfs/root/.bash_profile \
         airootfs/usr/local/bin/hatan-install-now; do
    require_file "$PROFILE/$f"
done
[[ $ERRORS -eq 0 ]] && log "جميع الملفات الإلزامية موجودة"

# ── profiledef.sh ──────────────────────────────────────
PD="$PROFILE/profiledef.sh"
grep -q 'iso_label="HATAN_OS"' "$PD" || fail "iso_label يجب أن يكون HATAN_OS"
grep -q 'install_dir="arch"' "$PD" || fail "install_dir يجب أن يكون arch"
grep -q 'arch="x86_64"' "$PD" || fail "arch يجب أن يكون x86_64"
grep -q 'uefi\.grub' "$PD" || fail "bootmodes يجب أن يتضمن uefi.grub"
grep -q 'bios' "$PD" && warn "يوجد وضع BIOS في profiledef"
log "profiledef: HATAN_OS / uefi.grub / x86_64"

# ── GRUB ───────────────────────────────────────────────
GRUB="$PROFILE/grub/grub.cfg"
require_grep "$GRUB" 'vmlinuz-linux-neptune' 'grub.cfg: نواة linux-neptune'
require_grep "$GRUB" 'initramfs-linux-neptune\.img' 'grub.cfg: initramfs neptune'
require_grep "$GRUB" 'archisosearchuuid=%ARCHISO_UUID%' 'grub.cfg: يجب archisosearchuuid=%ARCHISO_UUID%'
require_grep "$GRUB" 'rd\.systemd\.gpt_auto=no' 'grub.cfg: معامل Deck gpt_auto'
require_grep "$GRUB" 'amd_iommu=off' 'grub.cfg: معامل Deck amd_iommu'
log "grub.cfg صالح لـ Steam Deck UEFI"

# ── الحزم ──────────────────────────────────────────────
PKG="$PROFILE/packages.x86_64"
for pkg in base linux-neptune linux-firmware-neptune mkinitcpio mkinitcpio-archiso \
           grub efibootmgr arch-install-scripts squashfs-tools; do
    grep -qE "^${pkg}$" "$PKG" || fail "packages.x86_64: حزمة ناقصة: $pkg"
done
log "packages.x86_64 تحتوي نواة + initramfs + grub"

# ── pacman Valve ───────────────────────────────────────
PAC="$PROFILE/pacman.conf"
require_grep "$PAC" 'jupiter-main' 'pacman.conf: مستودع jupiter-main'
require_grep "$PAC" 'core-main' 'pacman.conf: مستودع core-main'
log "pacman.conf: مستودعات Valve"

# ── airootfs ───────────────────────────────────────────
require_grep "$PROFILE/airootfs/root/.bash_profile" 'hatan-live-installer' 'autostart المثبّت على tty1'
require_grep "$PROFILE/airootfs/usr/local/bin/hatan-install-now" 'iso-install' 'hatan-install-now يستدعي iso-install'

echo "" | tee -a "$LOG"
echo "────────────────────────────────────" | tee -a "$LOG"
if [[ $ERRORS -gt 0 ]]; then
    echo "FAILED: $ERRORS error(s), $WARNS warning(s)" | tee -a "$LOG"
    exit 1
fi
echo "PASSED: $WARNS warning(s)" | tee -a "$LOG"
exit 0
