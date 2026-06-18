#!/bin/bash
# HATAN OS — بناء ملف ISO للتثبيت (Arch Linux أو WSL)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/output"
RELENG="/usr/share/archiso/configs/releng"
WORK="$ROOT/build/iso-work"

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║   HATAN OS — بناء ملف ISO           ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "شغّل كـ root: sudo bash build/build-iso.sh"
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "ثبّت archiso: pacman -S archiso"
    exit 1
fi

if [[ ! -d "$RELENG" ]]; then
    echo "لم يُعثر على قالب releng في $RELENG"
    exit 1
fi

echo "==> نسخ قالب Arch ISO..."
rm -rf "$WORK"
mkdir -p "$WORK"
cp -a "$RELENG"/* "$WORK/"

# تخصيص اسم ISO
sed -i 's/^iso_name=.*/iso_name="hatan-os"/' "$WORK/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="HATAN_OS"/' "$WORK/profiledef.sh"
sed -i 's/^iso_publisher=.*/iso_publisher="HATAN OS"/' "$WORK/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="HATAN OS Installer for Steam Deck"/' "$WORK/profiledef.sh"

echo "==> إضافة حزم المثبت..."
grep -qxF 'rsync' "$WORK/packages.x86_64" || echo rsync >> "$WORK/packages.x86_64"
grep -qxF 'iwd' "$WORK/packages.x86_64" || echo iwd >> "$WORK/packages.x86_64"

AIROOT="$WORK/airootfs"
mkdir -p "$AIROOT/opt/hatan-os" "$AIROOT/usr/local/bin" \
    "$AIROOT/etc/systemd/system/multi-user.target.wants"

echo "==> تضمين ملفات HATAN OS..."
rsync -a --delete \
    --exclude='build/output' \
    --exclude='build/iso-work' \
    --exclude='.git' \
    "$ROOT/" "$AIROOT/opt/hatan-os/"

cp "$ROOT/installer/ventoy/live-sysroot/usr/local/bin/hatan-autoinstall.sh" \
    "$AIROOT/usr/local/bin/hatan-autoinstall.sh"
cp "$ROOT/installer/ventoy/live-sysroot/etc/systemd/system/hatan-autoinstall.service" \
    "$AIROOT/etc/systemd/system/hatan-autoinstall.service"

cat > "$AIROOT/usr/local/bin/hatan-install-now" << 'EOF'
#!/bin/bash
set -euo pipefail
exec > >(tee -a /tmp/hatan-install-now.log) 2>&1
echo "[hatan] ISO installer: $(date)"
for p in /opt/hatan-os /run/archiso/bootmnt/hatan-os; do
    [[ -f "$p/installer/live-install.sh" ]] || continue
    export HATAN_PROJECT_DIR="$p" HATAN_NONINTERACTIVE=1 HATAN_INSTALL_RECOMMENDED=0
    export HATAN_TARGET_DISK="${HATAN_TARGET_DISK:-/dev/nvme0n1}"
    sed -i 's/\r$//' "$p/installer/live-install.sh" || true
    chmod +x "$p/installer/live-install.sh"
    exec bash "$p/installer/live-install.sh"
done
echo "[hatan] hatan-os not found"; exit 1
EOF
chmod +x "$AIROOT/usr/local/bin/hatan-install-now"

ln -sf ../hatan-autoinstall.service \
    "$AIROOT/etc/systemd/system/multi-user.target.wants/hatan-autoinstall.service"

mkdir -p "$OUT"
echo "==> بناء ISO (10-25 دقيقة)..."
mkarchiso -v -r -o "$OUT" "$WORK"

ISO="$(ls -1t "$OUT"/hatan-os-*.iso 2>/dev/null | head -n1 || true)"
echo ""
if [[ -n "$ISO" ]]; then
    echo "✅ ISO جاهز:"
    echo "   $ISO"
    ls -lh "$ISO"
else
    ls -la "$OUT"
fi
