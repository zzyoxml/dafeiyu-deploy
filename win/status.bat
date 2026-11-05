@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Status
color 0B

echo ============================================
echo    DaFeiYu QQ Bot - Status
echo ============================================
echo.

wsl -d Ubuntu-24.04 -u root -- true >nul 2>&1
if errorlevel 1 goto nowsl

if exist "D:\xml\dafeiyu\logs\status-out.txt" del /q "D:\xml\dafeiyu\logs\status-out.txt"
wsl -d Ubuntu-24.04 -u root -- bash -lc "/root/status-bot.sh" > "D:\xml\dafeiyu\logs\status-out.txt" 2>&1
type "D:\xml\dafeiyu\logs\status-out.txt"
goto end

:nowsl
echo   *** WSL IS DOWN ***
echo   VirtualMachinePlatform / Hyper-V disabled.
echo   Fix: run fix-wsl-run.bat as Administrator, then reboot.

:end
echo.
echo ============================================
echo.
pause
