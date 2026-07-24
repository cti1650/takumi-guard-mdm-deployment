#!/bin/bash
# ============================================
# Takumi Guard configuration script (Jamf Pro Policy)
# ============================================
# Configures the npm / PyPI registry to Takumi Guard (anonymous mode) using each
# package manager command (npm config set / pip config set), preserving other
# existing settings. Anonymous mode uses fixed values (no Jamf parameters needed).
# Runs as root from a Jamf Policy and targets the console user's settings.
# ============================================

set -uo pipefail

# Takumi Guard anonymous registries (fixed values)
NPM_REGISTRY="https://npm.flatt.tech/"
PYPI_INDEX="https://pypi.flatt.tech/simple/"

# Log to stdout (captured by Jamf policy logs; no separate log file needed)
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
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
# Package manager stderr (e.g. npm config warnings) is captured and shown only on failure.
configure() {
    local label="$1" set_sub="$2"; shift 2
    local bin err
    bin=$(resolve_bin "$@")
    if [[ -z "$bin" ]]; then
        log_message "WARN" "$label not available - skipped"
        return 0
    fi
    if err=$(as_user "$bin $set_sub" 2>&1 >/dev/null); then
        log_message "INFO" "$label configured ($bin)"
        return 0
    fi
    log_message "ERROR" "$label configuration failed: $err"
    return 1
}

main() {
    log_message "INFO" "Starting Takumi Guard configuration"

    if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
        log_message "ERROR" "No valid console user session"
        exit 1
    fi

    local status=0
    configure "npm"  "config set registry '$NPM_REGISTRY'" npm || status=1
    configure "PyPI" "config set global.index-url '$PYPI_INDEX'" pip3 pip || status=1

    if [[ $status -eq 0 ]]; then
        log_message "INFO" "Takumi Guard configuration completed"
        exit 0
    fi

    log_message "ERROR" "Takumi Guard configuration failed"
    exit 1
}

main
