@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title HATAN OS - Boot from file (no ISO on USB)
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0.'"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$env:HATAN_BOOT_MODE='File'; & '%~dp0scripts\windows-installer.ps1'"
pause
