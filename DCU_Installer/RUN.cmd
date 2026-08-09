@echo off
:: ---------------------------------------------------------------------------
:: Launches lib\DCU_Installer.ps1 with Administrator privileges.
:: The script installs .NET Desktop Runtime 8 and Dell Command Update.
:: If not already elevated, relaunches itself via UAC prompt.
:: Expected layout:
::   DCU_Installer\RUN.cmd
::   DCU_Installer\lib\DCU_Installer.ps1
::   DCU_Installer\lib\dotnet-desktop-8.0.28-Win-x64.exe
::   DCU_Installer\lib\dell-command-update-installer.exe
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

set "SCRIPT_DIR=%~dp0"
set "PS1_PATH=%SCRIPT_DIR%lib\DCU_Installer.ps1"

if not exist "%PS1_PATH%" (
    echo [ERROR] Could not find: %PS1_PATH%
    pause
    exit /b 1
)

echo Launching DCU_Installer.ps1 with admin privileges...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1_PATH%"

echo.
echo Script finished. Press any key to close this window.
pause >nul