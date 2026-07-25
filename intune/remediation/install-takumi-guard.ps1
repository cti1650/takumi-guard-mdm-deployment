<#
.SYNOPSIS
    Takumi Guard remediation (Intune Remediation - Remediation)
.DESCRIPTION
    Sets npm registry / pip index-url to Takumi Guard (anonymous, fixed values)
    via "npm config set" / "pip config set" so existing settings are preserved.
    A package manager that is absent or cannot run is skipped.
.NOTES
    Run as the logged-on user ("Run using logged-on credentials" = Yes).
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

# Fixed anonymous registries
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"

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

# Warnings on stderr are captured and shown only when the command fails.
function Set-Config {
    param([string]$Command, [string[]]$SetArgs, [string]$Label)
    if (-not $Command) { Write-Output "SKIP: $Label not usable"; return }
    $output = & $Command @SetArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$Label configuration failed: $output" }
    Write-Output "OK: $Label configured"
}

try {
    Set-Config (Get-UsableCommand npm) @("config", "set", "registry", $NpmRegistry) "npm"
    Set-Config (Get-UsableCommand pip, pip3) @("config", "set", "global.index-url", $PypiIndex) "pip"
    Write-Output "REMEDIATION SUCCESS"
    exit 0
}
catch {
    Write-Error "REMEDIATION ERROR: $_"
    exit 1
}
