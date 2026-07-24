#!/bin/bash
# ============================================
# Takumi Guard ステータス検出 (Jamf Pro Extension Attribute)
# ============================================
# Data Type: String
# Input Type: Script
#
# npm / PyPI のレジストリが Takumi Guard（匿名利用）を指しているかを、
# 各パッケージマネージャーのコマンド (npm config get / pip config get) で確認します。
#
# 出力値:
#   - "Configured"     : npm/PyPI とも Takumi Guard 設定済み（未導入のものは対象外）
#   - "Not Configured" : 未設定
#   - "Error"          : ログインユーザー未検出などの検出エラー
# ============================================

# Takumi Guard 匿名利用レジストリ（固定値）
NPM_REGISTRY="https://npm.flatt.tech/"
PYPI_INDEX="https://pypi.flatt.tech/simple/"

# コンソールにログイン中のユーザー
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)

# ログインユーザーの環境でコマンドを実行
as_user() {
    sudo -u "$CONSOLE_USER" -H bash -lc "$*"
}

# 未導入は対象外(0)。導入済みは現在値が期待値と一致すれば 0、不一致で 1。
check_registry() {
    local resolve="$1" get="$2" expected="$3"
    local bin current
    bin=$(as_user "$resolve" 2>/dev/null || true)
    [[ -z "$bin" ]] && return 0
    current=$(as_user "$bin $get" 2>/dev/null | tr -d '[:space:]')
    [[ "${current%/}" == "${expected%/}" ]]
}

main() {
    if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
        echo "<result>Error</result>"
        exit 0
    fi

    if check_registry "command -v npm" "config get registry" "$NPM_REGISTRY" \
        && check_registry "command -v pip3 || command -v pip" "config get global.index-url" "$PYPI_INDEX"; then
        echo "<result>Configured</result>"
    else
        echo "<result>Not Configured</result>"
    fi
}

main
