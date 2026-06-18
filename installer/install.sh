#!/bin/bash
# HATAN OS - سكربت التثبيت على Steam Deck LCD

set -euo pipefail

HAT_DIR="/opt/hatan-os"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${HATAN_PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
NONINTERACTIVE="${HATAN_NONINTERACTIVE:-0}"
HATAN_USERNAME="${HATAN_USERNAME:-deck}"
HATAN_PROGRESS_FILE="${HATAN_PROGRESS_FILE:-/tmp/hatan-install-progress.json}"
HATAN_INSTALL_RECOMMENDED="${HATAN_INSTALL_RECOMMENDED:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[HATAN OS]${NC} $1"; }
warn() { echo -e "${YELLOW}[تحذير]${NC} $1"; }
err()  { echo -e "${RED}[خطأ]${NC} $1"; exit 1; }
step() { echo -e "${CYAN}==>${NC} $1"; }

report_progress() {
    local name="$1"
    local pct="$2"
    printf '{"step":"%s","percent":%s,"status":"running","done":false}\n' \
        "$name" "$pct" > "$HATAN_PROGRESS_FILE"
    step "$name"
}

[[ $EUID -eq 0 ]] || err "شغّل بصلاحيات root: sudo ./install.sh"

if [[ "${HATAN_GUI:-0}" != "1" ]]; then
    echo ""
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║     HATAN OS - تثبيت على Deck       ║"
    echo "  ╚══════════════════════════════════════╝"
    echo ""
    echo "  💡 للواجهة الرسومية: sudo ./hat-install.sh"
    echo ""
fi

# ── 0. مزامنة الأصول ─────────────────────────────────
report_progress "مزامنة الأصول" 2
bash "$PROJECT_DIR/scripts/sync-assets.sh" 2>/dev/null || true

# ── 1. نسخ ملفات HATAN OS ────────────────────────────
report_progress "نسخ ملفات النظام" 8
mkdir -p "$HAT_DIR" /var/lib/hatan/iso
cp -r "$PROJECT_DIR"/{ui,themes,config,base,scripts,installer,media-ref} "$HAT_DIR/" 2>/dev/null || \
cp -r "$PROJECT_DIR"/{ui,themes,config,base,scripts,installer} "$HAT_DIR/"
[[ -d "$PROJECT_DIR/media-ref" ]] && cp -r "$PROJECT_DIR/media-ref" "$HAT_DIR/" || true
chmod +x "$HAT_DIR/ui/shell/hat-shell.sh"
chmod +x "$HAT_DIR/ui/shell/hat-server.py"
chmod +x "$HAT_DIR/ui/shell/hat_api.py"
chmod +x "$HAT_DIR/ui/boot/hatan-boot.sh" 2>/dev/null || true
chmod +x "$HAT_DIR/ui/boot/boot-server.py" 2>/dev/null || true
chmod +x "$HAT_DIR/ui/boot/scripts/"*.sh 2>/dev/null || true
chmod +x "$HAT_DIR/scripts/install-deck-packages.sh"
chmod +x "$HAT_DIR/scripts/install-default-apps.sh"
chmod +x "$HAT_DIR/scripts/hat-capture-daemon.py"
chmod +x "$HAT_DIR/scripts/hat-record-toggle.sh"
chmod +x "$HAT_DIR/scripts/hat-deck-input.py"
chmod +x "$HAT_DIR/installer/hat-install.sh"
chmod +x "$HAT_DIR/installer/live-install.sh"
chmod +x "$HAT_DIR/installer/dual-boot-install.sh" 2>/dev/null || true
chmod +x "$HAT_DIR/installer/iso-install.sh" 2>/dev/null || true
chmod +x "$HAT_DIR/installer/install-server.py"
if [[ -f "$HAT_DIR/ui/boot/config/os-paths.deck.json" ]]; then
    cp "$HAT_DIR/ui/boot/config/os-paths.deck.json" "$HAT_DIR/ui/boot/config/os-paths.json"
fi

# ── 2. تكوين pacman ────────────────────────────────────
report_progress "إعداد مستودعات Valve" 12
cp "$HAT_DIR/base/pacman.conf" /etc/pacman.conf
pacman -Sy --noconfirm

