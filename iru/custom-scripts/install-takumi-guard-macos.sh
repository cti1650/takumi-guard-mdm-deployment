#!/bin/bash
# ============================================
# Takumi Guard 設定投入スクリプト (Iru Custom Script - macOS)
# ============================================
# npm / PyPI のレジストリを Takumi Guard（匿名利用）に設定します。
# 各パッケージマネージャーのコマンド (npm config set / pip config set) で設定するため、
# 既存の .npmrc / pip.conf を直接書き換えず、他の設定を保持したまま更新します。
#
# 実行コンテキスト: root
#   （コンソールにログイン中のユーザー設定を対象に、そのユーザー権限で実行します）
# ============================================

set -uo pipefail

# Takumi Guard 匿名利用レジストリ（固定値）
NPM_REGISTRY="https://npm.flatt.tech/"
PYPI_INDEX="https://pypi.flatt.tech/simple/"
LOG_FILE="/var/log/takumi-guard-iru.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IRU] [$1] $2" | tee -a "$LOG_FILE"
}

# コンソールにログイン中のユーザー
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)

# ログインユーザーの環境でコマンドを実行（PATH解決のためログインシェル経由）
as_user() {
    sudo -u "$CONSOLE_USER" -H bash -lc "$*"
}

configure_npm() {
    if ! as_user 'command -v npm >/dev/null 2>&1'; then
        log_message "WARN" "npm not installed - skipped"
        return 0
    fi
    if as_user "npm config set registry '$NPM_REGISTRY'"; then
        log_message "INFO" "npm configured"
        return 0
    fi
    log_message "ERROR" "npm configuration failed"
    return 1
}

configure_pip() {
    local pip_bin
    pip_bin=$(as_user 'command -v pip3 || command -v pip' 2>/dev/null || true)
    if [[ -z "$pip_bin" ]]; then
        log_message "WARN" "pip not installed - skipped"
        return 0
    fi
    if as_user "$pip_bin config set global.index-url '$PYPI_INDEX'"; then
        log_message "INFO" "PyPI configured"
        return 0
    fi
    log_message "ERROR" "PyPI configuration failed"
    return 1
}

main() {
    log_message "INFO" "=== Takumi Guard Installation (Iru macOS) ==="

    if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
        log_message "ERROR" "No valid console user session"
        log_message "COMPLIANCE" "Takumi Guard status: FAILED"
        exit 1
    fi

    local status=0
    configure_npm || status=1
    configure_pip || status=1

    if [[ $status -eq 0 ]]; then
        log_message "COMPLIANCE" "Takumi Guard status: COMPLIANT"
        log_message "INFO" "=== Takumi Guard Installation Complete ==="
        exit 0
    fi

    log_message "COMPLIANCE" "Takumi Guard status: FAILED"
    exit 1
}

main "$@"
