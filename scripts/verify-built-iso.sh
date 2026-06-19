#!/bin/bash
# HATAN OS — التحقق من ISO بعد البناء (UEFI + kernel + squashfs)
set -uo pipefail

ISO="${1:?usage: verify-built-iso.sh path/to/image.iso}"
INSTALL_DIR="${HATAN_INSTALL_DIR:-arch}"
MIN_BYTES=$((500 * 1024 * 1024))

ERRORS=0
log()  { echo "[OK]   $*"; }
fail() { echo "[FAIL] $*"; ERRORS=$((ERRORS + 1)); }

[[ -f "$ISO" ]] || { echo "ISO not found: $ISO"; exit 1; }

SIZE=$(stat -c%s "$ISO" 2>/dev/null || stat -f%z "$ISO")
[[ "$SIZE" -ge "$MIN_BYTES" ]] || fail "ISO صغير جداً ($SIZE bytes) — بناء ناقص"

list_iso() {
    if command -v xorriso &>/dev/null; then
        xorriso -indev "$ISO" -find / -type f 2>/dev/null
    elif command -v bsdtar &>/dev/null; then
        bsdtar -tf "$ISO" 2>/dev/null
    else
        fail "ثبّت xorriso أو bsdtar للتحقق من ISO"
        return 1
    fi
}

echo "Verifying: $ISO ($(numfmt --to=iec "$SIZE" 2>/dev/null || echo "${SIZE}B"))"
FILES=$(list_iso) || exit 1

check_path() {
    local pattern="$1" desc="$2"
    if echo "$FILES" | grep -qE "$pattern"; then
        log "$desc"
    else
        fail "ناقص: $desc ($pattern)"
    fi
}

# UEFI
check_path 'EFI/BOOT/BOOTX64\.EFI' 'BOOTX64.EFI (UEFI fallback)'
check_path 'EFI/BOOT/grubx64\.efi|boot/grub.*\.efi' 'GRUB EFI binary'

# Kernel + initramfs
check_path "${INSTALL_DIR}/boot/x86_64/vmlinuz-linux-neptune" 'vmlinuz-linux-neptune'
check_path "${INSTALL_DIR}/boot/x86_64/initramfs-linux-neptune\.img" 'initramfs-linux-neptune.img'

# Live rootfs
check_path "${INSTALL_DIR}/x86_64/airootfs\.sfs" 'airootfs.sfs (squashfs live)'

# GRUB config inside ISO
check_path 'boot/grub/grub\.cfg|grub/grub\.cfg' 'grub.cfg داخل ISO'

# Hybrid MBR/GPT hint
if command -v fdisk &>/dev/null; then
    if fdisk -l "$ISO" 2>/dev/null | grep -qi 'EFI'; then
        log "GPT/EFI partition table في ISO (hybrid)"
    else
        echo "[WARN] لم يُكتشف GPT EFI في ISO — قد يعمل عبر El Torito فقط"
    fi
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "ISO verification FAILED ($ERRORS errors)"
    exit 1
fi
echo "ISO verification PASSED — جاهز لـ Steam Deck UEFI"
exit 0
