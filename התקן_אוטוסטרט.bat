@echo off
chcp 65001 >nul

set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set SHORTCUT=%STARTUP%\Claude Context Widget.lnk
set VBS=%~dp0launcher.vbs

:: צור קיצור דרך ב-Startup
powershell -NoProfile -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%SHORTCUT%');$s.TargetPath='%VBS%';$s.WorkingDirectory='%~dp0';$s.Save()"

if exist "%SHORTCUT%" (
    echo [✓] הווידג'ט יופעל אוטומטית עם Claude מעכשיו.
    echo     קיצור דרך נוצר ב: %SHORTCUT%
) else (
    echo [!] שגיאה ביצירת קיצור הדרך.
)
echo.
pause
