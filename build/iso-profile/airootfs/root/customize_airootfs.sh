#!/bin/bash
# HATAN OS — تخصيص ISO live لـ Steam Deck

echo "HATAN OS: customizing airootfs for Steam Deck..."

# كلمة مرور live (تجنّب emergency من root الفارغ على Deck)
echo 'root:hatan' | chpasswd 2>/dev/null || true

grep -q 'en_US.UTF-8' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
grep -q 'ar_SA.UTF-8' /etc/locale.gen 2>/dev/null || echo 'ar_SA.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>/dev/null || true
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'KEYMAP=us' > /etc/vconsole.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime 2>/dev/null || true

systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable iwd.service 2>/dev/null || true
systemctl enable hatan-installer.service 2>/dev/null || true

mkdir -p /etc/hatan
echo '1' > /etc/hatan/iso-live

cat > /etc/motd << 'EOF'

  HATAN OS — Steam Deck
  root / hatan  |  hatan-install-now

EOF

chmod +x /usr/local/bin/hatan-install-now 2>/dev/null || true

echo "HATAN OS: airootfs ready (Steam Deck)."
