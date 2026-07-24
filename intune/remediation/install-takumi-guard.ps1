<#
.SYNOPSIS
    Takumi Guard configuration script (Intune Remediation - Remediation)
.DESCRIPTION
    Configures the npm / PyPI registry to Takumi Guard (anonymous mode).
    Uses each package manager command (npm config set / pip config set), so it does
    not edit .npmrc / pip.ini directly and preserves other existing settings.
.NOTES
    MDM: Microsoft Intune
    Target OS: Windows 10/11
    Execution context: logged-on user
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

function Set-Registry {
    param([string]$Command, [string[]]$SetArgs, [string]$Label)

    if (-not $Command) {
        Write-Output "SKIP: $Label not installed"
        return
    }

    & $Command @SetArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$Label configuration failed (exit $LASTEXITCODE)"
    }
    Write-Output "SET: $Label configured"
}

try {
    Write-Output "REMEDIATION: Starting Takumi Guard configuration"

    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    Set-Registry -Command $npm -SetArgs @("config", "set", "registry", $NpmRegistry) -Label "npm"
    Set-Registry -Command $pip -SetArgs @("config", "set", "global.index-url", $PypiIndex) -Label "PyPI"

    Write-Output "REMEDIATION SUCCESS: Takumi Guard configured"
    exit 0
}
catch {
    Write-Error "REMEDIATION ERROR: $_"
    exit 1
}
