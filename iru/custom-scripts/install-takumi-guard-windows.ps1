<#
.SYNOPSIS
    Takumi Guard 設定投入スクリプト (Iru Custom Script - Windows)
.DESCRIPTION
    npm / PyPI のレジストリを Takumi Guard（匿名利用）に設定します。
    各パッケージマネージャーのコマンドで設定するため、既存設定を保持します。
.NOTES
    MDM: Iru
    対象OS: Windows 10/11
    実行コンテキスト: ログオンユーザー
      （ユーザーの npm/pip 設定を対象とするため、ユーザーコンテキストで実行してください）
#>

# Takumi Guard 匿名利用レジストリ（固定値）
$NpmRegistry = "https://npm.flatt.tech/"
$PypiIndex   = "https://pypi.flatt.tech/simple/"
$LogFile     = "$env:ProgramData\Iru\Logs\takumi-guard.log"

function Write-Log {
    param([string]$Level, [string]$Message)
    $dir = Split-Path $LogFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $entry = "[{0}] [IRU] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    Write-Output $entry
}

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
        Write-Log "WARN" "$Label not installed - skipped"
        return
    }
    & $Command @SetArgs
    if ($LASTEXITCODE -ne 0) { throw "$Label configuration failed (exit $LASTEXITCODE)" }
    Write-Log "INFO" "$Label configured"
}

try {
    Write-Log "INFO" "=== Takumi Guard Installation (Iru Windows) ==="

    $npm = Resolve-Command @("npm")
    $pip = Resolve-Command @("pip", "pip3")

    Set-Registry -Command $npm -SetArgs @("config", "set", "registry", $NpmRegistry) -Label "npm"
    Set-Registry -Command $pip -SetArgs @("config", "set", "global.index-url", $PypiIndex) -Label "PyPI"

    Write-Log "COMPLIANCE" "Takumi Guard status: COMPLIANT"
    Write-Log "INFO" "=== Takumi Guard Installation Complete ==="
    exit 0
}
catch {
    Write-Log "ERROR" $_.Exception.Message
    Write-Log "COMPLIANCE" "Takumi Guard status: FAILED"
    exit 1
}
