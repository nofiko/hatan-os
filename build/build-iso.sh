#!/bin/bash
# HATAN OS — بناء ISO قابل للإقلاع على Steam Deck (UEFI x86_64)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE_DIR="$SCRIPT_DIR/iso-profile"
OUTPUT_DIR="$SCRIPT_DIR/output"
WORK_DIR="$OUTPUT_DIR/work"
HATAN_IN_ISO="$PROFILE_DIR/airootfs/opt/hatan-os"
LOG_FILE="$SCRIPT_DIR/iso-build.log"
VALIDATE_LOG="$SCRIPT_DIR/iso-validate.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $1" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[خطأ]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
step() { echo -e "${CYAN}==>${NC} $1" | tee -a "$LOG_FILE"; }

: > "$LOG_FILE"
echo "HATAN OS ISO build — $(date -Iseconds)" >> "$LOG_FILE"

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║     HATAN OS — بناء ISO للتثبيت              ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  السجل: $LOG_FILE"
echo ""

[[ $EUID -eq 0 ]] || err "شغّل بصلاحيات root: sudo $0"

install_deps() {
    local pkgs=(archiso rsync systemd grub mtools dosfstools libisoburn squashfs-tools)
    local missing=()
    local p
    for p in "${pkgs[@]}"; do
        pacman -Qi "$p" &>/dev/null || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        step "تثبيت: ${missing[*]}"
        pacman -Sy --noconfirm "${missing[@]}"
    fi
}

install_deps

[[ -f "$PROFILE_DIR/profiledef.sh" ]] || err "profiledef.sh غير موجود"

RELENG="/usr/share/archiso/configs/releng"
if [[ -d "$RELENG" && ! -f "$PROFILE_DIR/bootstrap_packages" ]]; then
    step "نسخ bootstrap_packages من archiso releng"
    cp "$RELENG/bootstrap_packages" "$PROFILE_DIR/"
fi

step "فحص ملف تعريف ISO قبل البناء"
chmod +x "$PROJECT_DIR/scripts/validate-iso-profile.sh"
chmod +x "$PROJECT_DIR/scripts/verify-built-iso.sh"
if ! HATAN_VALIDATE_LOG="$VALIDATE_LOG" bash "$PROJECT_DIR/scripts/validate-iso-profile.sh"; then
    err "فشل فحص الملف الشخصي — راجع $VALIDATE_LOG"
fi
log "فحص الملف الشخصي: ناجح"

step "مزامنة الأصول"
bash "$PROJECT_DIR/scripts/sync-assets.sh" 2>>"$LOG_FILE" || true

step "نسخ ملفات HATAN OS إلى airootfs"
rm -rf "$HATAN_IN_ISO"
mkdir -p "$HATAN_IN_ISO"
rsync -a \
    --exclude='build/output' \
    --exclude='build/wsl-bootstrap' \
    --exclude='build/iso-build.log' \
    --exclude='build/iso-validate.log' \
    --exclude='build/iso-profile/airootfs/opt' \
    --exclude='.git' \
    --exclude='.vscode' \
    --exclude='agent-tools' \
    --exclude='*.iso' \
    "$PROJECT_DIR"/ "$HATAN_IN_ISO/"

chmod +x "$HATAN_IN_ISO/scripts/hatan-live-installer.sh" 2>/dev/null || true
chmod +x "$HATAN_IN_ISO/scripts/"*.sh 2>/dev/null || true
chmod +x "$HATAN_IN_ISO/installer/"*.sh 2>/dev/null || true
chmod +x "$HATAN_IN_ISO/installer/install-server.py" 2>/dev/null || true

mkdir -p "$OUTPUT_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

export PACMAN_OPTS="--noconfirm --needed"

run_mkarchiso() {
    step "تشغيل mkarchiso (15–45 دقيقة)..."
    cd "$PROFILE_DIR"
    if ! mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" . 2>&1 | tee -a "$LOG_FILE"; then
        return 1
    fi
    return 0
}

BUILD_OK=0
if run_mkarchiso; then
    BUILD_OK=1
else
    warn "فشل البناء — محاولة ثانية بعد تنظيف work/"
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    if run_mkarchiso; then
        BUILD_OK=1
    fi
fi

[[ "$BUILD_OK" -eq 1 ]] || err "فشل mkarchiso بعد محاولتين — راجع $LOG_FILE"

ISO_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'hatan-os-*.iso' -type f | sort | tail -1)
[[ -n "$ISO_FILE" ]] || ISO_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name '*.iso' -type f ! -name 'archlinux*.iso' | sort | tail -1)
[[ -n "$ISO_FILE" ]] || err "لم يُعثر على ISO في $OUTPUT_DIR"

step "التحقق من ISO الناتج"
if ! bash "$PROJECT_DIR/scripts/verify-built-iso.sh" "$ISO_FILE" 2>&1 | tee -a "$LOG_FILE"; then
    err "فشل التحقق من ISO — الملف غير قابل للإقلاع بشكل كامل"
fi

LATEST="$PROJECT_DIR/hatan-os-latest.iso"
cp -f "$ISO_FILE" "$LATEST"
log "نسخة جاهزة: $LATEST"

echo ""
log "✅ اكتمل البناء والتحقق!"
echo ""
echo "  الملف:  $ISO_FILE"
echo "  الرابط: $LATEST"
echo "  الحجم:  $(du -h "$ISO_FILE" | cut -f1)"
echo "  السجل:  $LOG_FILE"
echo ""
echo "  ┌─ الإقلاع على Steam Deck (UEFI) ─────────────┐"
echo "  │ 1. Etcher أو Rufus (DD image) → USB         │"
echo "  │ 2. Volume+ + Power → Boot Manager → USB     │"
echo "  │ 3. HATAN OS — Auto Install (Deck)           │"
echo "  │ 4. Ventoy: GRUB2 mode إن فشل Normal         │"
echo "  └─────────────────────────────────────────────┘"
echo ""
