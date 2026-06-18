@echo off
title HATAN OS - Preview
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0preview.ps1"
if errorlevel 1 pause