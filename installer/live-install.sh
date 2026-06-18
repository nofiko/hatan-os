#!/bin/bash
# HATAN OS - Full installer from Arch live (disk partition + Arch + HATAN)

set -Eeuo pipefail

DISK="${HATAN_TARGET_DISK:-}"
MNT="${HATAN_TARGET_MOUNT:-/mnt}"
PROJECT_DIR="${HATAN_PROJECT_DIR:-}"
PROGRESS_FILE="${HATAN_PROGRESS_FILE:-/tmp/hatan-install-progress.json}"
LOG_FILE="${HATAN_LOG_FILE:-/tmp/hatan-live-install.log}"
HATAN_USERNAME="${HATAN_USERNAME:-deck}"
HATAN_INSTALL_RECOMMENDED="${HATAN_INSTALL_RECOMMENDED:-0}"
SYNC_PID=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[خطأ]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
step() { echo -e "${CYAN}==>${NC} $*" | tee -a "$LOG_FILE"; }

report_progress() {
    local name="$1"
    local pct="$2"
    local status="${3:-running}"
    local done="${4:-false}"
    printf '{"step":"%s","percent":%s,"status":"%s","done":%s}\n' \
        "$name" "$pct" "$status" "$done" > "$PROGRESS_FILE"
    step "$name"
}

cleanup() {
    set +e
    if [[ -n "${SYNC_PID:-}" ]]; then
        kill "$SYNC_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

on_error() {
    local line="$1"
    report_progress "فشل التثبيت" 100 error true
    err "فشل التثبيت عند السطر: $line"
}
trap 'on_error $LINENO' ERR

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || err "الأمر غير موجود: $cmd"
}

find_project_dir() {
    local candidates=(
        "/opt/hatan-os"
        "/mnt/usb/hatan-os"
        "/run/archiso/bootmnt/hatan-os"
        "/run/media/archiso/hatan-os"
    )
    local p
    for p in "${candidates[@]}"; do
        if [[ -d "$p/installer" ]]; then
            PROJECT_DIR="$p"
            return 0
        fi
    done

    p="$(find /run/media /mnt -maxdepth 4 -type d -name hatan-os 2>/dev/null | head -n1 || true)"
    if [[ -n "$p" && -d "$p/installer" ]]; then
        PROJECT_DIR="$p"
        return 0
    fi
    return 1
}

pick_target_disk() {
    if [[ -n "${DISK:-}" && -b "$DISK" ]]; then
        return 0
    fi
    if [[ -b /dev/nvme0n1 ]]; then
        DISK="/dev/nvme0n1"
        return 0
    fi

    # fallback: first non-removable whole disk
    local picked
    picked="$(lsblk -dpno NAME,TYPE,RM | awk '$2=="disk" && $3==0 {print $1; exit}')"
    if [[ -n "$picked" && -b "$picked" ]]; then
        DISK="$picked"
        return 0
    fi
    return 1
}

ensure_internet() {
    if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
        return 0
    fi
    warn "لا يوجد إنترنت. اتصل بالشبكة أولاً عبر iwctl."
    warn "مثال سريع:"
    warn "  iwctl -> station wlan0 scan -> station wlan0 get-networks -> station wlan0 connect \"SSID\""
    err "مطلوب إنترنت لإكمال التثبيت."
}

normalize_script_lf() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    sed -i 's/\r$//' "$f" || true
}

resolve_partitions() {
    if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then
        EFI_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        EFI_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi
}

write_root_cmdline() {
    local root_uuid="$1"
    arch-chroot "$MNT" bash -c "echo 'root=UUID=${root_uuid} rw' > /etc/cmdline.d/00-root.conf"
    arch-chroot "$MNT" sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"root=UUID=${root_uuid} rw\"|" /etc/default/grub 2>/dev/null || \
        arch-chroot "$MNT" bash -c "echo 'GRUB_CMDLINE_LINUX=\"root=UUID=${root_uuid} rw\"' >> /etc/default/grub"
}

