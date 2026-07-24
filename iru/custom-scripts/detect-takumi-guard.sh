#!/bin/bash
# ============================================
# Takumi Guard ステータス検出 (Iru Audit Script - macOS)
# ============================================
# Iru (旧Kandji) のAudit Scriptとして使用
# Blueprint > Audit & Remediation で設定
#
# 終了コード:
#   0 = Compliant (設定済み)
#   1 = Non-Compliant (未設定)
# ============================================

# ============================================
# 設定
# ============================================
EXPECTED_REGISTRY_HOST="${TAKUMI_REGISTRY_HOST:-registry.takumi.dev}"

# ============================================
# ユーザー検出
# ============================================
get_current_user() {
    stat -f "%Su" /dev/console 2>/dev/null
}

get_user_home() {
    local user="$1"
    dscl . -read "/Users/$user" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

# ============================================
# 検出ロジック
# ============================================
check_npmrc() {
    local npmrc_path="$1"

    if [[ ! -f "$npmrc_path" ]]; then
        return 1
    fi

    if grep -q "registry.*${EXPECTED_REGISTRY_HOST}" "$npmrc_path" 2>/dev/null; then
        return 0
    fi

    return 1
}

# ============================================
# メイン処理
# ============================================
main() {
    local current_user
    local user_home

    current_user=$(get_current_user)
    user_home=$(get_user_home "$current_user")

    # ユーザー.npmrc確認
    if check_npmrc "$user_home/.npmrc"; then
        echo "COMPLIANT: User .npmrc configured with Takumi Guard"
        exit 0
    fi

    # グローバル.npmrc確認
    if check_npmrc "/usr/local/etc/npmrc"; then
        echo "COMPLIANT: Global npmrc configured with Takumi Guard"
        exit 0
    fi

    echo "NON-COMPLIANT: Takumi Guard not configured"
    exit 1
}

main
