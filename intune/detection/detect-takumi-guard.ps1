<#
.SYNOPSIS
    Takumi Guard インストール状態検出スクリプト (Intune Remediation - Detection)
.DESCRIPTION
    Takumi Guardのインストール状態を検出し、Intune修復スクリプトのトリガー判定を行います。
    Exit 0: 正常（修復不要）
    Exit 1: 異常（修復が必要）
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

    # 期待するレジストリホスト（匿名利用時は空でOK）
    ExpectedRegistryHost = if ($env:TAKUMI_REGISTRY_HOST) { $env:TAKUMI_REGISTRY_HOST } else { "registry.takumi.dev" }

    # 検出モード: "registry" | "proxy" | "both"
    DetectionMode = if ($env:TAKUMI_DETECTION_MODE) { $env:TAKUMI_DETECTION_MODE } else { "registry" }
}

# ============================================
# 検出ロジック
# ============================================
function Test-NpmrcConfiguration {
    param([string]$NpmrcPath, [string]$ExpectedHost)

    if (-not (Test-Path $NpmrcPath)) {
        Write-Output "DETECTION: .npmrc not found at $NpmrcPath"
        return $false
    }

    $content = Get-Content $NpmrcPath -Raw

    # レジストリ設定の確認
    if ($content -match "registry\s*=\s*https?://[^/]*$([regex]::Escape($ExpectedHost))") {
        Write-Output "DETECTION: Takumi Guard registry configured"
        return $true
    }

    Write-Output "DETECTION: Takumi Guard registry not configured"
    return $false
}

function Test-ProxyConfiguration {
    # システムプロキシまたはnpm proxyの設定確認
    $npmProxy = npm config get proxy 2>$null
    $npmHttpsProxy = npm config get https-proxy 2>$null

    if ($npmProxy -or $npmHttpsProxy) {
        Write-Output "DETECTION: Proxy configured - proxy: $npmProxy, https-proxy: $npmHttpsProxy"
        return $true
    }

    return $false
}

# ============================================
# メイン処理
# ============================================
try {
    $isCompliant = $false

    switch ($Config.DetectionMode) {
        "registry" {
            $isCompliant = Test-NpmrcConfiguration -NpmrcPath $Config.NpmrcPath -ExpectedHost $Config.ExpectedRegistryHost
        }
        "proxy" {
            $isCompliant = Test-ProxyConfiguration
        }
        "both" {
            $registryOk = Test-NpmrcConfiguration -NpmrcPath $Config.NpmrcPath -ExpectedHost $Config.ExpectedRegistryHost
            $proxyOk = Test-ProxyConfiguration
            $isCompliant = $registryOk -or $proxyOk
        }
    }

    if ($isCompliant) {
        Write-Output "COMPLIANT: Takumi Guard is properly configured"
        exit 0
    } else {
        Write-Output "NON-COMPLIANT: Takumi Guard configuration required"
        exit 1
    }
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
