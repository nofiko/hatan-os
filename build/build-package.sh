#!/bin/bash
# HATAN OS - بناء حزمة التوزيعة
# يُشغَّل على جهاز Arch Linux (ليس بالضرورة Steam Deck)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/output"
REPO_DIR="$BUILD_DIR/repo"
PKG_NAME="hatan-os-shell"
PKG_VERSION="0.1.0"

echo "[HATAN OS] بناء حزمة $PKG_NAME v$PKG_VERSION..."

mkdir -p "$BUILD_DIR" "$REPO_DIR"

# ── إنشاء PKGBUILD ─────────────────────────────────────
BUILD_PKG="$BUILD_DIR/$PKG_NAME"
rm -rf "$BUILD_PKG"
mkdir -p "$BUILD_PKG"

cat > "$BUILD_PKG/PKGBUILD" << PKGBUILD
pkgname=$PKG_NAME
pkgver=$PKG_VERSION
pkgrel=1
pkgdesc="HATAN OS custom shell for Steam Deck"
arch=('any')
depends=('chromium' 'gamescope' 'nodejs')
source=()
package() {
    mkdir -p "\$pkgdir/opt/hatan-os"
    cp -r "$PROJECT_DIR/ui" "\$pkgdir/opt/hatan-os/"
    cp -r "$PROJECT_DIR/themes" "\$pkgdir/opt/hatan-os/"
    cp -r "$PROJECT_DIR/config" "\$pkgdir/opt/hatan-os/"
    install -Dm755 "$PROJECT_DIR/ui/shell/hat-shell.sh" "\$pkgdir/usr/bin/hatan-shell"
}
PKGBUILD

# ── بناء الحزمة ──────────────────────────────────────
cd "$BUILD_PKG"
makepkg -f -c --noconfig

# ── إنشاء المستودع ───────────────────────────────────
mv "$BUILD_PKG"/*.pkg.tar.* "$REPO_DIR/" 2>/dev/null || true
cd "$REPO_DIR"
repo-add hatan-os.db.tar.zst *.pkg.tar.zst 2>/dev/null || true

echo ""
echo "✅ اكتمل البناء!"
echo "   الحزمة: $REPO_DIR/"
echo ""
echo "   للتثبيت على Steam Deck:"
echo "   pacman -U $REPO_DIR/*.pkg.tar.zst"
