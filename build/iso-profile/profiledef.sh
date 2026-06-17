#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="hatan-os"
iso_label="HATAN_OS"
iso_publisher="HATAN OS <https://github.com/hatan-os>"
iso_application="HATAN OS Installer for Steam Deck"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/opt/hatan-os/scripts/hatan-live-installer.sh"]="0:0:755"
  ["/opt/hatan-os/installer/install.sh"]="0:0:755"
  ["/opt/hatan-os/installer/iso-install.sh"]="0:0:755"
  ["/opt/hatan-os/installer/hat-install.sh"]="0:0:755"
  ["/opt/hatan-os/installer/install-server.py"]="0:0:755"
)
