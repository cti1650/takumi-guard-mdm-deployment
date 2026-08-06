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

# Per-package-manager state: "ok" (configured) / "needs" (not configured) /
# "skip" (not usable = out of scope). Diagnostics use Write-Host because
# Write-Output would be captured into the assigned variable along with the
# return value and corrupt the comparison.
function Get-ConfigState {
    param([string]$Command, [string[]]$GetArgs, [string]$Expected, [string]$Label)
    if (-not $Command) { return "skip" }
    $current = (& $Command @GetArgs 2>$null | Out-String).Trim().TrimEnd('/')
    Write-Host "${Label}: $current"
    if ($current -eq $Expected) { return "ok" } else { return "needs" }
}

try {
    $npm = Get-ConfigState (Get-UsableCommand npm) @("config", "get", "registry") $NpmRegistry "npm"
    $pip = Get-ConfigState (Get-UsableCommand pip, pip3) @("config", "get", "global.index-url") $PypiIndex "pip"

    # Verdict line carries the same status vocabulary as the Jamf extension
    # attribute, so skips ("out of scope = compliant") are visible at a glance.
    $needs = @()
    if ($npm -eq "needs") { $needs += "npm" }
    if ($pip -eq "needs") { $needs += "pip" }
    $status = if ($needs.Count) { "Not Configured ($($needs -join ', '))" }
        elseif ($npm -eq "ok" -and $pip -eq "ok") { "Configured" }
        elseif ($npm -eq "ok") { "Configured (npm only; pip not usable)" }
        elseif ($pip -eq "ok") { "Configured (pip only; npm not usable)" }
        else { "Not Applicable (no usable package manager)" }

    if ($needs.Count) { Write-Output "NON-COMPLIANT: $status"; exit 1 }
    Write-Output "COMPLIANT: $status"
    exit 0
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
