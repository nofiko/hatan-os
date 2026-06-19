#!/bin/bash
# HATAN OS — التحقق من ISO بعد البناء (UEFI + kernel + squashfs)
# ملاحظة: archiso uefi.grub يضع BOOTX64.EFI داخل partition ESP المضمّن (hybrid)
# وليس دائماً كملف ISO9660 مرئي عبر xorriso -find
set -uo pipefail

ISO="${1:?usage: verify-built-iso.sh path/to/image.iso}"
INSTALL_DIR="${HATAN_INSTALL_DIR:-arch}"
MIN_BYTES=$((500 * 1024 * 1024))

ERRORS=0
WARNS=0
log()  { echo "[OK]   $*"; }
warn() { echo "[WARN] $*"; WARNS=$((WARNS + 1)); }
fail() { echo "[FAIL] $*"; ERRORS=$((ERRORS + 1)); }

[[ -f "$ISO" ]] || { echo "ISO not found: $ISO"; exit 1; }

SIZE=$(stat -c%s "$ISO" 2>/dev/null || stat -f%z "$ISO")
[[ "$SIZE" -ge "$MIN_BYTES" ]] || fail "ISO صغير جداً ($SIZE bytes) — بناء ناقص"

list_iso() {
    if command -v xorriso &>/dev/null; then
        xorriso -indev "$ISO" -find / -type f 2>/dev/null | sed 's|^/||'
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
    if echo "$FILES" | grep -qiE "$pattern"; then
        log "$desc"
        return 0
    fi
    fail "ناقص: $desc ($pattern)"
    return 1
}

# ── محتوى live (إلزامي) ─────────────────────────────────
check_path "${INSTALL_DIR}/boot/x86_64/vmlinuz-linux-neptune" 'vmlinuz-linux-neptune'
check_path "${INSTALL_DIR}/boot/x86_64/initramfs-linux-neptune\.img" 'initramfs-linux-neptune.img'
check_path "${INSTALL_DIR}/x86_64/airootfs\.sfs" 'airootfs.sfs (squashfs live)'
check_path 'boot/grub/grub\.cfg|grub/grub\.cfg' 'grub.cfg داخل ISO'

# ── UEFI boot (أحد الشروط يكفي) ─────────────────────────
UEFI_OK=0

if echo "$FILES" | grep -qiE 'EFI/BOOT/BOOTX64\.EFI'; then
    log "BOOTX64.EFI على ISO9660"
    UEFI_OK=1
fi

if echo "$FILES" | grep -qiE 'EFI/BOOT/grubx64\.efi|boot/grub/x86_64-efi/core\.efi'; then
    log "GRUB EFI binary على ISO9660"
    UEFI_OK=1
fi

if command -v xorriso &>/dev/null; then
    if xorriso -indev "$ISO" -report_el_torito as_mkisofs 2>/dev/null | grep -qi 'efi'; then
        log "El Torito UEFI boot entry"
        UEFI_OK=1
    fi
fi

if command -v fdisk &>/dev/null; then
    FDISK_OUT=$(fdisk -l "$ISO" 2>/dev/null || true)
    if echo "$FDISK_OUT" | grep -qiE 'EFI System|EFI boot'; then
        log "GPT/EFI hybrid partition (ESP مضمّن — BOOTX64.EFI هنا)"
        UEFI_OK=1
    fi
fi

if [[ "$UEFI_OK" -eq 0 ]]; then
    fail "لم يُثبت دعم UEFI (لا BOOTX64 ولا El Torito ولا ESP hybrid)"
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo "ISO verification FAILED ($ERRORS errors, $WARNS warnings)"
    exit 1
fi
echo "ISO verification PASSED ($WARNS warnings) — جاهز لـ Steam Deck UEFI"
exit 0
