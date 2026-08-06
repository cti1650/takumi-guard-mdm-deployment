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
# Reports a per-package-manager state (ok / needs / skip) on the RESULT line;
# the human-readable status is composed on the PowerShell side.
$Probe = @(
    'set -f'
    'usable(){ u=$(command -v $1 2>/dev/null) || return 1; case $u in /mnt/*) return 1;; esac; $1 --version >/dev/null 2>&1; }'
    'n=skip; if usable npm; then cur=$(npm config get registry 2>/dev/null); cur=${cur%/}; echo npm: ${cur:-unset}; if [ ${cur:-none} = https://npm.flatt.tech ]; then n=ok; else n=needs; fi; fi'
    'pm=; if usable pip; then pm=pip; elif usable pip3; then pm=pip3; fi'
    'p=skip; if [ ${pm:-none} != none ]; then cur=$($pm config get global.index-url 2>/dev/null); cur=${cur%/}; echo pip: ${cur:-unset}; if [ ${cur:-none} = https://pypi.flatt.tech/simple ]; then p=ok; else p=needs; fi; fi'
    'echo RESULT:npm=$n pip=$p'
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
# or $null when the probe could not run there. The RESULT protocol line is
# not displayed. Diagnostics use Write-Host because Write-Output would be
# captured into the return value.
function Invoke-WslProbe {
    param([string]$Distro, [string]$ShellScript)
    $lines = @(& wsl.exe -d $Distro --exec sh -lc $ShellScript 2>$null |
        ForEach-Object { ("$_" -replace "`0", "").Trim() } | Where-Object { $_ })
    foreach ($line in $lines) { if ($line -notmatch '^RESULT:') { Write-Host "${Distro}: $line" } }
    foreach ($line in $lines) { if ($line -match '^RESULT:(.+)$') { return $Matches[1] } }
}

# Compose the same status vocabulary as the Jamf extension attribute from a
# "npm=<state> pip=<state>" marker (state: ok / needs / skip).
function Format-Status {
    param([string]$Marker)
    $npm = if ($Marker -match 'npm=(\w+)') { $Matches[1] } else { "skip" }
    $pip = if ($Marker -match 'pip=(\w+)') { $Matches[1] } else { "skip" }
    $needs = @()
    if ($npm -eq "needs") { $needs += "npm" }
    if ($pip -eq "needs") { $needs += "pip" }
    if ($needs.Count) { return "Not Configured ($($needs -join ', '))" }
    if ($npm -eq "ok" -and $pip -eq "ok") { return "Configured" }
    if ($npm -eq "ok") { return "Configured (npm only; pip not usable)" }
    if ($pip -eq "ok") { return "Configured (pip only; npm not usable)" }
    return "Not Applicable (no usable package manager)"
}

try {
    $distros = Get-WslDistro
    if ($distros.Count -eq 0) { Write-Output "COMPLIANT (no WSL distribution)"; exit 0 }

    $needs = @()
    $tally = @{}
    foreach ($d in $distros) {
        $marker = Invoke-WslProbe $d $Probe
        $status = if ($marker) { Format-Status $marker } else { "Not Probeable (sh failed)" }
        Write-Host "${d}: $status"
        if ($status -like "Not Configured*") { $needs += $d }
        $key = switch -Wildcard ($status) {
            "Not Configured*"  { "not configured" }
            "Configured"       { "configured" }
            "Configured (*"    { "partially configured" }
            "Not Applicable*"  { "not applicable" }
            "Not Probeable*"   { "not probeable" }
        }
        $tally[$key] = 1 + $(if ($tally.ContainsKey($key)) { $tally[$key] } else { 0 })
    }

    if ($needs.Count) { Write-Output "NON-COMPLIANT: $($needs -join ', ')"; exit 1 }
    $summary = @("configured", "partially configured", "not applicable", "not probeable") |
        Where-Object { $tally.ContainsKey($_) } | ForEach-Object { "$($tally[$_]) $_" }
    Write-Output "COMPLIANT ($($summary -join ', '))"
    exit 0
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
