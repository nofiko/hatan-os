@echo off
chcp 65001 >nul
title HATAN OS - رفع إلى GitHub
cd /d "%~dp0"

echo.
echo  ═══════════════════════════════════════
echo   HATAN OS — رفع المشروع لحساب nofiko
echo  ═══════════════════════════════════════
echo.

where gh >nul 2>&1
if errorlevel 1 (
    echo  جاري تثبيت GitHub CLI...
    winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
)

echo  الخطوة 1: تسجيل الدخول إلى GitHub
echo  — سيُفتح المتصفح أو يُعطيك كوداً للنسخ
echo.
gh auth status >nul 2>&1
if errorlevel 1 (
    gh auth login -h github.com -p https -w
    if errorlevel 1 (
        echo.
        echo  فشل تسجيل الدخول. أعد تشغيل الملف وحاول مرة أخرى.
        pause
        exit /b 1
    )
)

echo.
echo  الخطوة 2: إنشاء المستودع ورفع المشروع وبناء ISO...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-github.ps1" -Username "nofiko" -RepoName "hatan-os"

pause
