@echo off
chcp 65001 >nul

:: ── מצא AutoHotkey ────────────────────────────────────────────
set AHK=
if exist "%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe" set AHK=%LOCALAPPDATA%\Programs\AutoHotkey\v2\AutoHotkey64.exe
if not defined AHK if exist "%PROGRAMFILES%\AutoHotkey\v2\AutoHotkey64.exe"  set AHK=%PROGRAMFILES%\AutoHotkey\v2\AutoHotkey64.exe
if not defined AHK if exist "%PROGRAMFILES%\AutoHotkey\AutoHotkey64.exe"     set AHK=%PROGRAMFILES%\AutoHotkey\AutoHotkey64.exe

if not defined AHK (
    echo AutoHotkey v2 לא נמצא. הורד מ: https://www.autohotkey.com/
    pause & exit /b 1
)

:: ── סגור מופעים קודמים ────────────────────────────────────────
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
timeout /t 1 >nul

:: ── הפעל Watcher (ברקע לחלוטין, ללא חלון) ───────────────────
set WATCHER=%~dp0watcher.js
echo Set o = CreateObject("WScript.Shell") > "%TEMP%\cw_launch.vbs"
echo o.Run "node ""%WATCHER%""", 0, False >> "%TEMP%\cw_launch.vbs"
start "" wscript.exe "%TEMP%\cw_launch.vbs"

:: ── הפעל Widget ───────────────────────────────────────────────
start "" "%AHK%" "%~dp0claude_token_widget.ahk"

exit
