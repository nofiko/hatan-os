@echo off
title HATAN OS - GitHub Setup
cd /d "%~dp0"

if "%~1"=="" set GHUSER=nofiko
if not "%~1"=="" set GHUSER=%~1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-github.ps1" -Username "%GHUSER%"
pause
