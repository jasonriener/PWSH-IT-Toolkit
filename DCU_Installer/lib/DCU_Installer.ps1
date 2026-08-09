<#
.SYNOPSIS
    Checks for and installs .NET Desktop Runtime 8.0.28 and Dell Command Update,
    then reports a summary. Does not check for or install Windows updates.

.NOTES
    Compatible with Windows PowerShell 5.1.
    Must be run as Administrator (installers require elevation).
    Expected location: DCU_Installer\lib\DCU_Installer.ps1
#>

# ---------------------------------------------------------------------------
# CONFIG - edit these if the installers are not in the same folder as this script
# ---------------------------------------------------------------------------
$DotNetInstallerPath = Join-Path $PSScriptRoot "dotnet-desktop-8.0.28-Win-x64.exe"
$DcuInstallerPath     = Join-Path $PSScriptRoot "dell-command-update-installer.exe"
$RequiredRuntimeName  = "Microsoft.WindowsDesktop.App"
$RequiredVersion      = "8.0.28"
$SuccessExitCodes     = @(0, 3010)   # 3010 = ERROR_SUCCESS_REBOOT_REQUIRED

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
$Script:StepNumber = 0
$Script:StepTotal  = 3

function Write-Banner {
    param([string]$Text)
    $line = "=" * 63
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    $Script:StepNumber++
    Write-Host ""
    Write-Host "[Step $($Script:StepNumber)/$Script:StepTotal] $Text" -ForegroundColor Cyan
    Write-Host ("-" * 63) -ForegroundColor DarkCyan
}

