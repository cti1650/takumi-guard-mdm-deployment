<#
.SYNOPSIS
    Takumi Guard 設定投入スクリプト (Intune Remediation - Remediation)
.DESCRIPTION
    npm / PyPI のレジストリを Takumi Guard（匿名利用）に設定します。
    各パッケージマネージャーのコマンド (npm config set / pip config set) で設定するため、
    既存の .npmrc / pip.ini を直接書き換えず、他の設定を保持したまま更新します。
.NOTES
    MDM: Microsoft Intune
    対象OS: Windows 10/11
    実行コンテキスト: ログオンユーザー
#>

# Takumi Guard 匿名利用レジストリ（固定値）
# 参考: https://shisho.dev/docs/ja/t/guard/quickstart/
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"

# インストール済みのコマンド名を返す（未導入なら $null）
function Resolve-Command {
    param([string[]]$Candidates)
    foreach ($name in $Candidates) {
        if (Get-Command $name -ErrorAction SilentlyContinue) { return $name }
    }
    return $null
}

function Set-Registry {
    param([string]$Command, [string[]]$SetArgs, [string]$Label)

    if (-not $Command) {
        Write-Output "SKIP: $Label not installed"
        return
    }

    & $Command @SetArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$Label configuration failed (exit $LASTEXITCODE)"
    }
    Write-Output "SET: $Label configured"
}

try {
    Write-Output "REMEDIATION: Starting Takumi Guard configuration"

    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    Set-Registry -Command $npm -SetArgs @("config", "set", "registry", $NpmRegistry) -Label "npm"
    Set-Registry -Command $pip -SetArgs @("config", "set", "global.index-url", $PypiIndex) -Label "PyPI"

    Write-Output "REMEDIATION SUCCESS: Takumi Guard configured"
    exit 0
}
catch {
    Write-Error "REMEDIATION ERROR: $_"
    exit 1
}
