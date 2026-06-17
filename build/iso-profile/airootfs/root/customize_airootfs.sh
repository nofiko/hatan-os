#!/bin/bash
# HATAN OS — تخصيص صورة ISO live

set -euo pipefail

echo "HATAN OS: customizing airootfs..."

# لغة ومنطقة
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ar_SA.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# شبكة
systemctl enable NetworkManager.service

# مثبّت HATAN — يبدأ تلقائياً بعد الإقلاع
systemctl enable hatan-installer.service

# root بدون كلمة مرور (Arch live standard — للطوارئ)
passwd -d root 2>/dev/null || true
passwd -u root 2>/dev/null || true
mkdir -p /etc/hatan
echo "1" > /etc/hatan/iso-live

echo "HATAN OS: airootfs ready."
