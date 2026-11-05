@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Start
color 0A

echo ============================================
echo    DaFeiYu QQ Bot - Start
echo ============================================
echo.

REM ===== Step 1: WSL pre-check =====
REM The original script had no check. When WSL was broken the window
REM vanished instantly with no explanation. This makes the cause visible.
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
echo   Fix: run fix-wsl-run.bat as Administrator, then reboot.
echo.
goto end

:runbot
REM ===== Step 2: run the real start script inside WSL =====
REM /root/start-bot.sh does 5 things the .bat alone would miss:
REM   - verify docker
REM   - docker update --restart=always (critical: after a manual stop
REM     the policy is set to no, so containers would not come back)
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
echo   Check logs\ or run status.bat
echo.
goto end

:abok
echo   AstrBot: running
echo.

REM ===== Step 3: Windows-side guardian =====
echo [Guard] Starting Windows-side guardian...
if not exist "D:\xml\dafeiyu\guard-autostart.vbs" goto noguard
wscript.exe "D:\xml\dafeiyu\guard-autostart.vbs"
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
