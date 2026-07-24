#!/bin/bash
# ============================================
# Takumi Guard configuration script (Iru Custom Script - macOS)
# ============================================
# Configures the npm / PyPI registry to Takumi Guard (anonymous mode) using each
# package manager command (npm config set / pip config set), preserving other
# existing settings.
#
# Execution context: root
#   (targets the console-logged-in user's settings, running as that user)
# ============================================

set -uo pipefail

# Takumi Guard anonymous registries (fixed values)
NPM_REGISTRY="https://npm.flatt.tech/"
PYPI_INDEX="https://pypi.flatt.tech/simple/"
LOG_FILE="/var/log/takumi-guard-iru.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [IRU] [$1] $2" | tee -a "$LOG_FILE"
}

# Console (logged-in) user
CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)

# Run a command in the logged-in user's environment (login shell for PATH)
as_user() {
    sudo -u "$CONSOLE_USER" -H bash -lc "$*"
}

# Return the first *usable* command (whose --version actually runs), or nothing.
# A version-manager shim (asdf/pyenv/nvm) with no version set exists on PATH but
# fails at runtime, so probing --version filters it out.
resolve_bin() {
    local name
    for name in "$@"; do
        if as_user "command -v $name >/dev/null 2>&1 && $name --version >/dev/null 2>&1"; then
            echo "$name"
            return 0
        fi
    done
    return 1
}

# Configure via the first usable command. No usable command -> skipped (0).
configure() {
    local label="$1" set_sub="$2"; shift 2
    local bin
    bin=$(resolve_bin "$@")
    if [[ -z "$bin" ]]; then
        log_message "WARN" "$label not available - skipped"
        return 0
    fi
    if as_user "$bin $set_sub"; then
        log_message "INFO" "$label configured ($bin)"
        return 0
    fi
    log_message "ERROR" "$label configuration failed"
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
    configure "npm"  "config set registry '$NPM_REGISTRY'" npm || status=1
    configure "PyPI" "config set global.index-url '$PYPI_INDEX'" pip3 pip || status=1

    if [[ $status -eq 0 ]]; then
        log_message "COMPLIANCE" "Takumi Guard status: COMPLIANT"
        log_message "INFO" "=== Takumi Guard Installation Complete ==="
        exit 0
    fi

    log_message "COMPLIANCE" "Takumi Guard status: FAILED"
    exit 1
}

main "$@"
