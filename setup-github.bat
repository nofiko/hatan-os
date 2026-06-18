@echo off
title HATAN OS - GitHub Setup
cd /d "%~dp0.."

if "%~1"=="" (
    echo.
    echo  Usage: setup-github.bat YOUR_GITHUB_USERNAME
    echo.
    echo  Example: setup-github.bat myusername
    echo.
    set /p GHUSER="GitHub username: "
) else (
    set GHUSER=%~1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-github.ps1" -Username "%GHUSER%"
pause
