@echo off
:: ---------------------------------------------------------------------------
:: LC State IT Toolkit launcher.
:: Launches lib\Menu.ps1 with Administrator privileges - required because
:: the toolkit's audio-rename options write to HKLM in the registry.
:: If not already elevated, relaunches itself via UAC prompt.
:: ---------------------------------------------------------------------------

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

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\Menu.ps1"
