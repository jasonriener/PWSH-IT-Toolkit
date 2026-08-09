@echo off
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    if errorlevel 1 (
        echo.
        echo [ERROR] Elevation request failed or was cancelled.
        pause
    )
    exit /b
)

cd C:\
sfc /scannow
dism /online /cleanup-image /restorehealth
pause