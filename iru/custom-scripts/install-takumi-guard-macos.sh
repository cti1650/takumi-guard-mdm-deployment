#!/bin/bash
# ============================================
# Takumi Guard 設定投入スクリプト (Iru Custom Script - macOS)
# ============================================
# Iru (旧Kandji) のカスタムスクリプトとして実行
# Self Service または Auto App として配布可能
#
# 環境変数で設定を制御:
#   TAKUMI_REGISTRY_URL : レジストリURL (必須)
#   TAKUMI_INSTALL_MODE : user | global | both (デフォルト: user)
#   TAKUMI_CREATE_BACKUP : true | false (デフォルト: true)
# ============================================

set -euo pipefail

# ============================================
# 設定
# ============================================
REGISTRY_URL="${TAKUMI_REGISTRY_URL:-}"
INSTALL_MODE="${TAKUMI_INSTALL_MODE:-user}"
CREATE_BACKUP="${TAKUMI_CREATE_BACKUP:-true}"
LOG_FILE="/var/log/takumi-guard-iru.log"

# ============================================
# ログ
# ============================================
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [IRU] [$level] $message" | tee -a "$LOG_FILE"
}

# ============================================
# 検証
# ============================================
validate_config() {
    if [[ -z "$REGISTRY_URL" ]]; then
        log_message "ERROR" "TAKUMI_REGISTRY_URL environment variable is required"
        log_message "ERROR" "Configure this in Iru Blueprint > Custom Script > Environment Variables"
        exit 1
    fi
}

# ============================================
# ユーザー検出 (Iruコンテキスト対応)
# ============================================
get_current_user() {
    # Iru実行コンテキストでのユーザー検出
    if [[ -n "${USER:-}" ]] && [[ "$USER" != "root" ]]; then
        echo "$USER"
    else
        stat -f "%Su" /dev/console 2>/dev/null || echo ""
    fi
}

get_user_home() {
    local user="$1"
    dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

# ============================================
# バックアップ処理
# ============================================
backup_file() {
    local file_path="$1"

    if [[ -f "$file_path" ]] && [[ "$CREATE_BACKUP" == "true" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_path="${file_path}.backup_${timestamp}"
        cp "$file_path" "$backup_path"
        log_message "INFO" "Backup created: $backup_path"
    fi
}

# ============================================
# 設定投入処理
# ============================================
configure_npmrc() {
    local npmrc_path="$1"
    local owner="$2"
    local registry_line="registry=${REGISTRY_URL}"

    backup_file "$npmrc_path"

    if [[ -f "$npmrc_path" ]]; then
        local temp_file
        temp_file=$(mktemp)
        grep -v "^registry=" "$npmrc_path" > "$temp_file" 2>/dev/null || true
        echo "$registry_line" | cat - "$temp_file" > "$npmrc_path"
        rm -f "$temp_file"
    else
        echo "$registry_line" > "$npmrc_path"
    fi

    if [[ -n "$owner" ]] && [[ "$owner" != "root" ]]; then
        chown "$owner" "$npmrc_path"
    fi
    chmod 644 "$npmrc_path"

    log_message "INFO" "Configured: $npmrc_path"
}

# ============================================
# Iru Audit Log (Compliance)
# ============================================
report_compliance() {
    local status="$1"
    # Iruのコンプライアンスログに記録
    log_message "COMPLIANCE" "Takumi Guard status: $status"
}

# ============================================
# メイン処理
# ============================================
main() {
    log_message "INFO" "=== Takumi Guard Installation (Iru) ==="
    log_message "INFO" "Install mode: $INSTALL_MODE"

    validate_config

    local current_user
    local user_home

    current_user=$(get_current_user)
    user_home=$(get_user_home "$current_user")

    case "$INSTALL_MODE" in
        user)
            if [[ -z "$current_user" ]] || [[ "$current_user" == "root" ]]; then
                log_message "ERROR" "No valid user session found for user-mode installation"
                report_compliance "FAILED"
                exit 1
            fi
            configure_npmrc "$user_home/.npmrc" "$current_user"
            ;;
        global)
            mkdir -p /usr/local/etc
            configure_npmrc "/usr/local/etc/npmrc" "root"
            ;;
        both)
            mkdir -p /usr/local/etc
            configure_npmrc "/usr/local/etc/npmrc" "root"
            if [[ -n "$current_user" ]] && [[ "$current_user" != "root" ]]; then
                configure_npmrc "$user_home/.npmrc" "$current_user"
            fi
            ;;
        *)
            log_message "ERROR" "Invalid install mode: $INSTALL_MODE"
            report_compliance "FAILED"
            exit 1
            ;;
    esac

    report_compliance "COMPLIANT"
    log_message "INFO" "=== Takumi Guard Installation Complete ==="
    exit 0
}

main "$@"
