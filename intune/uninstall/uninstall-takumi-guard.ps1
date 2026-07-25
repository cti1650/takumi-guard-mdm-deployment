<#
.SYNOPSIS
    Takumi Guard uninstall (revert npm / pip registry)
.DESCRIPTION
    Removes only the keys managed by install-takumi-guard.ps1 via
    "npm config delete" / "pip config unset"; other settings are preserved.
    Intended as the Win32 app uninstall command.
.NOTES
    Run as the logged-on user.
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

# First candidate that exists and actually runs; $null if none.
function Get-UsableCommand {
    param([string[]]$Candidates)
    foreach ($name in $Candidates) {
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            & $name --version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return $name }
        }
    }
}

# "key not set" errors are ignored; removing an absent key is already the goal.
function Reset-Config {
    param([string]$Command, [string[]]$ResetArgs, [string]$Label)
    if (-not $Command) { Write-Output "SKIP: $Label not usable"; return }
    & $Command @ResetArgs 2>&1 | Out-Null
    Write-Output "OK: $Label reverted"
}

try {
    Reset-Config (Get-UsableCommand npm) @("config", "delete", "registry") "npm"
    Reset-Config (Get-UsableCommand pip, pip3) @("config", "unset", "global.index-url") "pip"
    Write-Output "UNINSTALL SUCCESS"
    exit 0
}
catch {
    Write-Error "UNINSTALL ERROR: $_"
    exit 1
}
