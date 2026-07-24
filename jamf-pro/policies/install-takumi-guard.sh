#!/bin/bash
# ============================================
# Takumi Guard 設定投入スクリプト (Jamf Pro Policy)
# ============================================
# Jamf Pro Policyから実行されるスクリプト
# Parameter Labels:
#   $4 = Registry URL (required)
#   $5 = Installation Mode: user | global | both (default: user)
#   $6 = Create Backup: true | false (default: true)
# ============================================

# ============================================
# Jamf パラメータ
# ============================================
REGISTRY_URL="${4:-}"
INSTALL_MODE="${5:-user}"
CREATE_BACKUP="${6:-true}"

# ============================================
# ログ
# ============================================
LOG_FILE="/var/log/takumi-guard-install.log"

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# ============================================
# 検証
# ============================================
if [[ -z "$REGISTRY_URL" ]]; then
    log_message "ERROR" "Registry URL is required (Parameter 4)"
    log_message "ERROR" "Set the registry URL in Jamf Pro Policy parameters"
    exit 1
fi

# ============================================
# ユーザー検出
# ============================================
get_current_user() {
    stat -f "%Su" /dev/console
}

get_user_home() {
    local user="$1"
    dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

get_user_uid() {
    local user="$1"
    id -u "$user" 2>/dev/null
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
        # 既存のregistry行を削除して新しい設定を追加
        local temp_file
        temp_file=$(mktemp)
        grep -v "^registry=" "$npmrc_path" > "$temp_file" 2>/dev/null || true
        echo "$registry_line" | cat - "$temp_file" > "$npmrc_path"
        rm -f "$temp_file"
    else
        # 新規作成
        echo "$registry_line" > "$npmrc_path"
    fi

    # 所有者設定
    if [[ -n "$owner" ]] && [[ "$owner" != "root" ]]; then
        chown "$owner" "$npmrc_path"
    fi

    chmod 644 "$npmrc_path"
    log_message "INFO" "Configured: $npmrc_path"
}

# ============================================
# メイン処理
# ============================================
main() {
    log_message "INFO" "Starting Takumi Guard configuration"
    log_message "INFO" "Install mode: $INSTALL_MODE"

    local current_user
    local user_home
    local success=true

    current_user=$(get_current_user)
    user_home=$(get_user_home "$current_user")

    case "$INSTALL_MODE" in
        user)
            if [[ -z "$current_user" ]] || [[ "$current_user" == "root" ]]; then
                log_message "ERROR" "No valid user session found"
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
            exit 1
            ;;
    esac

    log_message "INFO" "Takumi Guard configuration completed"
    exit 0
}

main