function Write-Ok   { param([string]$Text) Write-Host "  [OK]   $Text" -ForegroundColor Green }
function Write-Info { param([string]$Text) Write-Host "  [INFO] $Text" -ForegroundColor Yellow }
function Write-Warn { param([string]$Text) Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
function Write-Err  { param([string]$Text) Write-Host "  [FAIL] $Text" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Function: run an installer, showing a live spinner + elapsed time while it runs
# ---------------------------------------------------------------------------
function Invoke-InstallerWithProgress {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [string[]]$ArgumentList,
        [Parameter(Mandatory)] [string]$Activity
    )

    $startArgs = @{ FilePath = $Path; PassThru = $true }
    if ($ArgumentList) { $startArgs["ArgumentList"] = $ArgumentList }

    try {
        $proc = Start-Process @startArgs
    }
    catch {
        Write-Err "Failed to launch '$Path': $($_.Exception.Message)"
        return $null
    }

    $spinnerFrames = @('|', '/', '-', '\')
    $frame = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while (-not $proc.HasExited) {
        $elapsed = [int]$stopwatch.Elapsed.TotalSeconds
        Write-Progress -Activity $Activity -Status "$($spinnerFrames[$frame % $spinnerFrames.Length])  elapsed: ${elapsed}s"
        $frame++
        Start-Sleep -Milliseconds 250
    }

    Write-Progress -Activity $Activity -Completed
    $proc.WaitForExit()
    return $proc.ExitCode
}

# ---------------------------------------------------------------------------
# Function: check if a specific .NET Desktop Runtime version is installed
# ---------------------------------------------------------------------------
function Test-DotNetDesktopRuntime {
    param([string]$Version)

    # Primary check: look directly in the shared-framework folder. This doesn't
    # depend on the current process's PATH, which can be stale immediately after
    # a fresh install (PATH is only refreshed for new processes/sessions).
    $sharedFrameworkDirs = @(
        (Join-Path $env:ProgramFiles "dotnet\shared\$RequiredRuntimeName")
    )
    if (${env:ProgramFiles(x86)}) {
        $sharedFrameworkDirs += (Join-Path ${env:ProgramFiles(x86)} "dotnet\shared\$RequiredRuntimeName")
    }

    foreach ($dir in $sharedFrameworkDirs) {
        if (Test-Path (Join-Path $dir $Version)) {
            return $true
        }
    }

    # Fallback: ask dotnet.exe directly, in case of a non-default install location.
    $dotnetCmd = Get-Command dotnet.exe -ErrorAction SilentlyContinue
    if (-not $dotnetCmd) {
        return $false
    }

    $runtimeLines = & dotnet --list-runtimes 2>$null
    if (-not $runtimeLines) {
        return $false
    }

    # Anchored match on runtime name + exact version field, so e.g. required "8.0.2"
    # can never match an installed "8.0.20" (a bare substring match could).
    $pattern = "^$([regex]::Escape($RequiredRuntimeName))\s+$([regex]::Escape($Version))\s"
    foreach ($line in $runtimeLines) {
        if ($line -match $pattern) {
            return $true
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Function: find installed Dell Command Update entries via the registry
# ---------------------------------------------------------------------------
function Get-InstalledDellCommandUpdate {
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Dell Command*Update*" } |
        Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString, PSChildName
}

# ---------------------------------------------------------------------------
# Function: split a recorded "UninstallString"-style command line into
# its executable path and argument string
# ---------------------------------------------------------------------------
function Split-InstallerCommandLine {
    param([Parameter(Mandatory)] [string]$CommandLine)

    if ($CommandLine -match '^\s*"([^"]+)"\s*(.*)$') {
        return @{ Path = $Matches[1]; Arguments = $Matches[2].Trim() }
    }
    if ($CommandLine -match '^\s*(\S+)\s*(.*)$') {
        return @{ Path = $Matches[1]; Arguments = $Matches[2].Trim() }
    }
    return @{ Path = $CommandLine; Arguments = "" }
}

# ---------------------------------------------------------------------------
# Function: silently uninstall one Dell Command Update registry entry
# ---------------------------------------------------------------------------
function Uninstall-DellCommandUpdateEntry {
    param([Parameter(Mandatory)] $Entry)

    Write-Info "Removing '$($Entry.DisplayName)' ($($Entry.DisplayVersion))..."

    # Dell Command Update is packaged as an MSI product under the hood, even though
    # the installer you double-click is an InstallShield/Burn front end. Whenever we
    # can find the MSI product code, drive msiexec ourselves with known-good silent
    # switches rather than guessing at the front end's own silent-uninstall flags.
    $guidMatch = [regex]::Match("$($Entry.UninstallString) $($Entry.PSChildName)", '\{[0-9A-Fa-f\-]{36}\}')

    if ($guidMatch.Success) {
        return Invoke-InstallerWithProgress -Path "$env:WINDIR\System32\msiexec.exe" `
            -ArgumentList @("/x", $guidMatch.Value, "/qn", "/norestart") `
            -Activity "Uninstalling $($Entry.DisplayName)"
    }

    if ($Entry.QuietUninstallString) {
        $parts = Split-InstallerCommandLine -CommandLine $Entry.QuietUninstallString
        return Invoke-InstallerWithProgress -Path $parts.Path -ArgumentList @($parts.Arguments) -Activity "Uninstalling $($Entry.DisplayName)"
    }

    Write-Warn "No silent uninstall command is recorded for '$($Entry.DisplayName)'. Skipping automatic removal - you may need to remove it manually from 'Apps & features'."
    return $null
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Banner ".NET Desktop Runtime + Dell Command Update Setup"

# Admin check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "This script must be run as Administrator. Right-click PowerShell and choose 'Run as Administrator'."
    exit 1
}

# Step 1: Check / install .NET Desktop Runtime
Write-Step ".NET Desktop Runtime $RequiredVersion"

if (Test-DotNetDesktopRuntime -Version $RequiredVersion) {
    Write-Ok ".NET Desktop Runtime $RequiredVersion is already installed."
    $dotnetStatus = "Already installed"
}
else {
    Write-Info ".NET Desktop Runtime $RequiredVersion was not found."

    if (-not (Test-Path $DotNetInstallerPath)) {
        Write-Err "Installer not found at: $DotNetInstallerPath"
        exit 1
    }

    Write-Info "Installing .NET Desktop Runtime $RequiredVersion..."
    $exitCode = Invoke-InstallerWithProgress -Path $DotNetInstallerPath `
        -ArgumentList @("/install", "/quiet", "/norestart") `
        -Activity "Installing .NET Desktop Runtime $RequiredVersion"

    if ($null -eq $exitCode) {
        exit 1
    }
    elseif ($exitCode -eq 3010) {
        Write-Warn ".NET Desktop Runtime installed, but a reboot is required to finish setup."
        $dotnetStatus = "Installed (reboot required)"
    }
    elseif ($SuccessExitCodes -contains $exitCode) {
        Write-Ok ".NET Desktop Runtime installed successfully."
        $dotnetStatus = "Installed"
    }
    else {
        Write-Err ".NET installer exited with code $exitCode."
        exit 1
    }

    # Re-check to confirm
    if (Test-DotNetDesktopRuntime -Version $RequiredVersion) {
        Write-Ok "Confirmed: .NET Desktop Runtime $RequiredVersion is now present."
    }
    else {
        Write-Warn "Install reported success, but the runtime still isn't detected. You may need to open a new PowerShell window (PATH refresh) or check manually."
    }
}

# Step 2: Remove any existing Dell Command Update installation(s)
Write-Step "Remove existing Dell Command Update installation(s)"

$existingDcu = @(Get-InstalledDellCommandUpdate)

if ($existingDcu.Count -eq 0) {
    Write-Ok "No existing Dell Command Update installation found."
    $dcuRemovalStatus = "None found"
}
else {
    $removalFailed = $false
    foreach ($entry in $existingDcu) {
        $exitCode = Uninstall-DellCommandUpdateEntry -Entry $entry
        if ($null -eq $exitCode) {
            $removalFailed = $true
        }
        elseif ($SuccessExitCodes -contains $exitCode) {
            Write-Ok "Removed '$($entry.DisplayName)' ($($entry.DisplayVersion))."
        }
        else {
            Write-Warn "Uninstaller for '$($entry.DisplayName)' exited with code $exitCode."
            $removalFailed = $true
        }
    }

    # Re-check to confirm
    if (@(Get-InstalledDellCommandUpdate).Count -eq 0) {
        Write-Ok "Confirmed: no Dell Command Update installation remains."
        $dcuRemovalStatus = "Removed $($existingDcu.Count) prior install(s)"
    }
    else {
        Write-Warn "At least one Dell Command Update installation still appears to be present."
        $dcuRemovalStatus = "Removal incomplete - check 'Apps & features' manually"
    }

    if ($removalFailed) {
        Write-Warn "Continuing to install the bundled version anyway - its installer may handle the upgrade itself."
    }
}

# Step 3: Run Dell Command Update installer
Write-Step "Install Dell Command Update"

if (-not (Test-Path $DcuInstallerPath)) {
    Write-Err "Dell Command Update installer not found at: $DcuInstallerPath"
    exit 1
}

# NOTE: Running interactively so you see its own install UI/confirmation.
# If you want silent install instead, check its supported switches first with:
#   & "$DcuInstallerPath" /?
# Common InstallShield-based silent switch is /s, but confirm before relying on it.
Write-Info "Launching Dell Command Update installer (its window may prompt you for input)..."
$dcuExitCode = Invoke-InstallerWithProgress -Path $DcuInstallerPath -Activity "Running Dell Command Update installer"

if ($null -eq $dcuExitCode) {
    exit 1
}

Write-Ok "Dell Command Update installer finished with exit code $dcuExitCode."
$dcuStatus = "Finished (exit code $dcuExitCode)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Banner "SUMMARY"
Write-Host "  .NET Desktop Runtime $RequiredVersion : $dotnetStatus"
Write-Host "  Dell Command Update removal   : $dcuRemovalStatus"
Write-Host "  Dell Command Update install   : $dcuStatus"
Write-Host ("=" * 63) -ForegroundColor Cyan
Write-Host ""