disable_uki_if_present() {
    arch-chroot "$MNT" bash -c '
        shopt -s nullglob
        for f in /etc/mkinitcpio.d/*.preset; do
            sed -i "s/^default_uki=/#default_uki=/" "$f"
            sed -i "s/^fallback_uki=/#fallback_uki=/" "$f"
        done
        rm -f /boot/EFI/Linux/*.efi 2>/dev/null || true
        mkdir -p /etc/cmdline.d
    '
}

main() {
    : > "$LOG_FILE"
    [[ $EUID -eq 0 ]] || err "يتطلب صلاحيات root"

    require_cmd wipefs
    require_cmd pacstrap
    require_cmd genfstab
    require_cmd arch-chroot
    require_cmd rsync
    require_cmd blkid
    require_cmd grub-install
    require_cmd grub-mkconfig
    require_cmd mkfs.fat
    require_cmd mkfs.ext4

    pick_target_disk || err "تعذر اكتشاف القرص الهدف. حدده عبر HATAN_TARGET_DISK=/dev/xxx"
    if [[ -z "${PROJECT_DIR:-}" ]]; then
        find_project_dir || err "تعذر العثور على مجلد hatan-os. تأكد من توصيل USB الذي يحتوي hatan-os."
    fi
    [[ -b "$DISK" ]] || err "القرص غير موجود: $DISK"
    [[ -d "$PROJECT_DIR/installer" ]] || err "ملفات HATAN غير موجودة في $PROJECT_DIR"
    ensure_internet
    normalize_script_lf "$PROJECT_DIR/installer/install.sh"
    normalize_script_lf "$PROJECT_DIR/installer/live-install.sh"
    log "المسار المكتشف لمشروع HATAN: $PROJECT_DIR"
    log "القرص الهدف للتثبيت: $DISK"

    if [[ "${HATAN_DUAL_BOOT:-0}" == "1" ]]; then
        # shellcheck source=/dev/null
        source "$PROJECT_DIR/installer/dual-boot-install.sh"
        report_progress "إعداد Dual Boot" 5
        dual_boot_prepare_partitions
        resolve_partitions
        report_progress "تحضير نظام الملفات" 12
        dual_boot_mount_partitions
    else
    report_progress "تقسيم القرص" 5
    wipefs -af "$DISK" 2>/dev/null || true
    if command -v sgdisk >/dev/null 2>&1; then
        sgdisk -Z "$DISK"
        sgdisk -n "1:0:+512M" -t "1:ef00" -c "1:EFI" \
               -n "2:0:0"     -t "2:8300" -c "2:HATAN-OS" "$DISK"
    else
        require_cmd parted
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart EFI fat32 1MiB 513MiB
        parted -s "$DISK" set 1 esp on
        parted -s "$DISK" mkpart root ext4 513MiB 100%
    fi
    partprobe "$DISK" 2>/dev/null || true
    sleep 2

    resolve_partitions
    [[ -b "$EFI_PART" && -b "$ROOT_PART" ]] || err "فشل إنشاء الأقسام على $DISK"

    report_progress "تهيئة الأقسام" 10
    mkfs.fat -F32 -n HATAN-EFI "$EFI_PART"
    mkfs.ext4 -F -L HATAN-OS "$ROOT_PART"

    report_progress "تحضير نظام الملفات" 12
    mkdir -p "$MNT"
    mount "$ROOT_PART" "$MNT"
    mkdir -p "$MNT/boot"
    mount "$EFI_PART" "$MNT/boot"

    fi

    report_progress "تثبيت Arch الأساسي" 18
    pacstrap "$MNT" \
        base base-devel linux linux-firmware amd-ucode \
        networkmanager sudo grub efibootmgr dosfstools e2fsprogs \
        pipewire pipewire-pulse wireplumber mkinitcpio
    genfstab -U "$MNT" >> "$MNT/etc/fstab"

    report_progress "نسخ ملفات HATAN OS" 22
    mkdir -p "$MNT/opt/hatan-os"
    rsync -a --exclude='build/output' --exclude='.git' \
        "$PROJECT_DIR"/ "$MNT/opt/hatan-os/"

    local chroot_progress="$MNT/tmp/hatan-install-progress.json"
    mkdir -p "$MNT/tmp"
    printf '{"step":"بدء تثبيت HATAN","percent":25,"status":"running","done":false}\n' > "$chroot_progress"

    report_progress "تثبيت HATAN OS" 28
    (
        while [[ -f "$chroot_progress" ]]; do
            cp -f "$chroot_progress" "$PROGRESS_FILE" 2>/dev/null || true
            sleep 2
        done
    ) &
    SYNC_PID=$!

    arch-chroot "$MNT" env \
        HATAN_GUI=1 \
        HATAN_NONINTERACTIVE=1 \
        HATAN_SKIP_MKINITCPIO=1 \
        HATAN_INSTALL_RECOMMENDED="$HATAN_INSTALL_RECOMMENDED" \
        HATAN_USERNAME="$HATAN_USERNAME" \
        HATAN_PROJECT_DIR=/opt/hatan-os \
        HATAN_PROGRESS_FILE=/tmp/hatan-install-progress.json \
        bash /opt/hatan-os/installer/install.sh

    kill "$SYNC_PID" 2>/dev/null || true
    SYNC_PID=""
    cp -f "$chroot_progress" "$PROGRESS_FILE" 2>/dev/null || true

    report_progress "إعداد الإقلاع" 92
    local root_uuid
    root_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
    [[ -n "$root_uuid" ]] || err "تعذر قراءة UUID لقسم الجذر"

    disable_uki_if_present
    write_root_cmdline "$root_uuid"
    arch-chroot "$MNT" mkinitcpio -p linux 2>/dev/null || true
    arch-chroot "$MNT" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot \
        --bootloader-id=HATAN-OS \
        --recheck
    arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg

    if [[ "${HATAN_DUAL_BOOT:-0}" == "1" ]]; then
        dual_boot_grub_config || warn "تعذّر تحديث GRUB لـ Dual Boot"
    fi

    report_progress "اكتمل التثبيت" 100 success true
    log "اكتمل تثبيت HATAN OS على $DISK"
    log "أعد التشغيل ثم افصل USB قبل الإقلاع النهائي."
}

main "$@"
