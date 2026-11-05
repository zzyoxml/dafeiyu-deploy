' DaFeiYu QQ Bot - silent guardian launcher
'
' Design notes (2026-10-18):
'   1. bash -c "..." inside a VBS string needs care with quotes,
'      and a wrong quote can leave the guard dead without any visible
'      error, because wscript runs windowless.
'   2. sh.Run(cmd, 0, False) returns immediately, so bash keeps running
'      after wscript exits. Do NOT use WshShell.Exec or plain
'      "cmd start /b" - both tie the bash lifetime to the caller.
'      cmd /c start /b detaches it properly.
'
' Path handling:
'   This file locates itself via WScript.ScriptFullName, so the whole
'   project folder can be moved or renamed without editing anything.
'   The only external dependency is Git for Windows' bash.exe.
'
Option Explicit

Dim fso, sh, bashExe, scriptPath, here, p, cmdLine

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

' --- locate ourselves -------------------------------------------------
here = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = here & "\guard.sh"

' Git for Windows bash. Checked in order so a non-default install still works.
Dim candidates, i, found
candidates = Array( _
    "C:\Program Files\Git\bin\bash.exe", _
    "C:\Program Files (x86)\Git\bin\bash.exe", _
    sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\Git\bin\bash.exe") _
)
found = ""
For i = 0 To UBound(candidates)
    If fso.FileExists(candidates(i)) Then
        found = candidates(i)
        Exit For
    End If
Next
If found = "" Then WScript.Quit 1
bashExe = found

If Not fso.FileExists(scriptPath) Then WScript.Quit 1

' --- D:\...\guard.sh -> /d/.../guard.sh ------------------------------
' Git bash needs a POSIX path, not a Windows one.
p = Replace(scriptPath, "\", "/")
p = "/" & LCase(Left(p, 1)) & Mid(p, 3)

' --- detach and launch ------------------------------------------------
' cmd /c start /b "" "<bash>" "<script>"
cmdLine = "cmd /c start /b """" """ & bashExe & """ """ & p & """"

sh.CurrentDirectory = here
sh.Run cmdLine, 0, False

Set sh  = Nothing
Set fso = Nothing
