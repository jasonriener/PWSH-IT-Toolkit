<#
.SYNOPSIS
    Reports the LCSC config stamp and Dell Command Update schedule from the
    registry. Read-only - makes no changes.

.NOTES
    No admin elevation required - only reads HKLM values.
#>

$configPath = "HKLM:\SOFTWARE\LCSC\DCUConfig"
$schedulePath = "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings\Schedule"

Write-Host "=== Config stamp ===" -ForegroundColor Magenta
if (Test-Path $configPath) {
    try {
        $cfg = Get-ItemProperty $configPath -Name ConfigVersion -ErrorAction Stop
        Write-Host ("ConfigVersion : {0}" -f $cfg.ConfigVersion) -ForegroundColor Green
    } catch {
        Write-Host "Key exists but 'ConfigVersion' value not found." -ForegroundColor Yellow
    }
} else {
    Write-Host "Path not found: $configPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== DCU schedule ===" -ForegroundColor Magenta
if (Test-Path $schedulePath) {
    try {
        $sched = Get-ItemProperty $schedulePath -ErrorAction Stop
        Write-Host ("ScheduleMode  : {0}" -f $sched.ScheduleMode) -ForegroundColor Green
        Write-Host ("Time          : {0}" -f $sched.Time) -ForegroundColor Green
    } catch {
        Write-Host "Key exists but could not be read: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Path not found: $schedulePath" -ForegroundColor Yellow
}
