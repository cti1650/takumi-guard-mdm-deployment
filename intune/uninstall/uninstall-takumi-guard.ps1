<#
.SYNOPSIS
    Takumi Guard uninstall script (revert npm / PyPI registry)
.DESCRIPTION
    Reverts the registry configured by install-takumi-guard.ps1 using each package
    manager command (npm config delete / pip config unset). Intended as the
    Win32 app "uninstall command". Only touches the key it manages; other settings
    are preserved.
.NOTES
    Execution context: logged-on user
    Encoding: UTF-8 without BOM, ASCII-only comments (safe on Windows PowerShell 5.1)
#>

# Return the first *usable* command (must run --version successfully), or $null.
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

# Remove the managed key. Ignore "key not set" errors; only report the action.
function Reset-Registry {
    param([string]$Command, [string[]]$ResetArgs, [string]$Label)
    if (-not $Command) {
        Write-Output "SKIP: $Label not installed"
        return
    }
    & $Command @ResetArgs 2>&1 | Out-Null
    Write-Output "RESET: $Label registry reverted"
}

try {
    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    Reset-Registry -Command $npm -ResetArgs @("config", "delete", "registry") -Label "npm"
    Reset-Registry -Command $pip -ResetArgs @("config", "unset", "global.index-url") -Label "PyPI"

    Write-Output "UNINSTALL SUCCESS: Takumi Guard registry reverted"
    exit 0
}
catch {
    Write-Error "UNINSTALL ERROR: $_"
    exit 1
}
