@echo off
chcp 65001 >nul 2>&1
setlocal
title Restore WSL2 - Administrator Required
color 0E

REM ===== 自动检测管理员权限 =====
net session >nul 2>&1
if errorlevel 1 (
    echo ============================================
    echo    ERROR: NOT RUNNING AS ADMINISTRATOR
    echo ============================================
    echo.
    echo   This script must run elevated because DISM
    echo   modifies system features.
    echo.
    echo   Right-click this file and choose:
    echo       "Run as administrator"
    echo.
    echo ============================================
    pause
    exit /b 1
)

echo ============================================
echo    Restoring WSL2 / Hyper-V
echo    (Administrator: OK)
echo ============================================
echo.

REM ===== 取消 emulator 造成的冲突 =====
echo [1/5] Stopping emulator processes that block virtualization...
taskkill /F /IM dnplayer.exe      >nul 2>&1
taskkill /F /IM LdVboxHeadless.exe >nul 2>&1
taskkill /F /IM LdVboxSVC.exe      >nul 2>&1
taskkill /F /IM LDPlayer.exe       >nul 2>&1
echo   done
echo.

echo [2/5] Enabling VirtualMachinePlatform...
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
echo.

echo [3/5] Enabling Microsoft-Windows-Subsystem-Linux...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
echo.

echo [4/5] Enabling Hyper-V hypervisor...
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-Hypervisor /all /norestart
echo.

echo [5/5] Setting hypervisor launch type to auto...
bcdedit /set hypervisorlaunchtype auto
echo.

echo ============================================
echo    Verify (may still show missing until reboot)
echo ============================================
if exist "C:\Windows\System32\vmcompute.exe" (
    echo   vmcompute.exe: OK
) else (
    echo   vmcompute.exe: still missing - will appear after reboot
)
echo.
echo ============================================
echo    ALL DONE. Now RESTART Windows.
echo.
echo    After restart, run start.bat
echo ============================================
echo.
echo Press any key to close...
pause >nul
