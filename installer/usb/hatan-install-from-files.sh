#!/bin/bash
# نقطة الدخول على جذر USB — يُنسخ إلى E:\hatan-install-from-files.sh
USB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HATAN_PROJECT_DIR="$USB_ROOT/hatan-os"
exec bash "$HATAN_PROJECT_DIR/installer/launch-from-files.sh"
