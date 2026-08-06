<#
.SYNOPSIS
    Windows E2E verify for Takumi Guard MDM scripts (Intune / Iru).
.DESCRIPTION
    Runs the product scripts under Windows PowerShell 5.1 through a full state
    transition: broken-shim detect -> unconfigured detect -> remediation ->
    configured detect -> uninstall -> reverted detect, then repeats the
    configure/detect/revert cycle with the Iru Windows script.

    Each expected exit code is asserted here; a mismatch fails the run. Note the
    inverted cases: detection returning exit 1 is the *expected* result when the
    package managers are present but unconfigured.

    Product scripts under intune/ and iru/ are never modified.
    Encoding: UTF-8 without BOM, ASCII only (Windows PowerShell 5.1 safe).
#>

$ErrorActionPreference = "Stop"

$Repo    = Split-Path -Parent $PSScriptRoot
$Detect  = Join-Path $Repo "intune\detection\detect-takumi-guard.ps1"
$Install = Join-Path $Repo "intune\remediation\install-takumi-guard.ps1"
$Uninst  = Join-Path $Repo "intune\uninstall\uninstall-takumi-guard.ps1"
$IruWin  = Join-Path $Repo "iru\custom-scripts\install-takumi-guard-windows.ps1"

$NpmExpected     = "https://npm.flatt.tech/"
$PipExpected     = "https://pypi.flatt.tech/simple/"
$NpmDefault      = "https://registry.npmjs.org/"

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
    param([string]$Path, [hashtable]$EnvOverride)
    $prevPath = $env:PATH
    try {
        if ($EnvOverride -and $EnvOverride.ContainsKey("PATH")) { $env:PATH = $EnvOverride["PATH"] }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $Path 2>&1 | ForEach-Object { Write-Host "    $_" }
        return $LASTEXITCODE
    } finally {
        $env:PATH = $prevPath
    }
}

# Assert an exit code equals the expectation.
function Assert-Exit {
    param([string]$Name, [int]$Actual, [int]$Expected)
    Add-Step $Name "exit $Expected" "exit $Actual" ($Actual -eq $Expected)
}

# Read a config value (trailing slash preserved for comparison against defaults).
function Get-NpmRegistry { (npm config get registry 2>$null | Out-String).Trim() }
function Get-PipIndex    { (pip config get global.index-url 2>$null | Out-String).Trim() }

Write-Host "== Takumi Guard Windows verify =="
Write-Host "Repo: $Repo"

# ------------------------------------------------------------------
# Scenario 1: broken-shim / PM-invisible PATH -> detect exit 0
#   Restrict PATH to core Windows dirs so npm/pip are not found at all;
#   the detect script treats absent PMs as out of scope = compliant.
# ------------------------------------------------------------------
$MinimalPath = "C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0"
$rc = Invoke-Script $Detect @{ PATH = $MinimalPath }
Assert-Exit "1. detect (PM invisible = out of scope, compliant)" $rc 0

# ------------------------------------------------------------------
# Scenario 2: normal PATH, PMs present but unconfigured -> detect exit 1
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect $null
Assert-Exit "2. detect (unconfigured -> flagged; exit 1 is correct)" $rc 1

# ------------------------------------------------------------------
# Scenario 3: remediation -> exit 0, then assert real values match
# ------------------------------------------------------------------
$rc = Invoke-Script $Install $null
Assert-Exit "3. remediation (install)" $rc 0

$npm = Get-NpmRegistry
Add-Step "3a. npm registry value" $NpmExpected $npm ($npm -eq $NpmExpected)
$pip = Get-PipIndex
Add-Step "3b. pip index-url value" $PipExpected $pip ($pip -eq $PipExpected)

# ------------------------------------------------------------------
# Scenario 4: detect after remediation -> exit 0
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect $null
Assert-Exit "4. detect (configured)" $rc 0

# ------------------------------------------------------------------
# Scenario 5: uninstall -> exit 0
# ------------------------------------------------------------------
$rc = Invoke-Script $Uninst $null
Assert-Exit "5. uninstall" $rc 0

# ------------------------------------------------------------------
# Scenario 6: detect after uninstall -> exit 1, npm back to default
# ------------------------------------------------------------------
$rc = Invoke-Script $Detect $null
Assert-Exit "6. detect (reverted -> flagged; exit 1 is correct)" $rc 1

$npm = Get-NpmRegistry
Add-Step "6a. npm registry default" $NpmDefault $npm ($npm -eq $NpmDefault)

# ------------------------------------------------------------------
# Scenario 7: Iru Windows script = same configure logic; one cycle
# ------------------------------------------------------------------
$rc = Invoke-Script $IruWin $null
Assert-Exit "7. iru install (configure)" $rc 0

$npm = Get-NpmRegistry
Add-Step "7a. iru npm registry value" $NpmExpected $npm ($npm -eq $NpmExpected)
$pip = Get-PipIndex
Add-Step "7b. iru pip index-url value" $PipExpected $pip ($pip -eq $PipExpected)

$rc = Invoke-Script $Detect $null
Assert-Exit "7c. detect (iru configured)" $rc 0

# Revert so the run leaves no residue.
$rc = Invoke-Script $Uninst $null
Assert-Exit "7d. iru revert (uninstall)" $rc 0

$rc = Invoke-Script $Detect $null
Assert-Exit "7e. detect (iru reverted -> flagged; exit 1 is correct)" $rc 1

# ------------------------------------------------------------------
# Step summary table
# ------------------------------------------------------------------
$failCount = ($Steps | Where-Object { $_.Status -eq "FAIL" }).Count

Write-Host ""
Write-Host "==========================================="
Write-Host "   WINDOWS VERIFY SUMMARY (FAIL=$failCount)"
Write-Host "==========================================="
$Steps | ForEach-Object { Write-Host ("{0,-6} {1}" -f $_.Status, $_.Name) }

if ($env:GITHUB_STEP_SUMMARY) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## Windows verify (PowerShell 5.1)")
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
    Write-Error "Windows verify failed ($failCount step(s))."
    exit 1
}
Write-Host "Windows verify passed."
exit 0
