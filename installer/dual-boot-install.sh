#!/bin/bash
# HATAN OS — تقسيم Dual Boot (يحافظ على SteamOS / Windows)

set -euo pipefail

dual_boot_prepare_partitions() {
    : "${DISK:?DISK required}"
    : "${MNT:?MNT required}"

    if [[ -n "${HATAN_ROOT_PART:-}" && -b "$HATAN_ROOT_PART" ]]; then
        ROOT_PART="$HATAN_ROOT_PART"
        EFI_PART="${HATAN_EFI_PART:-}"
        if [[ -z "$EFI_PART" ]]; then
            EFI_PART="$(lsblk -rno NAME,PARTTYPE "$DISK" | awk '$2 ~ /EFI|ef00/ {print "/dev/"$1; exit}')"
        fi
        [[ -n "$EFI_PART" && -b "$EFI_PART" ]] || err "حدد HATAN_EFI_PART لقسم EFI المشترك"
        log "Dual-boot: استخدام القسم الموجود $ROOT_PART (EFI: $EFI_PART)"
        return 0
    fi

    if command -v sgdisk >/dev/null 2>&1; then
        local free_start free_size
        free_start="$(sgdisk -F "$DISK" 2>/dev/null | awk '{print $2}')"
        free_size="$(sgdisk -F "$DISK" 2>/dev/null | awk '{print $3}')"
        if [[ -n "$free_start" && -n "$free_size" && "$free_size" -gt 10485760 ]]; then
            log "Dual-boot: إنشاء قسم HATAN في المساحة الحرة (${free_size} sectors)"
            sgdisk -n "0:${free_start}:+20G" -t "0:8300" -c "0:HATAN-OS" "$DISK"
            partprobe "$DISK" 2>/dev/null || true
            sleep 2
            ROOT_PART="$(lsblk -rno NAME,PARTLABEL "$DISK" | awk '$2=="HATAN-OS" {print "/dev/"$1; exit}')"
            EFI_PART="$(lsblk -rno NAME,PARTTYPE "$DISK" | awk '$2 ~ /ef00/ {print "/dev/"$1; exit}')"
            [[ -n "$ROOT_PART" && -b "$ROOT_PART" ]] || err "فشل إنشاء قسم HATAN-OS"
            mkfs.ext4 -F -L HATAN-OS "$ROOT_PART"
            return 0
        fi
    fi

    err "Dual-boot: لا توجد مساحة حرة كافية. عيّن HATAN_ROOT_PART يدوياً أو وفّر ~20GB."
}

dual_boot_mount_partitions() {
    mkdir -p "$MNT"
    mount "$ROOT_PART" "$MNT"
    mkdir -p "$MNT/boot/efi"
    if mountpoint -q /boot/efi 2>/dev/null; then
        mount --bind /boot/efi "$MNT/boot/efi"
    else
        mount "$EFI_PART" "$MNT/boot/efi"
    fi
    mkdir -p "$MNT/boot"
    if ! mountpoint -q "$MNT/boot" 2>/dev/null; then
        local boot_size
        boot_size="$(lsblk -b -rno SIZE "$EFI_PART" 2>/dev/null | head -n1 || echo 0)"
        if [[ "$boot_size" -lt 300000000 ]]; then
            mkdir -p "$MNT/boot"
        else
            mount "$EFI_PART" "$MNT/boot" || mount "$EFI_PART" "$MNT/boot/efi"
        fi
    fi
}

dual_boot_grub_config() {
    arch-chroot "$MNT" pacman -S --needed --noconfirm os-prober 2>/dev/null || true
    arch-chroot "$MNT" bash -c 'echo GRUB_DISABLE_OS_PROBER=false >> /etc/default/grub' 2>/dev/null || true
    arch-chroot "$MNT" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || \
        arch-chroot "$MNT" grub-mkconfig -o /boot/efi/grub/grub.cfg 2>/dev/null || true
}
