<#
.SYNOPSIS
    Takumi Guard WSL detection (Intune Remediation - Detection)
.DESCRIPTION
    Exit 0 = every WSL distribution configured (or WSL absent) / Exit 1 = a
    distribution needs remediation. Runs a POSIX probe inside each registered
    distribution via a login shell (sh -lc). A distribution that cannot run sh,
    and a package manager that is absent, cannot run, or resolves to the
    Windows host via interop (/mnt/*), is out of scope = compliant.
.NOTES
    Run as the logged-on user ("Run using logged-on credentials" = Yes);
    WSL distributions are registered per user (HKCU\Lxss) and are not
    visible to SYSTEM. Requires "Run script in 64-bit PowerShell" = Yes
    because wsl.exe exists only in the 64-bit System32.
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

# wsl.exe prints UTF-16LE by default; ask for UTF-8 (newer WSL honors this)
# and strip NUL bytes as a fallback for older versions.
$env:WSL_UTF8 = "1"

# Probe executed inside each distribution. Single-quoted lines joined with
# "; " so the command line stays one argument with no double quotes (safe
# through PowerShell 5.1 native argument passing and wsl.exe --exec).
# usable() rejects Windows-interop binaries under /mnt/ so the Windows host
# config is never mistaken for the distribution's own.
$Probe = @(
    'set -f'
    'usable(){ p=$(command -v $1 2>/dev/null) || return 1; case $p in /mnt/*) return 1;; esac; $1 --version >/dev/null 2>&1; }'
    'ng=0'
    'if usable npm; then cur=$(npm config get registry 2>/dev/null); cur=${cur%/}; echo npm: $cur; [ ${cur:-none} = https://npm.flatt.tech ] || ng=1; else echo SKIP: npm not usable; fi'
    'pm=; if usable pip; then pm=pip; elif usable pip3; then pm=pip3; fi'
    'if [ ${pm:-none} = none ]; then echo SKIP: pip not usable; else cur=$($pm config get global.index-url 2>/dev/null); cur=${cur%/}; echo pip: $cur; [ ${cur:-none} = https://pypi.flatt.tech/simple ] || ng=1; fi'
    'if [ $ng -eq 0 ]; then echo RESULT:OK; else echo RESULT:NEEDS; fi'
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

# Runs the probe in one distribution and returns the text after "RESULT:",
# or $null when the probe could not run there. Diagnostics use Write-Host
# because Write-Output would be captured into the return value.
function Invoke-WslProbe {
    param([string]$Distro, [string]$ShellScript)
    $lines = @(& wsl.exe -d $Distro --exec sh -lc $ShellScript 2>$null |
        ForEach-Object { ("$_" -replace "`0", "").Trim() } | Where-Object { $_ })
    foreach ($line in $lines) { Write-Host "${Distro}: $line" }
    foreach ($line in $lines) { if ($line -match '^RESULT:(.+)$') { return $Matches[1] } }
}

try {
    $distros = Get-WslDistro
    if ($distros.Count -eq 0) { Write-Output "COMPLIANT (no WSL distribution)"; exit 0 }

    $needs = @()
    foreach ($d in $distros) {
        $result = Invoke-WslProbe $d $Probe
        if (-not $result) { Write-Host "SKIP: $d not probeable"; continue }
        if ($result -ne "OK") { $needs += $d }
    }

    if ($needs.Count -eq 0) { Write-Output "COMPLIANT"; exit 0 }
    Write-Output "NON-COMPLIANT: $($needs -join ', ')"
    exit 1
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
