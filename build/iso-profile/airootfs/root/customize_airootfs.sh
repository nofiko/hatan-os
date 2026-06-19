#!/bin/bash
# HATAN OS — تخصيص ISO live لـ Steam Deck

echo "HATAN OS: customizing airootfs for Steam Deck..."

echo 'root:hatan' | chpasswd 2>/dev/null || true

# روابط نواة archiso القياسية (احتياط)
for kdir in /boot /boot/x86_64; do
    [[ -d "$kdir" ]] || continue
    [[ -e "$kdir/vmlinuz-linux-neptune" ]] && ln -sfn vmlinuz-linux-neptune "$kdir/vmlinuz-linux"
    [[ -e "$kdir/initramfs-linux-neptune.img" ]] && ln -sfn initramfs-linux-neptune.img "$kdir/initramfs-linux.img"
done

grep -q 'en_US.UTF-8' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
grep -q 'ar_SA.UTF-8' /etc/locale.gen 2>/dev/null || echo 'ar_SA.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>/dev/null || true
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime 2>/dev/null || true

systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable iwd.service 2>/dev/null || true
systemctl enable hatan-wifi-autoconnect.service 2>/dev/null || true
systemctl enable getty@tty1.service 2>/dev/null || true

# WiFi Deck: NM يستخدم iwd كخلفية — ملفات الاتصال الافتراضية 600
chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null || true
chmod +x /usr/local/bin/hatan-wifi-autoconnect.sh 2>/dev/null || true
chmod +x /usr/local/bin/hatan-wifi 2>/dev/null || true

mkdir -p /etc/hatan
echo '1' > /etc/hatan/iso-live

cat > /etc/motd << 'EOF'

  HATAN OS — Steam Deck
  root / hatan  |  hatan-wifi  |  hatan-install-now

EOF

chmod +x /usr/local/bin/hatan-install-now 2>/dev/null || true

# linux-neptune installs a default mkinitcpio preset (no archiso hooks).
# Without archiso hooks the live initramfs cannot find/mount airootfs.sfs.
install -Dm644 /dev/stdin /etc/mkinitcpio.d/linux-neptune.preset <<'EOF'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux-neptune'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image="/boot/initramfs-linux-neptune.img"
EOF

echo "HATAN OS: rebuilding initramfs with archiso hooks..."
mkinitcpio -p linux-neptune

echo "HATAN OS: airootfs ready (Steam Deck)."
