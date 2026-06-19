#!/bin/bash
# HATAN OS — دمج live-sysroot داخل airootfs.sfs (للتثبيت التلقائي بدون ISO)
set -euo pipefail

LIVE_DIR="${1:?hatan-live directory on USB}"
SYSROOT="${2:?live-sysroot directory}"
SFS="$LIVE_DIR/x86_64/airootfs.sfs"

command -v unsquashfs >/dev/null || { echo "unsquashfs missing — install squashfs-tools"; exit 1; }
command -v mksquashfs >/dev/null || { echo "mksquashfs missing — install squashfs-tools"; exit 1; }
[[ -f "$SFS" ]] || { echo "airootfs.sfs not found: $SFS"; exit 1; }
[[ -d "$SYSROOT" ]] || { echo "sysroot not found: $SYSROOT"; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "[hatan] extracting airootfs.sfs..."
unsquashfs -f -d "$WORKDIR/root" "$SFS"

echo "[hatan] merging autoinstall files..."
rsync -a "$SYSROOT/" "$WORKDIR/root/"

WANTS="$WORKDIR/root/etc/systemd/system/multi-user.target.wants"
mkdir -p "$WANTS"
ln -sf ../hatan-autoinstall.service "$WANTS/hatan-autoinstall.service"

echo "[hatan] rebuilding airootfs.sfs (may take a few minutes)..."
mv "$SFS" "${SFS}.bak"
mksquashfs "$WORKDIR/root" "$SFS" -comp xz -Xbcj x86 -b 1M -noappend
rm -f "${SFS}.bak"

echo "[hatan] live-sysroot injection complete"
