<#
.SYNOPSIS
    Windows E2E verify for the Takumi Guard WSL scripts (Intune).
.DESCRIPTION
    Runs the WSL product scripts under Windows PowerShell 5.1 against a real
    registered WSL distribution through a full state transition: bare distro
    (no PM) detect -> install PMs -> unconfigured detect -> remediation ->
    configured detect -> uninstall -> reverted detect. Also asserts that the
    Windows-side npm config is never touched (interop safety).

    Expects one usable WSL distribution (e.g. registered by Vampire/setup-wsl
    on a CI runner, or any local distro). WSL 1 is sufficient: the scripts
    only use the wsl.exe CLI surface (--list/-d/--exec) which is identical.

    Each expected exit code is asserted here; a mismatch fails the run. Note
    the inverted case: detection returning exit 1 is the *expected* result
    when package managers are present but unconfigured.

    Product scripts under intune/ are never modified.
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

$Repo    = Split-Path -Parent $PSScriptRoot
$Detect  = Join-Path $Repo "intune\detection\detect-takumi-guard-wsl.ps1"
$Install = Join-Path $Repo "intune\remediation\install-takumi-guard-wsl.ps1"
$Uninst  = Join-Path $Repo "intune\uninstall\uninstall-takumi-guard-wsl.ps1"

$NpmExpected = "https://npm.flatt.tech/"
$PipExpected = "https://pypi.flatt.tech/simple/"

# Ask wsl.exe for UTF-8 where supported; strip NUL bytes as fallback.
$env:WSL_UTF8 = "1"

# Step results for the summary table.
$Steps = New-Object System.Collections.Generic.List[object]
$Failed = $false

function Add-Step {
    param([string]$Name, [string]$Expected, [string]$Actual, [bool]$Ok)
    $status = if ($Ok) { "PASS" } else { "FAIL" }
    $script:Steps.Add([pscustomobject]@{ Name = $Name; Expected = $Expected; Actual = $Actual; Status = $status })
    if (-not $Ok) { $script:Failed = $true }
    Write-Host ("[{0}] {1} | expected={2} actual={3}" -f $status, $Name, $Expected, $Actual)
}

# Run a product script and return its exit code (PS 5.1 child process).
function Invoke-Script {
    param([string]$Path)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path 2>&1 | ForEach-Object { Write-Host "    $_" }
    return $LASTEXITCODE
}

# Assert an exit code equals the expectation.
function Assert-Exit {
    param([string]$Name, [int]$Actual, [int]$Expected)
    Add-Step $Name "exit $Expected" "exit $Actual" ($Actual -eq $Expected)
}

# First registered distribution (NUL-stripped for old UTF-16LE wsl.exe).
function Get-FirstDistro {
    $raw = (& wsl.exe --list --quiet 2>$null | Out-String) -replace "`0", ""
    @($raw -split "`r?`n" | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^(docker-desktop|rancher-desktop|podman-)' }) | Select-Object -First 1
}

# Run a POSIX command line inside the distro; returns trimmed stdout.
function Invoke-InDistro {
    param([string]$Distro, [string]$Command, [string]$User)
    $userArgs = if ($User) { @("-u", $User) } else { @() }
    $out = (& wsl.exe -d $Distro @userArgs --exec sh -lc $Command 2>&1 | Out-String) -replace "`0", ""
    return $out.Trim()
}

function Get-WindowsNpmRegistry { (npm config get registry 2>$null | Out-String).Trim() }

Write-Host "== Takumi Guard WSL verify =="
Write-Host "Repo: $Repo"

$distro = Get-FirstDistro
if (-not $distro) {
    Write-Error "No WSL distribution registered; cannot verify."
    exit 1
}
Write-Host "Distro: $distro"
Write-Host "Default user: $(Invoke-InDistro $distro 'id -un')"

# Windows-side npm registry must never change during this run.
$winNpmBefore = Get-WindowsNpmRegistry
Write-Host "Windows npm registry (before): $winNpmBefore"

# ------------------------------------------------------------------
# Scenario 1: bare distro (no PM installed inside) -> detect exit 0
#   npm/pip are absent in the distro (a Windows npm reachable only via
#   /mnt interop is excluded by design), so everything skips = compliant.
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect
Assert-Exit "1. detect (bare distro)" $rc 0

# ------------------------------------------------------------------
# Scenario 2: install npm + pip inside the distro, still unconfigured
#             -> detect exit 1
# ------------------------------------------------------------------
Write-Host "Installing npm / python3-pip inside ${distro}..."
Invoke-InDistro $distro "apt-get update -qq && apt-get install -y -qq npm python3-pip >/dev/null" "root" | Write-Host
Write-Host "npm: $(Invoke-InDistro $distro 'npm --version'), pip: $(Invoke-InDistro $distro 'pip3 --version')"

$rc = Invoke-Script $Detect
Assert-Exit "2. detect (unconfigured)" $rc 1

# ------------------------------------------------------------------
# Scenario 3: remediation -> exit 0, then assert real values inside WSL
# ------------------------------------------------------------------
$rc = Invoke-Script $Install
Assert-Exit "3. remediation (install)" $rc 0

$npm = Invoke-InDistro $distro "npm config get registry"
Add-Step "3a. npm registry value (in WSL)" $NpmExpected $npm ($npm -eq $NpmExpected)
$pip = Invoke-InDistro $distro "pip3 config get global.index-url"
Add-Step "3b. pip index-url value (in WSL)" $PipExpected $pip ($pip -eq $PipExpected)

# ------------------------------------------------------------------
# Scenario 4: detect after remediation -> exit 0
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect
Assert-Exit "4. detect (configured)" $rc 0

# ------------------------------------------------------------------
# Scenario 5: uninstall -> exit 0, keys removed
# ------------------------------------------------------------------
$rc = Invoke-Script $Uninst
Assert-Exit "5. uninstall" $rc 0

# ------------------------------------------------------------------
# Scenario 6: detect after uninstall -> exit 1 (npm back to default)
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect
Assert-Exit "6. detect (reverted)" $rc 1

# ------------------------------------------------------------------
# Scenario 7: Windows-side npm config untouched throughout
# ------------------------------------------------------------------
$winNpmAfter = Get-WindowsNpmRegistry
Add-Step "7. windows npm registry unchanged" $winNpmBefore $winNpmAfter ($winNpmAfter -eq $winNpmBefore)

# ------------------------------------------------------------------
# Step summary table
# ------------------------------------------------------------------
$failCount = ($Steps | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host ""
Write-Host "==========================================="
Write-Host "   WSL VERIFY SUMMARY (FAIL=$failCount)"
Write-Host "==========================================="
$Steps | ForEach-Object { Write-Host ("{0,-6} {1}" -f $_.Status, $_.Name) }

if ($env:GITHUB_STEP_SUMMARY) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## WSL verify (PowerShell 5.1 + $distro)")
    $lines.Add("")
    $lines.Add("| Step | Expected | Actual | Status |")
    $lines.Add("|------|----------|--------|--------|")
    foreach ($s in $Steps) {
        $lines.Add("| $($s.Name) | $($s.Expected) | $($s.Actual) | $($s.Status) |")
    }
    $lines.Add("")
    $lines.Add("FAIL=$failCount total=$($Steps.Count)")
    $lines -join "`n" | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
}

if ($Failed) {
    Write-Error "WSL verify failed ($failCount step(s))."
    exit 1
}
Write-Host "WSL verify passed."
exit 0
