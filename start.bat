@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Start
color 0A

REM ===== Locate ourselves =====
REM %~dp0 is the folder of this .bat WITH a trailing backslash.
REM Using it means the project folder can be moved or renamed freely
REM and every sibling file is still found.
set "HERE=%~dp0"

echo ============================================
echo    DaFeiYu QQ Bot - Start
echo ============================================
echo    Dir: %HERE%
echo.

REM ===== Step 1: WSL pre-check =====
REM The original had no check. When WSL was broken the window vanished
REM instantly with no explanation. This makes the cause visible.
echo [Check] WSL availability...
wsl -d Ubuntu-24.04 -u root -- true >nul 2>&1
if errorlevel 1 goto nowsl
echo   WSL OK
echo.
goto runbot

:nowsl
echo.
echo   *** WSL CANNOT START ***
echo.
echo   VirtualMachinePlatform or Hyper-V is disabled.
echo   This is usually caused by an Android emulator
echo   (LeiDian / LDPlayer / MuMu / BlueStacks). They need
echo   exclusive virtualization and switch Hyper-V off.
echo.
echo   Fix: run "%HERE%fix-wsl-run.bat" as Administrator, then reboot.
echo.
goto end

:runbot
REM ===== Step 2: run the real start script inside WSL =====
REM /root/start-bot.sh does 5 things the .bat alone would miss:
REM   - verify docker
REM   - docker update --restart=always (critical: a manual stop sets it
REM     to "no", so containers would not come back after a restart)
REM   - start both containers
REM   - launch the anchor keepalive loop
REM   - poll the WebUI until ready
echo [Run] /root/start-bot.sh ...
echo.
wsl -d Ubuntu-24.04 -u root -- bash -lc "/root/start-bot.sh"
echo.

echo [Verify] AstrBot state...
wsl -d Ubuntu-24.04 -u root -- bash -lc "docker inspect astrbot --format '{{.State.Status}}' 2>/dev/null" > "%TEMP%\ab_st.txt" 2>&1
set /p AB_STATUS=<"%TEMP%\ab_st.txt"
if "%AB_STATUS%"=="running" goto abok
echo   *** AstrBot is NOT running (state: %AB_STATUS%) ***
echo   Run status.bat or check the logs.
echo.
goto end

:abok
echo   AstrBot: running
echo.

REM ===== Step 3: Windows-side guardian =====
REM The VBS locates itself, so nothing here needs to know the path.
echo [Guard] Starting Windows-side guardian...
if not exist "%HERE%guard-autostart.vbs" goto noguard
wscript.exe "%HERE%guard-autostart.vbs"
echo   guardian launched
echo.
goto banner

:noguard
echo   guard-autostart.vbs not found - skipped
echo.

:banner
echo ============================================
echo    BOT IS UP
echo      AstrBot : http://localhost:6185
echo      NapCat  : http://localhost:6099
echo ============================================

:end
echo.
pause
