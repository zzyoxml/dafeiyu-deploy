@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Stop
color 0E

REM ===== Locate ourselves =====
REM %~dp0 is the folder of this .bat WITH a trailing backslash.
set "HERE=%~dp0"

echo ============================================
echo    DaFeiYu QQ Bot - Stop
echo ============================================
echo    Dir: %HERE%
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
echo   Fix: run "%HERE%fix-wsl-run.bat" as Administrator, then reboot.
echo.
goto end

:stopguard
REM ===== Step 2: kill Windows-side guards =====
REM The original used wmic, which Win11 24H2+ removed. Both lookups
REM failed silently, so guards survived while the script printed
REM "no wscript guard found". stop-guard.ps1 uses Get-CimInstance.
echo [1/3] Stopping Windows-side guards...
REM NOTE: deliberately no taskkill by window title here.
REM The guards run windowless (VBS + bash), so there is no such window
REM to kill - and a filter like "DaFeiYu*" would match this very
REM window and terminate the script halfway through.
if not exist "%HERE%stop-guard.ps1" goto noguardps
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%stop-guard.ps1"
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
