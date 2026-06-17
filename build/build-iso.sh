#!/bin/bash
# HATAN OS — بناء صورة ISO للتثبيت على Steam Deck
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE_DIR="$SCRIPT_DIR/iso-profile"
OUTPUT_DIR="$SCRIPT_DIR/output"
HATAN_IN_ISO="$PROFILE_DIR/airootfs/opt/hatan-os"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1"; }
err()  { echo -e "${RED}[خطأ]${NC} $1"; exit 1; }
step() { echo -e "${CYAN}==>${NC} $1"; }

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     HATAN OS — بناء ISO للتثبيت              ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

[[ $EUID -eq 0 ]] || err "شغّل بصلاحيات root: sudo $0"

command -v mkarchiso &>/dev/null || {
    step "تثبيت archiso..."
    pacman -Sy --noconfirm archiso rsync
}

[[ -f "$PROFILE_DIR/profiledef.sh" ]] || err "ملف profiledef.sh غير موجود"

RELENG="/usr/share/archiso/configs/releng"
if [[ -d "$RELENG" ]]; then
    step "دمج ملفات الإقلاع من archiso releng"
    [[ -f "$PROFILE_DIR/bootstrap_packages" ]] || cp "$RELENG/bootstrap_packages" "$PROFILE_DIR/"
    for dir in grub syslinux; do
        if [[ ! -d "$PROFILE_DIR/$dir" && -d "$RELENG/$dir" ]]; then
            cp -a "$RELENG/$dir" "$PROFILE_DIR/"
        fi
    done
fi

step "مزامنة الأصول"
bash "$PROJECT_DIR/scripts/sync-assets.sh" 2>/dev/null || true

step "نسخ ملفات HATAN OS إلى ملف ISO"
rm -rf "$HATAN_IN_ISO"
mkdir -p "$HATAN_IN_ISO"
rsync -a \
    --exclude='build/output' \
    --exclude='build/iso-profile/airootfs/opt' \
    --exclude='.git' \
    --exclude='.vscode' \
    "$PROJECT_DIR"/ "$HATAN_IN_ISO/"

chmod +x "$HATAN_IN_ISO/scripts/hatan-live-installer.sh"
chmod +x "$HATAN_IN_ISO/installer/"*.sh
chmod +x "$HATAN_IN_ISO/installer/install-server.py"

mkdir -p "$OUTPUT_DIR/work"
step "بناء ISO (قد يستغرق 15–30 دقيقة)..."

cd "$PROFILE_DIR"
mkarchiso -v -w "$OUTPUT_DIR/work" -o "$OUTPUT_DIR" .

ISO_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'hatan-os-*.iso' -type f | sort | tail -1)
[[ -n "$ISO_FILE" ]] || ISO_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.iso' -type f | sort | tail -1)

echo ""
if [[ -n "$ISO_FILE" ]]; then
    log "✅ اكتمل البناء!"
    echo ""
    echo "  الملف: $ISO_FILE"
    echo "  الحجم: $(du -h "$ISO_FILE" | cut -f1)"
    echo ""
    echo "  على PC (Rufus):"
    echo "    • GPT · UEFI · FAT32 · ISO mode"
    echo ""
    echo "  على Steam Deck:"
    echo "    1. Volume+ + Power → Boot Manager → USB"
    echo "    2. تظهر واجهة تثبيت HATAN تلقائياً + لوحة لمس"
    echo "    3. التالي → ابدأ التثبيت → إعادة التشغيل"
    echo ""
else
    err "لم يُعثر على ملف ISO في $OUTPUT_DIR"
fi
