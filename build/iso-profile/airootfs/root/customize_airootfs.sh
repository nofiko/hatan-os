#!/bin/bash
# HATAN OS — تخصيص صورة ISO live (Arch official style)

echo "HATAN OS: customizing airootfs..."

# ── فتح root أولاً وآخراً (لا يعتمد على set -e) ────────
unlock_root() {
    [[ -f /etc/shadow ]] || return 0
    sed -i 's/^root:[!*]*:/root::/' /etc/shadow 2>/dev/null || true
    sed -i 's/^root:[^:]*:/root::/' /etc/shadow 2>/dev/null || true
    passwd -d root 2>/dev/null || true
    passwd -u root 2>/dev/null || true
    usermod -U root 2>/dev/null || true
    chmod 600 /etc/shadow 2>/dev/null || true
}

unlock_root

# ── لغة ───────────────────────────────────────────────
grep -q 'en_US.UTF-8' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
grep -q 'ar_SA.UTF-8' /etc/locale.gen 2>/dev/null || echo 'ar_SA.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>/dev/null || true
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime 2>/dev/null || true

# ── خدمات ─────────────────────────────────────────────
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable hatan-installer.service 2>/dev/null || true
systemctl enable getty@tty1.service 2>/dev/null || true

# ── علامة ISO ───────────────────────────────────────────
mkdir -p /etc/hatan
echo '1' > /etc/hatan/iso-live

chmod +x /usr/local/bin/hatan-install-now 2>/dev/null || true

unlock_root

echo "HATAN OS: airootfs ready (root unlocked)."
