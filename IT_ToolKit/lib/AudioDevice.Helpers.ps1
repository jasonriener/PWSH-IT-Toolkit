<#
.SYNOPSIS
    Shared helpers for enumerating and renaming Windows audio input/output
    devices via their MMDevices registry entries.

.NOTES
    Dot-source this file from a script that needs it:
        . "$PSScriptRoot\AudioDevice.Helpers.ps1"
    Must run elevated - the registry keys involved are under HKLM.
#>

$PropKey     = "{a45c254e-df1c-4efd-8020-67d146a850e0},2"
$DescKey     = "{b3f8fa53-0004-438e-9003-51a46e139bfc},6"
$RenderPath  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
$CapturePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture"

function Get-AudioDevices {
    param(
        [Parameter(Mandatory)] [string]$RegistryPath,
        [string]$Type
    )
    $devices = @()
    foreach ($guid in Get-ChildItem $RegistryPath) {
        $propsPath    = Join-Path $guid.PSPath "Properties"
        $friendlyName = (Get-ItemProperty -Path $propsPath -Name $PropKey -ErrorAction SilentlyContinue).$PropKey
        $description  = (Get-ItemProperty -Path $propsPath -Name $DescKey -ErrorAction SilentlyContinue).$DescKey
        if ($friendlyName) {
            $devices += [PSCustomObject]@{
                Index        = $devices.Count + 1
                Type         = $Type
                FriendlyName = $friendlyName
                Description  = $description
                PropsPath    = $propsPath
            }
        }
    }
    return $devices
}

function Convert-ToWScriptPath {
    param([Parameter(Mandatory)] [string]$PSPath)
    $PSPath -replace 'Microsoft\.PowerShell\.Core\\Registry::HKEY_LOCAL_MACHINE', 'HKLM'
}

function Set-AudioDeviceFriendlyName {
    param(
        [Parameter(Mandatory)] [string]$PropsPath,
        [Parameter(Mandatory)] [string]$NewName
    )
    $wsh   = New-Object -ComObject WScript.Shell
    $wPath = (Convert-ToWScriptPath -PSPath $PropsPath) + "\$PropKey"
    try {
        $wsh.RegWrite($wPath, $NewName, "REG_SZ")
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "  [FAIL] Could not rename device: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "         Make sure this window is running as Administrator." -ForegroundColor Red
        return $false
    }
}
