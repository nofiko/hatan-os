@echo off
title HATAN OS - Build ISO
cd /d "%~dp0"

where wsl >nul 2>&1
if errorlevel 1 (
    echo.
    echo  WSL غير متوفر. لبناء ISO تحتاج أحد الخيارات:
    echo    1. Arch Linux:  sudo bash build/build-iso.sh
    echo    2. تثبيت WSL ثم أعد تشغيل هذا الملف
    echo.
    echo  بديل بدون بناء ISO: استخدم install-hatan.bat ^(USB + Ventoy^)
    echo.
    pause
    exit /b 1
)

echo.
echo  Building HATAN OS ISO via WSL...
echo  قد يُطلب كلمة مرور Linux.
echo.

for /f "delims=" %%I in ('wsl wslpath -a "%CD%"') do set WSL_DIR=%%I
wsl bash -lc "cd '%WSL_DIR%' && sudo bash build/build-iso.sh"

echo.
pause
