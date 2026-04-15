' Claude Context Widget Launcher
' מפעיל את ה-watcher וה-widget בשקט, ללא חלון שחור
' ממוקם ב-Startup — מריץ אחד פעם עם Windows

Dim scriptDir
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))

Dim shell
Set shell = CreateObject("WScript.Shell")

' הפעל watcher ברקע
shell.Run "node """ & scriptDir & "watcher.js""", 0, False

' המתן רגע קצר ואז הפעל widget
WScript.Sleep 800

' מצא AutoHotkey v2
Dim ahkPath
Dim fs
Set fs = CreateObject("Scripting.FileSystemObject")

Dim candidates(3)
candidates(0) = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Programs\AutoHotkey\v2\AutoHotkey64.exe"
candidates(1) = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Programs\AutoHotkey\v2\AutoHotkey32.exe"
candidates(2) = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
candidates(3) = "C:\Program Files\AutoHotkey\AutoHotkey64.exe"

Dim i
For i = 0 To 3
    If fs.FileExists(candidates(i)) Then
        ahkPath = candidates(i)
        Exit For
    End If
Next

If ahkPath = "" Then
    MsgBox "AutoHotkey v2 לא נמצא." & Chr(13) & "הורד מ: https://www.autohotkey.com/", 16, "Claude Widget"
    WScript.Quit
End If

shell.Run """" & ahkPath & """ """ & scriptDir & "claude_token_widget.ahk""", 0, False
