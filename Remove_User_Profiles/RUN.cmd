@echo off
:: ---------------------------------------------------------------------------
:: Launches removeUserProfiles.ps1 with Administrator privileges via UAC.
:: The script permanently deletes local user profiles under C:\Users, except
:: the one named "lewis" (see -KeepName) and built-in/system profiles.
:: It prompts for confirmation before deleting anything unless run with -Force.
:: Expected layout:
::   Remove_User_Profiles\RUN.cmd
::   Remove_User_Profiles\lib\Remove-UserProfiles.ps1
:: ---------------------------------------------------------------------------
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"try { Start-Process PowerShell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0lib\Remove-UserProfiles.ps1""' -ErrorAction Stop } catch { Write-Host ''; Write-Host 'Elevation was cancelled or failed:' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Yellow; Write-Host ''; Write-Host 'Press any key to close...' -ForegroundColor Gray; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') }"