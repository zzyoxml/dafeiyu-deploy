@echo off
chcp 65001 >nul 2>&1
setlocal
title DaFeiYu QQ Bot - Live Log

REM %~dp0 is the folder of this .bat WITH a trailing backslash.
set "HERE=%~dp0"

echo ============================================
echo    DaFeiYu QQ Bot - Live Conversation Log
echo    [A] = AstrBot   [Q] = QQ
echo    Close the window or press Ctrl+C to exit
echo ============================================
echo.
wsl -d Ubuntu-24.04 -u root -- bash /root/live-log.sh
echo.
echo Log ended.
pause >nul
