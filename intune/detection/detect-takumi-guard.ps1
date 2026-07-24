<#
.SYNOPSIS
    Takumi Guard インストール状態検出スクリプト (Intune Remediation - Detection)
.DESCRIPTION
    npm / PyPI のレジストリが Takumi Guard（匿名利用）を指しているかを、
    各パッケージマネージャーのコマンド (npm config get / pip config get) で確認します。
    設定ファイルを直接読まないため、意図しない設定の見落としや誤判定を避けます。
    Exit 0: 設定済み（修復不要）
    Exit 1: 未設定（修復が必要）
.NOTES
    MDM: Microsoft Intune
    対象OS: Windows 10/11
    実行コンテキスト: ログオンユーザー
      （Intune の "Run this script using the logged-on credentials" = Yes）
#>

# Takumi Guard 匿名利用レジストリ（固定値）
# 参考: https://shisho.dev/docs/ja/t/guard/quickstart/
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"

# インストール済みのコマンド名を返す（未導入なら $null）
# pip / pip3 はユーザー設定ファイルを共有するため、どちらか片方を解決すれば十分。
function Resolve-Command {
    param([string[]]$Candidates)
    foreach ($name in $Candidates) {
        if (Get-Command $name -ErrorAction SilentlyContinue) { return $name }
    }
    return $null
}

# 未導入は対象外(true)。導入済みなら現在の設定値が期待値と一致するかを返す。
function Test-Registry {
    param([string]$Command, [string[]]$GetArgs, [string]$Expected, [string]$Label)

    if (-not $Command) {
        Write-Output "SKIP: $Label not installed"
        return $true
    }

    $current = (& $Command @GetArgs 2>$null | Out-String).Trim()
    if ($current.TrimEnd('/') -eq $Expected.TrimEnd('/')) {
        Write-Output "OK: $Label -> $current"
        return $true
    }

    Write-Output "NG: $Label -> $current"
    return $false
}

try {
    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    $npmOk = Test-Registry -Command $npm -GetArgs @("config", "get", "registry") -Expected $NpmRegistry -Label "npm"
    $pipOk = Test-Registry -Command $pip -GetArgs @("config", "get", "global.index-url") -Expected $PypiIndex -Label "PyPI"

    if ($npmOk -and $pipOk) {
        Write-Output "COMPLIANT: Takumi Guard is properly configured (npm/PyPI)"
        exit 0
    }

    Write-Output "NON-COMPLIANT: Takumi Guard configuration required"
    exit 1
}
catch {
    Write-Error "DETECTION ERROR: $_"
    exit 1
}
