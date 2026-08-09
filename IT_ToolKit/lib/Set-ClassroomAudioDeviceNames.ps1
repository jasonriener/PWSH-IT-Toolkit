<#
.SYNOPSIS
    Renames the selected audio output device to 'Classroom Speakers' and the
    selected audio input device to 'Classroom Microphone'.

.NOTES
    Must be run as Administrator - renames are written to HKLM in the registry.
#>

. "$PSScriptRoot\AudioDevice.Helpers.ps1"

function Select-AudioDevice {
    param([array]$Devices, [string]$DeviceType)
    Write-Host ""
    Write-Host "Available $DeviceType Devices:" -ForegroundColor Cyan
    foreach ($d in $Devices) {
        Write-Host "  [$($d.Index)] $($d.FriendlyName) ($($d.Description))"
    }
    Write-Host ""
    do {
        $userInput = Read-Host "Enter the number of the $DeviceType device"
        $selection = $userInput -as [int]
    } while (-not $selection -or $selection -lt 1 -or $selection -gt $Devices.Count)
    return $Devices[$selection - 1]
}

while ($true) {

# --- Enumerate devices ---
$outputDevices = Get-AudioDevices -RegistryPath $RenderPath
$inputDevices  = Get-AudioDevices -RegistryPath $CapturePath

if ($outputDevices.Count -eq 0) { Write-Host "No audio output devices found." -ForegroundColor Red; exit 1 }
if ($inputDevices.Count  -eq 0) { Write-Host "No audio input devices found."  -ForegroundColor Red; exit 1 }

# --- Prompt for selections ---
Write-Host ""
Write-Host "=== Classroom Audio Device Renamer ===" -ForegroundColor Magenta

$selectedOutput = Select-AudioDevice -Devices $outputDevices -DeviceType "Output (Speakers)"
$selectedInput  = Select-AudioDevice -Devices $inputDevices  -DeviceType "Input (Microphone)"

# --- Confirm ---
Write-Host ""
Write-Host "Pending Changes:" -ForegroundColor Yellow
Write-Host "  Output : '$($selectedOutput.FriendlyName)' --> 'Classroom Speakers'"
Write-Host "  Input  : '$($selectedInput.FriendlyName)' --> 'Classroom Microphone'"
Write-Host ""
$confirm = Read-Host "Apply these changes? (Y/N)"

if ($confirm -notmatch '^[Yy]$') {
    Write-Host "Cancelled." -ForegroundColor Blue
    exit 0
}

# --- Apply renames ---
$outputOk = Set-AudioDeviceFriendlyName -PropsPath $selectedOutput.PropsPath -NewName "Classroom Speakers"
$inputOk  = Set-AudioDeviceFriendlyName -PropsPath $selectedInput.PropsPath  -NewName "Classroom Microphone"

Write-Host ""
if ($outputOk) { Write-Host "Renamed '$($selectedOutput.FriendlyName)' --> 'Classroom Speakers'"  -ForegroundColor Green }
if ($inputOk)  { Write-Host "Renamed '$($selectedInput.FriendlyName)' --> 'Classroom Microphone'" -ForegroundColor Green }
if ($outputOk -and $inputOk) {
    Write-Host ""
    Write-Host "Done. A restart may be necessary for changes to be displayed." -ForegroundColor Green
}

    Write-Host ""
    $again = Read-Host "Run again? (Y/N)"
    if ($again -notmatch '^[Yy]$') { break }
}
