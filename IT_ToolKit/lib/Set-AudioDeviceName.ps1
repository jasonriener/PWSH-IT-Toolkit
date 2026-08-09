<#
.SYNOPSIS
    Enumerates all input and output audio devices and renames the selected one.

.NOTES
    Must be run as Administrator - renames are written to HKLM in the registry.
#>

. "$PSScriptRoot\AudioDevice.Helpers.ps1"

while ($true) {

# --- Enumerate all devices ---
$allDevices = @()
$allDevices += Get-AudioDevices -RegistryPath $RenderPath  -Type "Output"
$allDevices += Get-AudioDevices -RegistryPath $CapturePath -Type "Input"

if ($allDevices.Count -eq 0) {
    Write-Host "No audio devices found." -ForegroundColor Red
    exit 1
}

# Assign indexes across the combined list
for ($i = 0; $i -lt $allDevices.Count; $i++) {
    $allDevices[$i].Index = $i + 1
}

# --- Display combined device list ---
Write-Host ""
Write-Host "=== Rename Audio Device ===" -ForegroundColor Magenta
Write-Host ""
Write-Host "Available Audio Devices:" -ForegroundColor Cyan
foreach ($d in $allDevices) {
    Write-Host "  [$($d.Index)] [$($d.Type)] $($d.FriendlyName) ($($d.Description))"
}
Write-Host ""

# --- Prompt for selection ---
do {
    $userInput = Read-Host "Enter the number of the device to rename"
    $selection = $userInput -as [int]
} while (-not $selection -or $selection -lt 1 -or $selection -gt $allDevices.Count)

$selected = $allDevices[$selection - 1]

# --- Prompt for new name ---
Write-Host ""
do {
    $newName = Read-Host "Enter new name for '$($selected.FriendlyName)'"
} while ([string]::IsNullOrWhiteSpace($newName))

# --- Confirm ---
Write-Host ""
Write-Host "Pending Change:" -ForegroundColor Yellow
Write-Host "  '$($selected.FriendlyName)' --> '$newName'"
Write-Host ""
$confirm = Read-Host "Apply this change? (Y/N)"

if ($confirm -notmatch '^[Yy]$') {
    Write-Host "Cancelled." -ForegroundColor Blue
    exit 0
}

# --- Apply rename ---
if (Set-AudioDeviceFriendlyName -PropsPath $selected.PropsPath -NewName $newName) {
    Write-Host ""
    Write-Host "Renamed '$($selected.FriendlyName)' --> '$newName'" -ForegroundColor Green
    Write-Host ""
    Write-Host "Done. A restart may be necessary for changes to be displayed." -ForegroundColor Green
}

    Write-Host ""
    $again = Read-Host "Run again? (Y/N)"
    if ($again -notmatch '^[Yy]$') { break }
}
