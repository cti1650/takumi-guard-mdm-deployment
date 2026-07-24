<#
.SYNOPSIS
    Takumi Guard 設定投入スクリプト (Intune Remediation - Remediation)
.DESCRIPTION
    Takumi Guardのレジストリ設定を.npmrcに投入します。
    Intune修復スクリプトとして動作し、検出スクリプトで異常判定時に実行されます。
.NOTES
    MDM: Microsoft Intune
    対象OS: Windows 10/11
#>

# ============================================
# 設定（環境変数から取得、未設定時はデフォルト値）
# ============================================
$Config = @{
    # npm設定ファイルのパス
    NpmrcPath = if ($env:TAKUMI_NPMRC_PATH) { $env:TAKUMI_NPMRC_PATH } else { "$env:USERPROFILE\.npmrc" }

    # Takumi Guard レジストリURL（組織トークンを含む）
    # 形式: https://registry.takumi.dev/npm/<ORG_TOKEN>/
    # 匿名利用の場合: https://registry.takumi.dev/npm/
    RegistryUrl = if ($env:TAKUMI_REGISTRY_URL) { $env:TAKUMI_REGISTRY_URL } else { "" }

    # バックアップを作成するか
    CreateBackup = if ($env:TAKUMI_CREATE_BACKUP) { [bool]$env:TAKUMI_CREATE_BACKUP } else { $true }

    # 既存設定をマージするか（false=上書き）
    MergeConfig = if ($env:TAKUMI_MERGE_CONFIG) { [bool]$env:TAKUMI_MERGE_CONFIG } else { $true }
}

# ============================================
# 検証
# ============================================
if ([string]::IsNullOrWhiteSpace($Config.RegistryUrl)) {
    Write-Error "REMEDIATION ERROR: TAKUMI_REGISTRY_URL environment variable is required"
    Write-Error "Set the registry URL via Intune script configuration or device environment"
    exit 1
}

# ============================================
# バックアップ処理
# ============================================
function Backup-Npmrc {
    param([string]$Path)

    if ((Test-Path $Path) -and $Config.CreateBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$Path.backup_$timestamp"
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-Output "BACKUP: Created backup at $backupPath"
    }
}

# ============================================
# 設定投入処理
# ============================================
function Set-NpmrcRegistry {
    param([string]$Path, [string]$RegistryUrl)

    $registryLine = "registry=$RegistryUrl"

    if ($Config.MergeConfig -and (Test-Path $Path)) {
        # 既存設定とマージ
        $content = Get-Content $Path
        $newContent = @()
        $registryFound = $false

        foreach ($line in $content) {
            if ($line -match "^registry\s*=") {
                $newContent += $registryLine
                $registryFound = $true
            } else {
                $newContent += $line
            }
        }

        if (-not $registryFound) {
            $newContent = @($registryLine) + $newContent
        }

        $newContent | Set-Content -Path $Path -Encoding UTF8
    } else {
        # 新規作成または上書き
        $registryLine | Set-Content -Path $Path -Encoding UTF8
    }

    Write-Output "REMEDIATION: Registry configured to $RegistryUrl"
}

# ============================================
# メイン処理
# ============================================
try {
    Write-Output "REMEDIATION: Starting Takumi Guard configuration"

    # バックアップ
    Backup-Npmrc -Path $Config.NpmrcPath

    # 設定投入
    Set-NpmrcRegistry -Path $Config.NpmrcPath -RegistryUrl $Config.RegistryUrl

    # 検証
    $content = Get-Content $Config.NpmrcPath -Raw
    if ($content -match [regex]::Escape($Config.RegistryUrl)) {
        Write-Output "REMEDIATION SUCCESS: Takumi Guard configured successfully"
        exit 0
    } else {
        Write-Error "REMEDIATION VERIFY FAILED: Configuration not applied correctly"
        exit 1
    }
}
catch {
    Write-Error "REMEDIATION ERROR: $_"
    exit 1
}
