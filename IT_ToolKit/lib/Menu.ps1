<#
.SYNOPSIS
    LC State IT Toolkit - main menu.

.NOTES
    Launched via '..\RUN.cmd', which elevates first since the
    toolkit's registry-writing options require Administrator rights.
#>

while ($true) {
    Clear-Host
    Write-Host "=== LC State IT Toolkit ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [1] Set Classroom Audio Devices" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [2] Rename Any Audio Device" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "Select an option"

    switch ($choice.ToUpper()) {
        '1' { & "$PSScriptRoot\Set-ClassroomAudioDeviceNames.ps1" }
        '2' { & "$PSScriptRoot\Set-AudioDeviceName.ps1" }
        'Q' { exit }
        default { Write-Host "Invalid selection, please try again." -ForegroundColor Red; Start-Sleep -Seconds 2 }
    }
}