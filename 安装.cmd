@echo off
chcp 65001 >nul
title UI First Dev Installer
echo.
echo ==========================================
echo    UI First Dev - one click installer
echo ==========================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install\install-machine.ps1"
echo.
echo (Press any key to close)
pause >nul
