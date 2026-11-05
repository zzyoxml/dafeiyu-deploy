@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Status
color 0B

REM %~dp0 is the folder of this .bat WITH a trailing backslash.
set "HERE=%~dp0"

echo ============================================
echo    DaFeiYu QQ Bot - Status
echo ============================================
echo    Dir: %HERE%
echo.

wsl -d Ubuntu-24.04 -u root -- true >nul 2>&1
if errorlevel 1 goto nowsl

REM Capture to a file first, then type it. Piping wsl.exe output straight
REM through means a failed or stalled call shows nothing at all.
if not exist "%HERE%logs" mkdir "%HERE%logs" >nul 2>&1
set "OUT=%HERE%logs\status-out.txt"
wsl -d Ubuntu-24.04 -u root -- bash -lc "/root/status-bot.sh" > "%OUT%" 2>&1
type "%OUT%"
goto end

:nowsl
echo   *** WSL IS DOWN ***
echo   VirtualMachinePlatform / Hyper-V disabled.
echo   This is commonly caused by an Android emulator (LDPlayer etc.)
echo   that needs exclusive virtualization and switched Hyper-V off.
echo   Fix: run "%HERE%fix-wsl-run.bat" as Administrator, then reboot.

:end
echo.
echo ============================================
echo.
pause
