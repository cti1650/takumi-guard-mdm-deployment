#!/bin/bash
# ============================================
# Takumi Guard status detection (Jamf Pro Extension Attribute)
# ============================================
# Data Type: String
# Input Type: Script
#
# Checks whether the npm / PyPI registry points to Takumi Guard (anonymous mode)
# using each package manager command (npm config get / pip config get).
#
# Output:
#   <result>Configured</result>     - npm/PyPI point to Takumi Guard (unusable ones skipped)
#   <result>Not Configured</result> - not configured
#   <result>Error</result>          - no valid console user session
# ============================================

# Takumi Guard anonymous registries (fixed values)
NPM_REGISTRY="https://npm.flatt.tech/"
PYPI_INDEX="https://pypi.flatt.tech/simple/"

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

# No usable command -> out of scope (0). Otherwise compare current value with expected.
check_registry() {
    local get="$1" expected="$2"; shift 2
    local bin current
    bin=$(resolve_bin "$@") || return 0
    current=$(as_user "$bin $get" 2>/dev/null | tr -d '[:space:]')
    [[ "${current%/}" == "${expected%/}" ]]
}

main() {
    if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
        echo "<result>Error</result>"
        exit 0
    fi

    if check_registry "config get registry" "$NPM_REGISTRY" npm \
        && check_registry "config get global.index-url" "$PYPI_INDEX" pip3 pip; then
        echo "<result>Configured</result>"
    else
        echo "<result>Not Configured</result>"
    fi
}

main
