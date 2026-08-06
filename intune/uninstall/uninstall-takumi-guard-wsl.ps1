<#
.SYNOPSIS
    Takumi Guard WSL uninstall (revert npm / pip registry inside WSL)
.DESCRIPTION
    Removes only the keys managed by install-takumi-guard-wsl.ps1 via
    "npm config delete" / "pip config unset" run in a login shell (sh -lc)
    inside every registered WSL distribution; other settings are preserved.
    A distribution that cannot run sh, and a package manager that is absent,
    cannot run, or resolves to the Windows host via interop (/mnt/*), is
    skipped.
.NOTES
    Run as the logged-on user; WSL distributions are registered per user
    (HKCU\Lxss) and are not visible to SYSTEM. Requires 64-bit PowerShell
    because wsl.exe exists only in the 64-bit System32.
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

# wsl.exe prints UTF-16LE by default; ask for UTF-8 (newer WSL honors this)
# and strip NUL bytes as a fallback for older versions.
$env:WSL_UTF8 = "1"

# Commands executed inside each distribution. Single-quoted lines joined with
# "; " so the command line stays one argument with no double quotes (safe
# through PowerShell 5.1 native argument passing and wsl.exe --exec).
# "key not set" errors are ignored; removing an absent key is already the goal.
$Revert = @(
    'set -f'
    'usable(){ p=$(command -v $1 2>/dev/null) || return 1; case $p in /mnt/*) return 1;; esac; $1 --version >/dev/null 2>&1; }'
    'if usable npm; then npm config delete registry >/dev/null 2>&1; echo OK: npm reverted; else echo SKIP: npm not usable; fi'
    'pm=; if usable pip; then pm=pip; elif usable pip3; then pm=pip3; fi'
    'if [ ${pm:-none} = none ]; then echo SKIP: pip not usable; else $pm config unset global.index-url >/dev/null 2>&1; echo OK: pip reverted; fi'
    'echo RESULT:DONE'
) -join '; '

# Registered distributions of the current user; utility distributions that
# ship with container tools are excluded. Empty when WSL is absent.
function Get-WslDistro {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return @() }
    $raw = (& wsl.exe --list --quiet 2>$null | Out-String) -replace "`0", ""
    if ($LASTEXITCODE -ne 0) { return @() }
    @($raw -split "`r?`n" | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^(docker-desktop|rancher-desktop|podman-)' })
}

# Runs the commands in one distribution and returns the text after "RESULT:",
# or $null when they could not run there. The RESULT protocol line is not
# displayed. Diagnostics use Write-Host because Write-Output would be
# captured into the return value.
function Invoke-WslProbe {
    param([string]$Distro, [string]$ShellScript)
    $lines = @(& wsl.exe -d $Distro --exec sh -lc $ShellScript 2>$null |
        ForEach-Object { ("$_" -replace "`0", "").Trim() } | Where-Object { $_ })
    foreach ($line in $lines) { if ($line -notmatch '^RESULT:') { Write-Host "${Distro}: $line" } }
    foreach ($line in $lines) { if ($line -match '^RESULT:(.+)$') { return $Matches[1] } }
}

try {
    $distros = Get-WslDistro
    if ($distros.Count -eq 0) { Write-Output "UNINSTALL SUCCESS (no WSL distribution)"; exit 0 }

    foreach ($d in $distros) {
        $result = Invoke-WslProbe $d $Revert
        if (-not $result) { Write-Output "SKIP: $d not probeable"; continue }
        Write-Output "OK: $d reverted"
    }

    Write-Output "UNINSTALL SUCCESS"
    exit 0
}
catch {
    Write-Error "UNINSTALL ERROR: $_"
    exit 1
}
