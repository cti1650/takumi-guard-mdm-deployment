<#
.SYNOPSIS
    Build an .intunewin package from this repo's Intune scripts.
.DESCRIPTION
    Downloads the Microsoft Win32 Content Prep Tool (cached under IntuneWinAppUtil/),
    stages the Intune install / uninstall / detection scripts, and produces
    install-takumi-guard.intunewin under output/. Also writes output/intune-config.txt
    with the exact Intune install / uninstall commands and detection rule to paste
    into the admin center.

    Runs on Windows PowerShell 5.1+ or PowerShell 7+ (CI windows runner or local Windows).
.NOTES
    Encoding: UTF-8 without BOM, ASCII-only comments.
#>
param(
    [string]$OutputDir = "output",
    [string]$CacheDir  = "IntuneWinAppUtil",
    [string]$StageDir  = "build-stage"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

# Fixed anonymous registries (for the generated config note)
$NpmRegistry   = "https://npm.flatt.tech/"
$PypiIndex     = "https://pypi.flatt.tech/simple/"
$InstallScript = "install-takumi-guard.ps1"

# Resolve IntuneWinAppUtil.exe; download+extract once, reuse if cached.
function Get-IntuneWinAppUtilPath {
    param(
        [string]$Dir,
        [string]$ZipUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/archive/refs/heads/master.zip"
    )
    $existing = Get-ChildItem -Path $Dir -Filter IntuneWinAppUtil.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        Write-Host "Using cached IntuneWinAppUtil: $($existing.FullName)"
        return $existing.FullName
    }
    Write-Host "Downloading IntuneWinAppUtil..."
    $zip = Join-Path ([System.IO.Path]::GetTempPath()) "IntuneWinAppUtil.zip"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $Dir -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
    $tool = Get-ChildItem -Path $Dir -Filter IntuneWinAppUtil.exe -Recurse | Select-Object -First 1
    if (-not $tool) { throw "IntuneWinAppUtil.exe not found after download" }
    return $tool.FullName
}

# Stage the scripts to package
$stage        = Join-Path $repoRoot $StageDir
$intunewinOut = Join-Path $repoRoot $OutputDir
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item $stage, $intunewinOut -ItemType Directory -Force | Out-Null

Copy-Item (Join-Path $repoRoot "intune/remediation/install-takumi-guard.ps1")  (Join-Path $stage $InstallScript)                 -Force
Copy-Item (Join-Path $repoRoot "intune/uninstall/uninstall-takumi-guard.ps1")  (Join-Path $stage "uninstall-takumi-guard.ps1")   -Force
Copy-Item (Join-Path $repoRoot "intune/detection/detect-takumi-guard.ps1")     (Join-Path $stage "detect-takumi-guard.ps1")      -Force

# Build the package
$tool = Get-IntuneWinAppUtilPath -Dir (Join-Path $repoRoot $CacheDir)
Write-Host "Building intunewin (setup: $InstallScript)..."
& $tool -c $stage -s $InstallScript -o $intunewinOut -q
if ($LASTEXITCODE -ne 0) { throw "IntuneWinAppUtil failed (exit $LASTEXITCODE)" }

$built = Get-ChildItem (Join-Path $intunewinOut "*.intunewin") | Select-Object -First 1
if (-not $built) { throw "No .intunewin produced" }
Write-Host "Produced: $($built.Name)"

# Emit the Intune config the operator pastes into the admin center
$installCmd   = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallScript"
$uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall-takumi-guard.ps1"
@"
# Takumi Guard - Intune Win32 app configuration
# Generated (UTC): $((Get-Date).ToUniversalTime().ToString('o'))

Install behavior : User
Install command  : $installCmd
Uninstall command: $uninstallCmd

Detection rule   : Use a custom detection script = detect-takumi-guard.ps1
  Run script as 32-bit process on 64-bit clients: No
  Enforce script signature check                : No

Fixed values (anonymous):
  npm  registry  = $NpmRegistry
  PyPI index-url = $PypiIndex
"@ | Out-File (Join-Path $intunewinOut "intune-config.txt") -Encoding utf8

Write-Host "Build completed. Output:"
Get-ChildItem $intunewinOut | ForEach-Object { Write-Host "  $($_.Name)" }
