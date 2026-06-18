#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="hatan-os"
iso_label="HATAN_OS"
iso_publisher="HATAN OS"
iso_application="HATAN OS Installer for Steam Deck"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'uefi-x64.systemd-boot.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:0400"
  ["/root"]="0:0:0750"
  ["/root/.automated_script.sh"]="0:0:0755"
  ["/root/.gnupg"]="0:0:0700"
  ["/usr/local/bin/hatan-autoinstall.sh"]="0:0:0755"
  ["/usr/local/bin/hatan-install-now"]="0:0:0755"
)
