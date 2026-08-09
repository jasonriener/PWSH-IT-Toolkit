@echo off
:: ---------------------------------------------------------------------------
:: Launches lib\Check-DCUConfig.ps1, a read-only diagnostic that reports
:: the LCSC config stamp and Dell Command Update schedule from the registry.
:: No admin elevation needed - it only reads HKLM values.
:: Prefers PowerShell 7 (pwsh.exe) if present, falling back to Windows
:: PowerShell 5.1 (powershell.exe) otherwise.
:: Expected layout:
::   Check_DCU_Config\RUN.cmd
::   Check_DCU_Config\lib\Check-DCUConfig.ps1
:: ---------------------------------------------------------------------------
where pwsh.exe >nul 2>nul
if %errorlevel%==0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\Check-DCUConfig.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lib\Check-DCUConfig.ps1"
)
pause
