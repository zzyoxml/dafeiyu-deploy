# stop-guard.ps1 - stop Windows-side guard processes
#
# Why this file exists:
#   The original stop.bat used wmic, but Win11 24H2+ removed wmic.exe.
#   Both lookup commands failed silently, so guards were never killed
#   yet the script printed "no wscript guard found".
#
# Why a separate file rather than inline in .bat:
#   Nesting PowerShell inside .bat needs ^ escaping and breaks easily.

$killed = 0

$ws = @(Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*guard-autostart*' })
foreach ($p in $ws) {
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        Write-Host ("  killed wscript  PID={0}" -f $p.ProcessId)
        $killed = $killed + 1
    } catch {
        Write-Host ("  FAILED wscript PID={0}: {1}" -f $p.ProcessId, $_.Exception.Message)
    }
}

$bs = @(Get-CimInstance Win32_Process -Filter "Name='bash.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*guard.sh*' })
foreach ($p in $bs) {
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
        Write-Host ("  killed bash     PID={0}" -f $p.ProcessId)
        $killed = $killed + 1
    } catch {
        Write-Host ("  FAILED bash PID={0}: {1}" -f $p.ProcessId, $_.Exception.Message)
    }
}

if ($killed -eq 0) { Write-Host "  no guard process found" }
else { Write-Host ("  total killed: {0}" -f $killed) }
exit 0