# ── 3. تثبيت الحزم الأساسية (Steam Deck) ───────────────
report_progress "تثبيت تعريفات Valve" 20
bash "$HAT_DIR/scripts/install-deck-packages.sh" "$HAT_DIR/base/packages/essential.txt"

# ── 3b. التطبيقات الافتراضية ───────────────────────────
report_progress "تثبيت التطبيقات الافتراضية" 45
HAT_DIR="$HAT_DIR" bash "$HAT_DIR/scripts/install-default-apps.sh" || warn "بعض التطبيقات الافتراضية لم تُثبَّت"

# ── 4. firmware الصوت ──────────────────────────────────
report_progress "إعداد صوت Steam Deck" 52
FIRMWARE_DIR="/usr/lib/firmware/cirrus"
mkdir -p "$FIRMWARE_DIR"
for f in cs35l41-dsp1-spk-cali.bin cs35l41-dsp1-spk-cali.wmfw \
         cs35l41-dsp1-spk-prot.bin cs35l41-dsp1-spk-prot.wmfw; do
    src="/usr/lib/firmware/$f"
    [[ -f "$src" && ! -f "$FIRMWARE_DIR/$f" ]] && ln -sf "$src" "$FIRMWARE_DIR/$f"
done

# ── 5. Plymouth (شاشة الإقلاع) ─────────────────────────
report_progress "إعداد شاشة الإقلاع" 60
pacman -S --noconfirm plymouth 2>/dev/null || warn "plymouth غير متوفر"

PLYMOUTH_THEME="/usr/share/plymouth/themes/hatan-os"
mkdir -p "$PLYMOUTH_THEME"
if [[ -f "$HAT_DIR/themes/plymouth/hatan-os.plymouth" ]]; then
    cp "$HAT_DIR/themes/plymouth/hatan-os.plymouth" "$PLYMOUTH_THEME/"
    cp "$HAT_DIR/themes/plymouth/hatan-os.script" "$PLYMOUTH_THEME/"
fi
for img in "$HAT_DIR/themes/splash/boot.png" "$HAT_DIR/themes/splash/logo.png" "$HAT_DIR/logo.png"; do
    [[ -f "$img" ]] && cp "$img" "$PLYMOUTH_THEME/boot.png" && break
done

if command -v plymouth-set-default-theme &>/dev/null; then
    plymouth-set-default-theme -R hatan-os
fi

if [[ -f /etc/mkinitcpio.conf ]] && [[ "${HATAN_SKIP_MKINITCPIO:-0}" != "1" ]]; then
    if ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
        sed -i 's/^HOOKS=(\(.*\)keyboard)/HOOKS=(\1 plymouth keyboard)/' /etc/mkinitcpio.conf 2>/dev/null || \
        sed -i 's/^HOOKS=(base udev)/HOOKS=(base udev plymouth)/' /etc/mkinitcpio.conf 2>/dev/null || \
        warn "أضف plymouth يدوياً إلى HOOKS في /etc/mkinitcpio.conf"
    fi
    mkinitcpio -p linux 2>/dev/null || mkinitcpio -P 2>/dev/null || warn "فشل mkinitcpio"
fi

# ── 6. الخدمات ─────────────────────────────────────────
report_progress "تفعيل الخدمات" 68
systemctl enable NetworkManager
systemctl enable jupiter-fan-control.service 2>/dev/null || warn "jupiter-fan-control"
systemctl enable sddm.service 2>/dev/null || warn "sddm"

# ── 7. HATAN Shell كجلسة افتراضية ─────────────────────
report_progress "إعداد واجهة HATAN OS" 75
mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/hatan-os.conf << SDDM
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${HATAN_USERNAME}
Session=

[Wayland]
CompositorCommand=gamescope -W 1280 -H 800 -f -- /opt/hatan-os/ui/boot/hatan-boot.sh
SDDM

