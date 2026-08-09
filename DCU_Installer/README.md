# DCU_Installer

Installs .NET Desktop Runtime 8.0.28 and Dell Command Update, then reports a summary. Does not check for or install Windows updates.

## Usage

Run `RUN.cmd` (self-elevates via UAC if not already running as Administrator).

## Vendor binaries (not tracked in git)

This tool depends on two third-party installer executables that must be placed in `lib/` before running. They are intentionally excluded from git (see root `.gitignore`) to keep the repo lightweight and avoid redistributing vendor installers:

| File | Source |
|---|---|
| `lib/dotnet-desktop-8.0.28-Win-x64.exe` | Microsoft .NET downloads page (get the ".NET Desktop Runtime 8.0.28" x64 installer) |
| `lib/dell-command-update-installer.exe` | Dell support site (Dell Command \| Update installer) |

If the installed versions change, update `$RequiredVersion` near the top of `lib/DCU_Installer.ps1` to match.
