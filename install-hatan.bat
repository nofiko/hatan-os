@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title HATAN OS - Installer
cd /d "%~dp0"

:: Request admin (skip if already elevated)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  Requesting administrator privileges...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0.'"
    exit /b
)

echo.
echo  Starting HATAN OS installer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows-installer.ps1"
set "EXITCODE=%ERRORLEVEL%"

echo.
if not "%EXITCODE%"=="0" (
    echo  [Error] Installer exited with code %EXITCODE%
    echo  Log: %TEMP%\hatan-installer.log
) else (
    echo  Done.
)
echo.
pause
