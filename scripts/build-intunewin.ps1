<#
.SYNOPSIS
    Build an .intunewin package from this repo's Intune scripts.
.DESCRIPTION
    Downloads the Microsoft Win32 Content Prep Tool (cached under IntuneWinAppUtil/),
    stages the Intune install / uninstall / detection scripts, and produces
    install-takumi-guard.intunewin and install-takumi-guard-wsl.intunewin under
    output/. Also writes output/intune-config.txt / intune-config-wsl.txt with the
    exact Intune install / uninstall commands and detection rules to paste into
    the admin center.

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
$NpmRegistry      = "https://npm.flatt.tech/"
$PypiIndex        = "https://pypi.flatt.tech/simple/"
$InstallScript    = "install-takumi-guard.ps1"
$InstallScriptWsl = "install-takumi-guard-wsl.ps1"

# The Intune agent launches Win32 install commands from a 32-bit host, but
# wsl.exe exists only in the 64-bit System32, so the WSL package must invoke
# PowerShell through the Sysnative alias.
$SysnativePS = "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

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

$intunewinOut = Join-Path $repoRoot $OutputDir
New-Item $intunewinOut -ItemType Directory -Force | Out-Null
$tool = Get-IntuneWinAppUtilPath -Dir (Join-Path $repoRoot $CacheDir)

# Stage the given repo scripts and build <setup name>.intunewin under output/.
function Build-Package {
    param([string]$Stage, [string[]]$Sources, [string]$SetupFile)
    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $Stage -ItemType Directory -Force | Out-Null
    foreach ($src in $Sources) {
        Copy-Item (Join-Path $repoRoot $src) (Join-Path $Stage (Split-Path $src -Leaf)) -Force
    }
    Write-Host "Building intunewin (setup: $SetupFile)..."
    & $tool -c $Stage -s $SetupFile -o $intunewinOut -q
    if ($LASTEXITCODE -ne 0) { throw "IntuneWinAppUtil failed (exit $LASTEXITCODE)" }
    $name = [System.IO.Path]::GetFileNameWithoutExtension($SetupFile) + ".intunewin"
    if (-not (Test-Path (Join-Path $intunewinOut $name))) { throw "No $name produced" }
    Write-Host "Produced: $name"
}

Build-Package (Join-Path $repoRoot $StageDir) @(
    "intune/remediation/install-takumi-guard.ps1",
    "intune/uninstall/uninstall-takumi-guard.ps1",
    "intune/detection/detect-takumi-guard.ps1"
) $InstallScript

Build-Package (Join-Path $repoRoot "$StageDir-wsl") @(
    "intune/remediation/install-takumi-guard-wsl.ps1",
    "intune/uninstall/uninstall-takumi-guard-wsl.ps1",
    "intune/detection/detect-takumi-guard-wsl.ps1"
) $InstallScriptWsl

# Emit the Intune config the operator pastes into the admin center
$installCmd   = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $InstallScript"
$uninstallCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File uninstall-takumi-guard.ps1"
@"
# Takumi Guard - Intune Win32 app configuration
# Generated (UTC): $((Get-Date).ToUniversalTime().ToString('o'))

[App information]  (Name / Description / Publisher are required)
  Name        : Takumi Guard Configuration
  Description : Routes npm / PyPI package downloads through Takumi Guard to block malicious packages.
  Publisher   : <your organization, e.g. IT Department>
  App Version : 1.0
  Information URL: https://shisho.dev/docs/ja/t/guard/

[Program]
  Install behavior : User
  Install command  : $installCmd
  Uninstall command: $uninstallCmd
  Device restart behavior: No specific action

[Requirements]
  Operating system architecture: x64 (add Arm64 if applicable)
  Minimum operating system    : Windows 10 1607

[Detection rules]
  Rules format: Use a custom detection script = detect-takumi-guard.ps1
  Run script as 32-bit process on 64-bit clients: No
  Enforce script signature check                : No

Fixed values (anonymous):
  npm  registry  = $NpmRegistry
  PyPI index-url = $PypiIndex
"@ | Out-File (Join-Path $intunewinOut "intune-config.txt") -Encoding utf8

# Same for the optional WSL package (a second, separate Win32 app).
$installCmdWsl   = "$SysnativePS -NoProfile -ExecutionPolicy Bypass -File $InstallScriptWsl"
$uninstallCmdWsl = "$SysnativePS -NoProfile -ExecutionPolicy Bypass -File uninstall-takumi-guard-wsl.ps1"
@"
# Takumi Guard (WSL) - Intune Win32 app configuration (optional second app)
# Generated (UTC): $((Get-Date).ToUniversalTime().ToString('o'))

[App information]  (Name / Description / Publisher are required)
  Name        : Takumi Guard Configuration (WSL)
  Description : Routes npm / PyPI package downloads inside WSL distributions through Takumi Guard.
  Publisher   : <your organization, e.g. IT Department>
  App Version : 1.0
  Information URL: https://shisho.dev/docs/ja/t/guard/

[Program]
  Install behavior : User
  Install command  : $installCmdWsl
  Uninstall command: $uninstallCmdWsl
  Device restart behavior: No specific action
  # Sysnative is required: wsl.exe exists only in the 64-bit System32 and the
  # Intune agent launches install commands from a 32-bit host.

[Requirements]
  Operating system architecture: x64 (add Arm64 if applicable)
  Minimum operating system    : Windows 10 1607

[Detection rules]
  Rules format: Use a custom detection script = detect-takumi-guard-wsl.ps1
  Run script as 32-bit process on 64-bit clients: No
  Enforce script signature check                : No
  # Devices without WSL report COMPLIANT (exit 0 + output) = detected as
  # installed, so the install command never runs there.

Fixed values (anonymous):
  npm  registry  = $NpmRegistry
  PyPI index-url = $PypiIndex
"@ | Out-File (Join-Path $intunewinOut "intune-config-wsl.txt") -Encoding utf8

Write-Host "Build completed. Output:"
Get-ChildItem $intunewinOut | ForEach-Object { Write-Host "  $($_.Name)" }
