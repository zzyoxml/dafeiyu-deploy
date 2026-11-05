@echo off
setlocal
set LOG=D:\xml\dafeiyu\logs\fix-wsl.log

echo ==== START %DATE% %TIME% ==== > "%LOG%"

net session >nul 2>&1
if errorlevel 1 (
    echo ADMIN_CHECK: FAILED - not elevated >> "%LOG%"
    exit /b 1
)
echo ADMIN_CHECK: OK >> "%LOG%"

echo. >> "%LOG%"
echo ---- kill emulator ---- >> "%LOG%"
taskkill /F /IM dnplayer.exe       >> "%LOG%" 2>&1
taskkill /F /IM LdVboxHeadless.exe >> "%LOG%" 2>&1
taskkill /F /IM LdVboxSVC.exe      >> "%LOG%" 2>&1
taskkill /F /IM LDPlayer.exe       >> "%LOG%" 2>&1
taskkill /F /IM LDMultiPlayer.exe  >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ---- DISM VirtualMachinePlatform ---- >> "%LOG%"
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >> "%LOG%" 2>&1
echo DISM1_EXIT=%errorlevel% >> "%LOG%"

echo. >> "%LOG%"
echo ---- DISM Microsoft-Windows-Subsystem-Linux ---- >> "%LOG%"
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >> "%LOG%" 2>&1
echo DISM2_EXIT=%errorlevel% >> "%LOG%"

echo. >> "%LOG%"
echo ---- DISM Microsoft-Hyper-V-Hypervisor ---- >> "%LOG%"
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V-Hypervisor /all /norestart >> "%LOG%" 2>&1
echo DISM3_EXIT=%errorlevel% >> "%LOG%"

echo. >> "%LOG%"
echo ---- bcdedit hypervisorlaunchtype auto ---- >> "%LOG%"
bcdedit /set hypervisorlaunchtype auto >> "%LOG%" 2>&1
echo BCD_EXIT=%errorlevel% >> "%LOG%"

echo. >> "%LOG%"
echo ---- bcdedit readback ---- >> "%LOG%"
bcdedit /enum "{current}" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ---- verify files ---- >> "%LOG%"
if exist "C:\Windows\System32\vmcompute.exe" (echo VMCOMPUTE: PRESENT >> "%LOG%") else (echo VMCOMPUTE: MISSING >> "%LOG%")

echo ==== END %DATE% %TIME% ==== >> "%LOG%"
exit /b 0
