@echo off
title HATAN OS - معاينة الواجهة
cd /d "%~dp0"

echo.
echo  ========================================
echo       HATAN OS - معاينة الواجهة
echo  ========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\sync-assets.ps1"
powershell -ExecutionPolicy Bypass -File "%~dp0preview.ps1"
