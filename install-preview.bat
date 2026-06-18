@echo off
chcp 65001 >nul
title HATAN OS - Installer Preview
cd /d "%~dp0"

echo.
echo  ========================================
echo       HATAN OS - Installer Preview
echo  ========================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\sync-assets.ps1"
powershell -ExecutionPolicy Bypass -File "%~dp0install-preview.ps1"
pause
