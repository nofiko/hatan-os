#!/usr/bin/env bash
# HATAN OS — تثبيت SteamOS من partsets (على Linux / Steam Deck)
set -euo pipefail

PARTSETS="${1:-}"
EFI="${2:-}"

[[ -n "$PARTSETS" && -f "$PARTSETS/self" ]] || {
  echo "partsets غير صالحة: $PARTSETS" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || { echo "يتطلب root" >&2; exit 1; }

echo "[HATAN] SteamOS partsets: $PARTSETS"

if command -v steamos-install >/dev/null 2>&1; then
  steamos-install
  exit $?
fi

if [[ -z "$EFI" || ! -f "$EFI" ]]; then
  for base in /boot/efi /efi; do
  if [[ -f "$base/steamos/grubx64.efi" ]]; then
      EFI="$base/steamos/grubx64.efi"
      break
    fi
  done
fi

DISK="${HATAN_STEAM_DISK:-/dev/nvme0n1}"
PART="${HATAN_STEAM_EFI_PART:-2}"

if [[ -f "$EFI" ]]; then
  efibootmgr -d "$DISK" -p "$PART" -c 'SteamOS' -l '\\EFI\\steamos\\grubx64.efi' 2>/dev/null || true
  entry=$(efibootmgr | awk '/SteamOS/{gsub(/\*/, "", $1); print substr($1,5); exit}')
  if [[ -n "$entry" ]]; then
    efibootmgr -n "$entry"
    systemctl reboot
    exit 0
  fi
fi

echo "شغّل steamos-install من وضع المطوّر على Steam Deck، أو أكمل من استعادة SteamOS." >&2
exit 1
