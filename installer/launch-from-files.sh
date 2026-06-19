#!/bin/bash
# HATAN OS — التثبيت من تطبيق الملفات (Steam Deck Desktop Mode)
# انقر الملف على USB من Dolphin / Files ثم أكّد التثبيت.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

msg()  { echo -e "${GREEN}[HATAN OS]${NC} $*"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $*"; }
err()  { echo -e "${RED}[خطأ]${NC} $*"; exit 1; }

resolve_project_dir() {
    if [[ -n "${HATAN_PROJECT_DIR:-}" && -d "${HATAN_PROJECT_DIR}/installer" ]]; then
        echo "$(cd "$HATAN_PROJECT_DIR" && pwd)"
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "$0")" && pwd)"

    if [[ -f "$script_dir/live-install.sh" ]]; then
        echo "$(cd "$script_dir/.." && pwd)"
        return 0
    fi

    local p
    for p in \
        "$script_dir/hatan-os" \
        "/opt/hatan-os" \
        "/run/media/deck"/*/hatan-os \
        "/run/media/deck"/*/*/hatan-os \
        "/run/media"/*/hatan-os \
        "/run/media"/*/*/hatan-os; do
        [[ -d "$p/installer" ]] || continue
        echo "$(cd "$p" && pwd)"
        return 0
    done

    p="$(find /run/media /mnt -maxdepth 5 -type d -name hatan-os 2>/dev/null | head -n1 || true)"
    [[ -n "$p" && -d "$p/installer" ]] && { echo "$p"; return 0; }
    return 1
}

is_steamos_desktop() {
    [[ -f /etc/os-release ]] || return 1
    grep -qiE 'steamos|steam os|holo' /etc/os-release
}

prepare_steamos_host() {
    is_steamos_desktop || return 0

    msg "وضع SteamOS — تجهيز أدوات التثبيت..."
    export HATAN_DUAL_BOOT="${HATAN_DUAL_BOOT:-1}"

    if command -v pacstrap &>/dev/null && command -v arch-chroot &>/dev/null; then
        return 0
    fi

    if command -v steamos-readonly &>/dev/null; then
        steamos-readonly disable 2>/dev/null || warn "تعذّر تعطيل القرص للقراءة فقط — قد تحتاج كلمة مرور Steam"
    fi

    pacman -Sy --needed --noconfirm \
        arch-install-scripts grub efibootmgr dosfstools e2fsprogs \
        parted gptfdisk rsync 2>/dev/null || {
        err "ثبّت الأدوات يدوياً في الطرفية:
  sudo steamos-readonly disable
  sudo pacman -S arch-install-scripts grub efibootmgr dosfstools e2fsprogs parted gptfdisk rsync"
    }
    msg "أدوات التثبيت جاهزة"
}

show_confirm_dialog() {
    local text title
    title="تثبيت HATAN OS"
    if [[ "${HATAN_DUAL_BOOT:-0}" == "1" ]]; then
        text="سيتم تثبيت HATAN OS بجانب SteamOS الحالي (Dual Boot).\nتحتاج إنترنت (~30–60 دقيقة).\n\nهل تريد المتابعة؟"
    else
        text="تحذير: سيتم مسح القرص الداخلي بالكامل!\n\nهل تريد المتابعة؟"
    fi

    if command -v zenity &>/dev/null; then
        zenity --question --title="$title" --text="$text" --width=420 || exit 0
        return 0
    fi
    if command -v kdialog &>/dev/null; then
        kdialog --title "$title" --yesno "$text" || exit 0
        return 0
    fi

    echo ""
    echo -e "${YELLOW}$text${NC}"
    read -rp "اكتب YES للمتابعة: " ans
    [[ "$ans" == "YES" ]] || exit 0
}

main() {
    local project_dir
    project_dir="$(resolve_project_dir)" || err "لم يُعثر على مجلد hatan-os — انسخ المشروع كاملاً إلى USB"

    export HATAN_PROJECT_DIR="$project_dir"
    export HATAN_FROM_FILES=1

    # إعادة التشغيل بصلاحيات root (نافذة كلمة مرور Steam)
    if [[ $EUID -ne 0 ]]; then
        if command -v pkexec &>/dev/null; then
            exec pkexec env \
                HATAN_PROJECT_DIR="$HATAN_PROJECT_DIR" \
                HATAN_FROM_FILES=1 \
                HATAN_DUAL_BOOT="${HATAN_DUAL_BOOT:-}" \
                bash "$project_dir/installer/launch-from-files.sh"
        fi
        err "يتطلب صلاحيات المسؤول: sudo bash $0"
    fi

    sed -i 's/\r$//' "$project_dir/installer/"*.sh 2>/dev/null || true
    chmod +x "$project_dir/installer/"*.sh 2>/dev/null || true

    prepare_steamos_host
    show_confirm_dialog

    export HATAN_ISO_LIVE=1
    export HATAN_NONINTERACTIVE=1
    export HATAN_INSTALL_RECOMMENDED="${HATAN_INSTALL_RECOMMENDED:-0}"

    msg "بدء المثبّت الرسومي..."
    msg "المسار: $project_dir"

    exec bash "$project_dir/installer/hat-install.sh"
}

main "$@"
