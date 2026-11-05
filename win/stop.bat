@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Stop
color 0E

echo ============================================
echo    DaFeiYu QQ Bot - Stop
echo ============================================
echo.

REM ===== Step 1: WSL pre-check =====
echo [Check] WSL availability...
wsl -d Ubuntu-24.04 -u root -- true >nul 2>&1
if errorlevel 1 goto nowsl
echo   WSL OK
echo.
goto stopguard

:nowsl
echo.
echo   *** WSL CANNOT START ***
echo   VirtualMachinePlatform / Hyper-V is disabled.
echo   Fix: run fix-wsl-run.bat as Administrator, then reboot.
echo.
goto end

:stopguard
REM ===== Step 2: kill Windows-side guards =====
REM The original used wmic, which Win11 24H2+ removed. Both lookups
REM failed silently, so guards survived while the script printed
REM "no wscript guard found". stop-guard.ps1 uses Get-CimInstance.
echo [1/3] Stopping Windows-side guards...
REM NOTE: no taskkill by window title here. The guards run windowless
REM (VBS + bash), so there is no such window to kill - and the filter
REM "DaFeiYu*" would match this very window and kill the script itself.
if not exist "D:\xml\dafeiyu\stop-guard.ps1" goto noguardps
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\xml\dafeiyu\stop-guard.ps1"
goto stopbot

:noguardps
echo   stop-guard.ps1 missing - guards may still be running

:stopbot
echo.
REM ===== Step 3: run the real stop script inside WSL =====
echo [2/3] Running /root/stop-bot.sh ...
echo.
wsl -d Ubuntu-24.04 -u root -- bash -lc "/root/stop-bot.sh"
echo.

echo [3/3] Verifying...
wsl -d Ubuntu-24.04 -u root -- bash -lc "docker ps --format '  {{.Names}} {{.Status}}' | grep -E 'astrbot|napcat' || echo '  no bot containers running'"
echo.
echo ============================================
echo    BOT IS STOPPED
echo    Run start.bat to bring it back.
echo ============================================

:end
echo.
pause
