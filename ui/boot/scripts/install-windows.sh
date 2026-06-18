#!/usr/bin/env bash
# HATAN OS — تثبيت Windows من مصدر D:\ أو ISO
set -euo pipefail

SOURCE="${1:-}"
SETUP=""

if [[ -f "$SOURCE/setup.exe" ]]; then
  SETUP="$SOURCE/setup.exe"
elif [[ -f "$SOURCE" && "$SOURCE" == *.iso ]]; then
  echo "[HATAN] ISO: $SOURCE"
  mkdir -p /var/lib/hatan/mnt/winiso
  mount -o loop,ro "$SOURCE" /var/lib/hatan/mnt/winiso
  SETUP="/var/lib/hatan/mnt/winiso/setup.exe"
fi

[[ -n "$SETUP" && -f "$SETUP" ]] || {
  echo "لم يُعثر على setup.exe في: $SOURCE" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || { echo "يتطلب root" >&2; exit 1; }

echo "[HATAN] Windows setup: $SETUP"
echo "[HATAN] تحقق من المساحة..."
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT

# على Deck: يُفضّل تقسيم يدوي ثم تشغيل setup من USB
if command -v ntfs-3g >/dev/null 2>&1; then
  echo "[HATAN] جهّز قسم NTFS ثم أعد التشغيل من USB الذي يحتوي Windows (D:)"
fi

MARKER="/var/lib/hatan/windows-ready"
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"
echo "[HATAN] تم التحضير — أعد التشغيل من وسيط التثبيت D:"
