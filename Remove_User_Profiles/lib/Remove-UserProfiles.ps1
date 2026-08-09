<#
.SYNOPSIS
    Removes all local user profiles under C:\Users except the one named "lewis"
    (and built-in system/service profiles, which are always skipped).

.DESCRIPTION
    Uses Win32_UserProfile (via Get-CimInstance) rather than just deleting folders,
    so the registry profile hive (HKEY_USERS\<SID>) and profile list entries are
    cleaned up properly instead of leaving orphaned/corrupt profile references.

.PARAMETER KeepName
    The username to preserve. Defaults to "lewis". Matching is case-insensitive
    and matches on the local profile folder name.

.PARAMETER WhatIf
    Built-in PowerShell switch. Run with -WhatIf first to see exactly what would
    be deleted without actually deleting anything.

.PARAMETER Force
    Skips the interactive confirmation prompt. Without -Force, the script lists
    what it intends to delete and asks you to type YES before proceeding.

.NOTES
    - Must be run elevated (as Administrator).
    - Always skips built-in/system profiles regardless of KeepName:
      Public, Default, Default User, All Users, systemprofile,
      LocalService, NetworkService.
    - Currently logged-on users cannot be removed while their session is
      active; the script will report and skip these rather than fail.
    - Log written to C:\Windows\Temp\RemoveUserProfiles.log
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$KeepName = "lewis",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$LogPath = "C:\Windows\Temp\RemoveUserProfiles.log"

# Track results for final summary
$RemovedProfiles = @()
$FailedProfiles = @()
$HadError = $false

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}

function Show-FinalSummary {
    Write-Host ""
    Write-Host "#########################" -ForegroundColor Magenta

    if ($RemovedProfiles.Count -gt 0) {
        Write-Host "# Removed $($RemovedProfiles.Count) Profile(s) Successfully" -ForegroundColor Green
        Write-Host "#########################" -ForegroundColor Magenta

        foreach ($prof in $RemovedProfiles) {
            Write-Host $prof -ForegroundColor White
        }

        if ($FailedProfiles.Count -gt 0) {
            Write-Host ""
            Write-Host "# $($FailedProfiles.Count) Profile(s) Failed to Remove - See Log" -ForegroundColor Red
            foreach ($prof in $FailedProfiles) {
                Write-Host $prof -ForegroundColor White
            }
        }
    }
    elseif ($FailedProfiles.Count -gt 0) {
        Write-Host "# $($FailedProfiles.Count) Profile(s) Failed to Remove - See Log" -ForegroundColor Red
        Write-Host "#########################" -ForegroundColor Magenta

        foreach ($prof in $FailedProfiles) {
            Write-Host $prof -ForegroundColor White
        }
    }
    elseif ($HadError) {
        Write-Host "# Completed With Errors - No Profiles Removed" -ForegroundColor Red
        Write-Host "#########################" -ForegroundColor Magenta
    }
    else {
        Write-Host "# No Profiles Found for Removal" -ForegroundColor Yellow
        Write-Host "#########################" -ForegroundColor Magenta
    }

    Write-Host ""
    Write-Host "Press any key to close..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try {

    # Require admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdmin) {
        throw "This script must be run as Administrator."
    }

    # Built-in/system profiles that should never be removed
    $AlwaysSkip = @(
        'Public',
        'Default',
        'Default User',
        'All Users',
        'systemprofile',
        'LocalService',
        'NetworkService'
    )

    Write-Log "=== Starting profile cleanup run. KeepName='$KeepName' Force=$Force WhatIf=$($WhatIfPreference) ==="

    $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object {
        $_.Special -eq $false -and
        $_.LocalPath -like "$env:SystemDrive\Users\*"
    }

    if (-not $profiles) {
        Write-Log "No candidate profiles found under $env:SystemDrive\Users."
    }
    else {

        $toDelete = @()

        foreach ($p in $profiles) {

            $folderName = Split-Path $p.LocalPath -Leaf

            if ($AlwaysSkip -contains $folderName) {
                Write-Log "SKIP (built-in): $folderName"
                continue
            }

            if ($folderName -ieq $KeepName) {
                Write-Log "SKIP (keep): $folderName"
                continue
            }

            if ($p.Loaded) {
                Write-Log "SKIP (currently logged on, cannot remove while loaded): $folderName"
                continue
            }

            $toDelete += [PSCustomObject]@{
                FolderName = $folderName
                LocalPath  = $p.LocalPath
                SID        = $p.SID
                Profile    = $p
            }
        }

        if ($toDelete.Count -eq 0) {
            Write-Log "Nothing to delete after filtering."
        }
        else {

            Write-Log "The following profiles are candidates for deletion:"
            $toDelete | ForEach-Object {
                Write-Log "  - $($_.FolderName) ($($_.LocalPath))"
            }

            $proceed = $true

            if (-not $Force -and -not $WhatIfPreference) {
                $ConfirmAnswers = @('YES', 'Y', 'A')
                Write-Host ""
                Write-Host "This will PERMANENTLY delete $($toDelete.Count) user profile(s) listed above." -ForegroundColor Yellow
                $answer = Read-Host "Type YES, Y, or A to continue"

                if ($ConfirmAnswers -notcontains $answer) {
                    Write-Log "User did not confirm. Aborting without changes."
                    $proceed = $false
                }
            }

            if ($proceed) {

                foreach ($item in $toDelete) {

                    if ($PSCmdlet.ShouldProcess($item.LocalPath, "Remove user profile")) {

                        try {
                            Remove-CimInstance -InputObject $item.Profile -ErrorAction Stop
                            Write-Log "REMOVED: $($item.FolderName)"
                            $RemovedProfiles += $item.FolderName
                        }
                        catch {
                            Write-Log "ERROR removing $($item.FolderName): $($_.Exception.Message)"
                            $FailedProfiles += $item.FolderName
                        }

                    }

                }

            }

        }

    }

    Write-Log "=== Cleanup run complete. ==="
}
catch {
    $HadError = $true
    Write-Host ""
    Write-Host "#########################" -ForegroundColor Red
    Write-Host "# ERROR" -ForegroundColor Red
    Write-Host "#########################" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
finally {
    Show-FinalSummary
}