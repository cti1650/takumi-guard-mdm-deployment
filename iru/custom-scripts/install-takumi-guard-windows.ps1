<#
.SYNOPSIS
    Takumi Guard configuration script (Iru Custom Script - Windows)
.DESCRIPTION
    Configures the npm / PyPI registry to Takumi Guard (anonymous mode).
    Uses each package manager command, preserving other existing settings.
.NOTES
    MDM: Iru
    Target OS: Windows 10/11
    Execution context: logged-on user
      (run in the user context so the user's own npm/pip settings are targeted)
    Encoding: UTF-8 without BOM, ASCII-only comments (safe on Windows PowerShell 5.1)
#>

# Takumi Guard anonymous registries (fixed values)
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"

# Log to stdout (captured by Iru; no separate log file needed)
function Write-Log {
    param([string]$Level, [string]$Message)
    Write-Output ("[{0}] [IRU] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message)
}

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
        Write-Log "WARN" "$Label not installed - skipped"
        return
    }
    # Capture output (incl. warnings on stderr); surface it only on failure.
    $output = & $Command @SetArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$Label configuration failed (exit $LASTEXITCODE): $output" }
    Write-Log "INFO" "$Label configured"
}

try {
    Write-Log "INFO" "=== Takumi Guard Installation (Iru Windows) ==="

    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    Set-Registry -Command $npm -SetArgs @("config", "set", "registry", $NpmRegistry) -Label "npm"
    Set-Registry -Command $pip -SetArgs @("config", "set", "global.index-url", $PypiIndex) -Label "PyPI"

    Write-Log "COMPLIANCE" "Takumi Guard status: COMPLIANT"
    Write-Log "INFO" "=== Takumi Guard Installation Complete ==="
    exit 0
}
catch {
    Write-Log "ERROR" $_.Exception.Message
    Write-Log "COMPLIANCE" "Takumi Guard status: FAILED"
    exit 1
}
