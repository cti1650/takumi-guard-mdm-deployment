<#
.SYNOPSIS
    Takumi Guard status detection script (Intune Remediation - Detection)
.DESCRIPTION
    Checks whether the npm / PyPI registry points to Takumi Guard (anonymous mode)
    by using each package manager command (npm config get / pip config get).
    It does not read config files directly, avoiding false judgements.
    Exit 0: configured (no remediation needed)
    Exit 1: not configured (remediation needed)
.NOTES
    MDM: Microsoft Intune
    Target OS: Windows 10/11
    Execution context: logged-on user
      (Intune "Run this script using the logged-on credentials" = Yes)
    Encoding: UTF-8 without BOM, ASCII-only comments (safe on Windows PowerShell 5.1)
#>

# Takumi Guard anonymous registries (fixed values)
# Ref: https://shisho.dev/docs/ja/t/guard/quickstart/
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"

# Return the first *usable* command (must run --version successfully), or $null.
# A version-manager shim (pyenv/nvm/asdf) with no version set exists on PATH but
# fails to run, so probing --version filters it out. pip / pip3 share the per-user
# config file, so resolving either one is enough.
function Resolve-Command {
    param([string[]]$Candidates)
    foreach ($name in $Candidates) {
        if (Get-Command $name -ErrorAction SilentlyContinue) {
            & $name --version 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { return $name }
        }
    }
    return $null
}

# Not installed -> out of scope (true). Installed -> true only if current value matches.
function Test-Registry {
    param([string]$Command, [string[]]$GetArgs, [string]$Expected, [string]$Label)

    if (-not $Command) {
        Write-Output "SKIP: $Label not installed"
        return $true
    }

    $current = (& $Command @GetArgs 2>$null | Out-String).Trim()
    if ($current.TrimEnd('/') -eq $Expected.TrimEnd('/')) {
        Write-Output "OK: $Label -> $current"
        return $true
    }

    Write-Output "NG: $Label -> $current"
    return $false
}

try {
    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    $npmOk = Test-Registry -Command $npm -GetArgs @("config", "get", "registry") -Expected $NpmRegistry -Label "npm"
    $pipOk = Test-Registry -Command $pip -GetArgs @("config", "get", "global.index-url") -Expected $PypiIndex -Label "PyPI"

    if ($npmOk -and $pipOk) {
        Write-Output "COMPLIANT: Takumi Guard is properly configured (npm/PyPI)"
        exit 0
    }

    Write-Output "NON-COMPLIANT: Takumi Guard configuration required"
    exit 1
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
