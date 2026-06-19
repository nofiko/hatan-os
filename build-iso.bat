@echo off
chcp 65001 >nul
title HATAN OS — بناء ISO

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║     HATAN OS — بناء ISO                      ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  ملف ISO لا يُبنى على Windows مباشرة.
echo  يحتاج Arch Linux + archiso (~20 GB مساحة).
echo.
echo  ┌─ الخيارات ─────────────────────────────────┐
echo  │                                              │
echo  │  1. Arch Linux / Steam Deck (Arch)           │
echo  │     sudo ./build/build-iso.sh               │
echo  │                                              │
echo  │  2. WSL2 + Arch                              │
echo  │     wsl -d Arch                              │
echo  │     cd /mnt/c/Users/PC-12/Desktop/HAT2       │
echo  │     sudo ./build/build-iso.sh               │
echo  │                                              │
echo  │  3. GitHub Actions (من المتصفح)              │
echo  │     ارفع المشروع إلى GitHub                  │
echo  │     Actions ^> Build HATAN OS ISO ^> Run     │
echo  │     حمّل الملف من Artifacts                  │
echo  │                                              │
echo  └──────────────────────────────────────────────┘
echo.
echo  بعد البناء:
echo    • Etcher أو Rufus: GPT + UEFI + DD image mode
echo    • التحقق: bash scripts/verify-built-iso.sh build/output/*.iso
echo    • Boot Deck من USB -^> HATAN OS Auto Install
echo.
echo  راجع docs/ISO.md للتفاصيل.
echo.
pause