# ── 8. مستخدم ──────────────────────────────────────────
report_progress "إعداد المستخدم" 82
if ! id "$HATAN_USERNAME" &>/dev/null; then
    useradd -m -G wheel,audio,video,input,i2c "$HATAN_USERNAME"
    echo "${HATAN_USERNAME}:${HATAN_USERNAME}" | chpasswd 2>/dev/null || passwd "$HATAN_USERNAME"
    echo "${HATAN_USERNAME} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${HATAN_USERNAME}"
    chmod 440 "/etc/sudoers.d/${HATAN_USERNAME}"
fi

# ── 9. حزم إضافية ──────────────────────────────────────
install_rec="n"
if [[ -n "$HATAN_INSTALL_RECOMMENDED" ]]; then
    [[ "$HATAN_INSTALL_RECOMMENDED" == "1" ]] && install_rec="y"
elif [[ "$NONINTERACTIVE" != "1" ]]; then
    read -rp "تثبيت الحزم الموصى بها (Lutris, Wine, ...)؟ (y/n): " install_rec
else
    install_rec="y"
fi

if [[ "$install_rec" =~ ^[Yy] ]]; then
    report_progress "تثبيت الحزم الإضافية" 90
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        pacman -S --noconfirm "$pkg" || warn "فشل: $pkg"
    done < "$HAT_DIR/base/packages/recommended.txt"
fi

# ── 10. اختصار تشغيل ───────────────────────────────────
report_progress "إنهاء التثبيت" 98
ln -sf /opt/hatan-os/ui/shell/hat-shell.sh /usr/local/bin/hatan-shell
ln -sf /opt/hatan-os/ui/boot/hatan-boot.sh /usr/local/bin/hatan-boot 2>/dev/null || true
ln -sf /opt/hatan-os/installer/hat-install.sh /usr/local/bin/hatan-install 2>/dev/null || true

# ── خدمة تصوير الشاشة (اختصار عالمي) ─────────────────
report_progress "إعداد خدمة التصوير" 96
CAP_USER_HOME=$(eval echo "~${HATAN_USERNAME}")
USER_SYSTEMD="${CAP_USER_HOME}/.config/systemd/user"
mkdir -p "$USER_SYSTEMD"
cp "$HAT_DIR/config/systemd/hatan-capture.service" "$USER_SYSTEMD/"
cp "$HAT_DIR/config/systemd/hat-deck-input.service" "$USER_SYSTEMD/" 2>/dev/null || true
chmod +x "$HAT_DIR/scripts/hat-deck-input.py" 2>/dev/null || true
chown -R "${HATAN_USERNAME}:${HATAN_USERNAME}" "${CAP_USER_HOME}/.config/systemd" 2>/dev/null || true
if id "$HATAN_USERNAME" &>/dev/null; then
    sudo -u "$HATAN_USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$HATAN_USERNAME")" \
        systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "$HATAN_USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$HATAN_USERNAME")" \
        systemctl --user enable hatan-capture.service 2>/dev/null || warn "تفعيل خدمة التصوير"
    sudo -u "$HATAN_USERNAME" XDG_RUNTIME_DIR="/run/user/$(id -u "$HATAN_USERNAME")" \
        systemctl --user enable hat-deck-input.service 2>/dev/null || warn "تفعيل أزرار Steam/QAM"
fi

printf '{"step":"اكتمل التثبيت","percent":100,"status":"success","done":true}\n' \
    > "$HATAN_PROGRESS_FILE"

log "✅ اكتمل تثبيت HATAN OS!"

if [[ "${HATAN_GUI:-0}" != "1" ]]; then
    echo ""
    echo "  أعد التشغيل: reboot"
    echo ""
    echo "  بعد التشغيل:"
    echo "    1. شاشة HATAN OS (Plymouth)"
    echo "    2. شاشة الإقلاع — اختر Windows أو SteamOS"
    echo "    3. اضغط H للدخول لواجهة HATAN مباشرة"
    echo ""
    echo "  التطبيقات الافتراضية:"
    echo "    • Steam · Xbox · Microsoft Store · Brave"
    echo "    • الملفات · الإعدادات · تصوير الشاشة · ملفات EXE"
    echo ""
    echo "  المستخدم: ${HATAN_USERNAME}"
    echo "  تشغيل يدوي: hatan-shell"
    echo ""
fi
