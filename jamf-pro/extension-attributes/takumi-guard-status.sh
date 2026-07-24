#!/bin/bash
# ============================================
# Takumi Guard ステータス検出 (Jamf Pro Extension Attribute)
# ============================================
# Data Type: String
# Input Type: Script
#
# 出力値:
#   - "Configured" : Takumi Guard設定済み
#   - "Not Configured" : 未設定
#   - "Partial" : 一部設定済み
#   - "Error" : 検出エラー
# ============================================

# ============================================
# 設定
# ============================================
# 期待するレジストリホスト
EXPECTED_REGISTRY_HOST="${TAKUMI_REGISTRY_HOST:-registry.takumi.dev}"

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

# ============================================
# 検出ロジック
# ============================================
check_npmrc_config() {
    local npmrc_path="$1"

    if [[ ! -f "$npmrc_path" ]]; then
        echo "not_found"
        return
    fi

    if grep -q "registry.*${EXPECTED_REGISTRY_HOST}" "$npmrc_path" 2>/dev/null; then
        echo "configured"
    else
        echo "not_configured"
    fi
}

# ============================================
# メイン処理
# ============================================
main() {
    local current_user
    local user_home
    local user_npmrc_status
    local global_npmrc_status

    current_user=$(get_current_user)

    if [[ -z "$current_user" ]] || [[ "$current_user" == "root" ]]; then
        echo "<result>Error</result>"
        exit 0
    fi

    user_home=$(get_user_home "$current_user")

    # ユーザー.npmrc確認
    user_npmrc_status=$(check_npmrc_config "$user_home/.npmrc")

    # グローバル.npmrc確認（/usr/local/etc/npmrc）
    global_npmrc_status=$(check_npmrc_config "/usr/local/etc/npmrc")

    # 判定
    if [[ "$user_npmrc_status" == "configured" ]] || [[ "$global_npmrc_status" == "configured" ]]; then
        echo "<result>Configured</result>"
    elif [[ "$user_npmrc_status" == "not_found" ]] && [[ "$global_npmrc_status" == "not_found" ]]; then
        echo "<result>Not Configured</result>"
    else
        echo "<result>Not Configured</result>"
    fi
}

main
