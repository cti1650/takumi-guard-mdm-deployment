<#
.SYNOPSIS
    Takumi Guard 設定投入スクリプト (Iru Custom Script - Windows)
.DESCRIPTION
    Iru (旧Kandji) のWindowsカスタムスクリプトとして実行
    Device Settings または Auto App として配布可能
.NOTES
    MDM: Iru
    対象OS: Windows 10/11

    環境変数で設定を制御:
      TAKUMI_REGISTRY_URL : レジストリURL (必須)
      TAKUMI_INSTALL_MODE : user | global | both (デフォルト: user)
      TAKUMI_CREATE_BACKUP : true | false (デフォルト: true)
#>

# ============================================
# 設定
# ============================================
$Config = @{
    RegistryUrl   = $env:TAKUMI_REGISTRY_URL
    InstallMode   = if ($env:TAKUMI_INSTALL_MODE) { $env:TAKUMI_INSTALL_MODE } else { "user" }
    CreateBackup  = if ($env:TAKUMI_CREATE_BACKUP -eq "false") { $false } else { $true }
    LogFile       = "$env:ProgramData\Iru\Logs\takumi-guard.log"
}

# ============================================
# ログ
# ============================================
function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    $logDir = Split-Path $Config.LogFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [IRU] [$Level] $Message"
    Add-Content -Path $Config.LogFile -Value $logEntry -Encoding UTF8
    Write-Output $logEntry
}

# ============================================
# 検証
# ============================================
function Test-Configuration {
    if ([string]::IsNullOrWhiteSpace($Config.RegistryUrl)) {
        Write-Log "ERROR" "TAKUMI_REGISTRY_URL environment variable is required"
        Write-Log "ERROR" "Configure this in Iru Blueprint > Custom Script > Environment Variables"
        return $false
    }
    return $true
}

# ============================================
# ユーザー検出
# ============================================
function Get-CurrentConsoleUser {
    try {
        $user = (Get-WmiObject -Class Win32_ComputerSystem).UserName
        if ($user -and $user -ne "SYSTEM") {
            return $user.Split('\')[-1]
        }
    }
    catch {
        Write-Log "WARN" "Could not detect current user: $_"
    }
    return $null
}

# ============================================
# バックアップ処理
# ============================================
function Backup-File {
    param([string]$FilePath)

    if ((Test-Path $FilePath) -and $Config.CreateBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$FilePath.backup_$timestamp"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-Log "INFO" "Backup created: $backupPath"
    }
}

# ============================================
# 設定投入処理
# ============================================
function Set-NpmrcRegistry {
    param(
        [string]$NpmrcPath,
        [string]$RegistryUrl
    )

    Backup-File -FilePath $NpmrcPath

    $registryLine = "registry=$RegistryUrl"

    if (Test-Path $NpmrcPath) {
        $content = Get-Content $NpmrcPath | Where-Object { $_ -notmatch "^registry=" }
        $newContent = @($registryLine) + $content
        $newContent | Set-Content -Path $NpmrcPath -Encoding UTF8
    }
    else {
        $registryLine | Set-Content -Path $NpmrcPath -Encoding UTF8
    }

    Write-Log "INFO" "Configured: $NpmrcPath"
}

# ============================================
# Iru Compliance Report
# ============================================
function Report-Compliance {
    param([string]$Status)
    Write-Log "COMPLIANCE" "Takumi Guard status: $Status"
}

# ============================================
# メイン処理
# ============================================
function Main {
    Write-Log "INFO" "=== Takumi Guard Installation (Iru Windows) ==="
    Write-Log "INFO" "Install mode: $($Config.InstallMode)"

    if (-not (Test-Configuration)) {
        Report-Compliance "FAILED"
        exit 1
    }

    $currentUser = Get-CurrentConsoleUser

    switch ($Config.InstallMode) {
        "user" {
            if (-not $currentUser) {
                Write-Log "ERROR" "No valid user session found"
                Report-Compliance "FAILED"
                exit 1
            }
            $userProfile = (Get-WmiObject Win32_UserProfile | Where-Object { $_.LocalPath -like "*$currentUser*" }).LocalPath
            if ($userProfile) {
                Set-NpmrcRegistry -NpmrcPath "$userProfile\.npmrc" -RegistryUrl $Config.RegistryUrl
            }
        }
        "global" {
            # Program Dataに配置
            $globalNpmrc = "$env:ProgramData\npm\npmrc"
            $parentDir = Split-Path $globalNpmrc -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            Set-NpmrcRegistry -NpmrcPath $globalNpmrc -RegistryUrl $Config.RegistryUrl
        }
        "both" {
            # Global
            $globalNpmrc = "$env:ProgramData\npm\npmrc"
            $parentDir = Split-Path $globalNpmrc -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            Set-NpmrcRegistry -NpmrcPath $globalNpmrc -RegistryUrl $Config.RegistryUrl

            # User
            if ($currentUser) {
                $userProfile = (Get-WmiObject Win32_UserProfile | Where-Object { $_.LocalPath -like "*$currentUser*" }).LocalPath
                if ($userProfile) {
                    Set-NpmrcRegistry -NpmrcPath "$userProfile\.npmrc" -RegistryUrl $Config.RegistryUrl
                }
            }
        }
        default {
            Write-Log "ERROR" "Invalid install mode: $($Config.InstallMode)"
            Report-Compliance "FAILED"
            exit 1
        }
    }

    Report-Compliance "COMPLIANT"
    Write-Log "INFO" "=== Takumi Guard Installation Complete ==="
    exit 0
}

Main
