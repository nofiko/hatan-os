# HATAN OS — بدء المثبّت تلقائياً على tty1 (Steam Deck)
if [[ "$(tty)" == "/dev/tty1" ]] && [[ -f /etc/hatan/iso-live ]] && [[ ! -f /tmp/.hatan-installer-started ]]; then
  touch /tmp/.hatan-installer-started
  export HATAN_ISO_LIVE=1
  export HATAN_PROJECT_DIR=/opt/hatan-os
  /opt/hatan-os/scripts/hatan-live-installer.sh || /usr/local/bin/hatan-install-now
fi
