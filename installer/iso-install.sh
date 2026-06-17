#!/bin/bash
# HATAN OS — تثبيت كامل من ISO (تقسيم + Arch + HATAN)
# يُشغَّل من بيئة Arch live عند HATAN_ISO_LIVE=1

set -euo pipefail

DISK="${HATAN_TARGET_DISK:-/dev/nvme0n1}"
MNT="/mnt"
PROJECT_DIR="${HATAN_PROJECT_DIR:-/opt/hatan-os}"
PROGRESS_FILE="${HATAN_PROGRESS_FILE:-/tmp/hatan-install-progress.json}"
HATAN_USERNAME="${HATAN_USERNAME:-deck}"
HATAN_INSTALL_RECOMMENDED="${HATAN_INSTALL_RECOMMENDED:-1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1"; }
err()  { echo -e "${RED}[خطأ]${NC} $1"; exit 1; }
step() { echo -e "${CYAN}==>${NC} $1"; }

report_progress() {
    local name="$1"
    local pct="$2"
    local status="${3:-running}"
    local done="${4:-false}"
    printf '{"step":"%s","percent":%s,"status":"%s","done":%s}\n' \
        "$name" "$pct" "$status" "$done" > "$PROGRESS_FILE"
    step "$name"
}

[[ $EUID -eq 0 ]] || err "يتطلب صلاحيات root"

if [[ ! -b "$DISK" ]]; then
    err "القرص غير موجود: $DISK — وصّل Steam Deck أو حدّد HATAN_TARGET_DISK"
fi

if [[ ! -d "$PROJECT_DIR/installer" ]]; then
    err "ملفات HATAN غير موجودة في $PROJECT_DIR"
fi

# ── 1. تقسيم القرص ─────────────────────────────────────
report_progress "تقسيم القرص" 5
wipefs -af "$DISK" 2>/dev/null || true
if command -v sgdisk &>/dev/null; then
    sgdisk -Z "$DISK"
    sgdisk -n "1:0:+512M" -t "1:ef00" -c "1:EFI" \
           -n "2:0:0"     -t "2:8300" -c "2:HATAN-OS" "$DISK"
else
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart EFI fat32 1MiB 513MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart root ext4 513MiB 100%
fi
partprobe "$DISK" 2>/dev/null || true
sleep 2

if [[ "$DISK" == *"nvme"* ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

[[ -b "$EFI_PART" && -b "$ROOT_PART" ]] || err "فشل إنشاء الأقسام على $DISK"

# ── 2. تهيئة ───────────────────────────────────────────
report_progress "تهيئة الأقسام" 10
mkfs.fat -F32 -n HATAN-EFI "$EFI_PART"
mkfs.ext4 -F -L HATAN-OS "$ROOT_PART"

# ── 3. Mount ───────────────────────────────────────────
report_progress "تحضير نظام الملفات" 12
mkdir -p "$MNT"
mount "$ROOT_PART" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI_PART" "$MNT/boot"

# ── 4. pacstrap ────────────────────────────────────────
report_progress "تثبيت Arch الأساسي" 18
pacstrap "$MNT" \
    base base-devel linux linux-firmware amd-ucode \
    networkmanager sudo grub efibootmgr dosfstools e2fsprogs \
    pipewire pipewire-pulse wireplumber

genfstab -U "$MNT" >> "$MNT/etc/fstab"

# ── 5. نسخ HATAN OS ────────────────────────────────────
report_progress "نسخ ملفات HATAN OS" 22
mkdir -p "$MNT/opt/hatan-os"
rsync -a --exclude='build/output' --exclude='.git' \
    "$PROJECT_DIR"/ "$MNT/opt/hatan-os/"

CHROOT_PROGRESS="$MNT/tmp/hatan-install-progress.json"
mkdir -p "$MNT/tmp"
printf '{"step":"بدء تثبيت HATAN","percent":25,"status":"running","done":false}\n' \
    > "$CHROOT_PROGRESS"

# ── 6. تثبيت HATAN داخل chroot ─────────────────────────
report_progress "تثبيت HATAN OS" 28

(
    while [[ -f "$CHROOT_PROGRESS" ]]; do
        if [[ -f "$CHROOT_PROGRESS" ]]; then
            cp -f "$CHROOT_PROGRESS" "$PROGRESS_FILE" 2>/dev/null || true
        fi
        sleep 2
    done
) &
SYNC_PID=$!

arch-chroot "$MNT" env \
    HATAN_GUI=1 \
    HATAN_NONINTERACTIVE=1 \
    HATAN_INSTALL_RECOMMENDED="$HATAN_INSTALL_RECOMMENDED" \
    HATAN_USERNAME="$HATAN_USERNAME" \
    HATAN_PROJECT_DIR=/opt/hatan-os \
    HATAN_PROGRESS_FILE=/tmp/hatan-install-progress.json \
    bash /opt/hatan-os/installer/install.sh

kill "$SYNC_PID" 2>/dev/null || true
cp -f "$CHROOT_PROGRESS" "$PROGRESS_FILE" 2>/dev/null || true

# ── 7. Bootloader ──────────────────────────────────────
report_progress "إعداد الإقلاع" 92
arch-chroot "$MNT" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot \
    --bootloader-id=HATAN-OS \
    --recheck
arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg

# ── 8. تم ──────────────────────────────────────────────
report_progress "اكتمل التثبيت" 100 success true
log "✅ HATAN OS مثبت على $DISK — أعد التشغيل"
