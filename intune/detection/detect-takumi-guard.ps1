<#
.SYNOPSIS
    Takumi Guard detection (Intune Remediation - Detection)
.DESCRIPTION
    Exit 0 = configured (no remediation) / Exit 1 = not configured.
    Checks via "npm config get" / "pip config get" only; config files are never
    read directly. A package manager that is absent or cannot run (e.g. a
    version-manager shim with no version set) is out of scope = compliant.
.NOTES
    Run as the logged-on user ("Run using logged-on credentials" = Yes).
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

# Fixed anonymous registries (compared with trailing slash removed)
$NpmRegistry = "https://npm.flatt.tech"
$PypiIndex   = "https://pypi.flatt.tech/simple"

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

# No usable command -> out of scope (true). Diagnostics use Write-Host because
# Write-Output would be captured into the assigned variable along with the
# boolean return value and corrupt the comparison.
function Test-Config {
    param([string]$Command, [string[]]$GetArgs, [string]$Expected, [string]$Label)
    if (-not $Command) { Write-Host "SKIP: $Label not usable"; return $true }
    $current = (& $Command @GetArgs 2>$null | Out-String).Trim().TrimEnd('/')
    Write-Host "${Label}: $current"
    return ($current -eq $Expected)
}

try {
    $npmOk = Test-Config (Get-UsableCommand npm) @("config", "get", "registry") $NpmRegistry "npm"
    $pipOk = Test-Config (Get-UsableCommand pip, pip3) @("config", "get", "global.index-url") $PypiIndex "pip"

    if ($npmOk -and $pipOk) { Write-Output "COMPLIANT"; exit 0 }
    Write-Output "NON-COMPLIANT"; exit 1
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
