# PWSH IT Toolkit

A library of Windows PowerShell and CMD scripts built by our IT infrastructure team for day-to-day campus IT support - diagnostics, automation for repetitive admin tasks, and one-click fixes for common issues. Public copy of a private working repo, kept fully functional (not a stripped-down showcase version).

References to my institution (LC State) and the specific vendor tools we run (Dell Command Update, Quest KACE) are left in place intentionally - none of it is sensitive (no credentials, hostnames, or internal endpoints), and it's a more honest picture of the actual problems this was built to solve than a genericized version would be.

## Requirements

- Windows PowerShell 5.1 and/or PowerShell 7 (`pwsh.exe`) - noted per tool below where it matters.
- Several tools self-elevate via a UAC prompt; you'll see a Windows elevation dialog when running them.

## Tools

| Tool | Description | Entry point | Elevation |
|---|---|---|---|
| `Check_DCU_Config` | Read-only registry diagnostic for the config stamp and Dell Command Update schedule | `Check_DCU_Config\RUN.cmd` | No |
| `DCU_Installer` | Installs .NET 8 Desktop Runtime + Dell Command Update | `DCU_Installer\RUN.cmd` | Yes (self-elevates) |
| `IT_ToolKit` | Interactive menu for renaming audio devices (generic or fixed classroom names) | `IT_ToolKit\RUN.cmd` | Yes (writes to HKLM) |
| `Remove_User_Profiles` | Removes local user profiles via CIM, keeps a named profile, supports `-WhatIf`/`-Force` | `Remove_User_Profiles\RUN.cmd` | Yes (self-elevates) |
| `Misc_Scripts` | Small one-off utilities with no supporting `.ps1` (a KACE inventory kick and an SFC/DISM repair helper) | Run each `.cmd` individually | Varies per script |

## Repo conventions

- One folder per tool, named `Title_Case_With_Underscores`.
- Each tool folder contains `RUN.cmd` (the entry point) and a `lib\` subfolder holding everything it depends on - `.ps1` scripts, helper modules, vendor binaries.
- `.ps1` files follow PowerShell's approved Verb-Noun PascalCase convention (e.g. `Set-AudioDeviceName.ps1`).
- Trivial one-off `.cmd` scripts with no `.ps1` companion live in `Misc_Scripts\` instead of getting a full tool folder.
- Vendor/third-party binaries are gitignored, not committed - see the relevant tool's own `README.md` for how to obtain them (e.g. `DCU_Installer\README.md`).

## Notes on what's *not* here

- No credentials, API keys, or internal network addresses appear anywhere in this repo.
- `Remove_User_Profiles` defaults to keeping a profile named `lewis` - that's a standing local account convention on our lab/classroom images, not a secret; override it with `-KeepName`.
