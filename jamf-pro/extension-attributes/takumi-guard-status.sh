#!/bin/bash
# ============================================
# Takumi Guard status (Jamf Pro Extension Attribute)
# ============================================
# Data Type: String / Input Type: Script
# Output values:
#   <result>Configured</result>             all usable PMs point to Takumi Guard
#   <result>Configured (npm only)</result>  npm ok / pip not usable (skipped)
#   <result>Configured (pip only)</result>  pip ok / npm not usable (skipped)
#   <result>Not Applicable</result>         no usable package manager
#   <result>Not Configured</result>         a usable PM does not point to Takumi Guard
#   <result>Error</result>                  no console user session
#
# Checks via "npm config get" / "pip config get" run once as the console user.
# A version-manager shim with no version set (asdf/pyenv/nvm) is "not usable";
# it is reported as a partial state instead of silently passing.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "<result>Error</result>"; exit 0 ;;
esac

# Single sudo. The child prints one machine-readable TG_STATUS line; grep
# filters out any login-shell profile noise.
STATUS_LINE=$(sudo -u "$CONSOLE_USER" -H bash -l 2>/dev/null <<'CHILD' | grep '^TG_STATUS:' | tail -n1
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
usable() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }
val() { "$@" 2>/dev/null | tr -d '[:space:]'; }

npm_s="skip"
if usable npm; then
    v=$(val npm config get registry)
    [ "${v%/}" = "https://npm.flatt.tech" ] && npm_s="ok" || npm_s="ng"
fi

pip_s="skip"
for c in pip3 pip; do
    if usable "$c"; then
        v=$(val "$c" config get global.index-url)
        [ "${v%/}" = "https://pypi.flatt.tech/simple" ] && pip_s="ok" || pip_s="ng"
        break
    fi
done

echo "TG_STATUS:${npm_s}:${pip_s}"
CHILD
)

npm_s=$(printf '%s' "$STATUS_LINE" | cut -d: -f2)
pip_s=$(printf '%s' "$STATUS_LINE" | cut -d: -f3)

if [ -z "$STATUS_LINE" ]; then
    echo "<result>Error</result>"
elif [ "$npm_s" = "ng" ] || [ "$pip_s" = "ng" ]; then
    echo "<result>Not Configured</result>"
elif [ "$npm_s" = "ok" ] && [ "$pip_s" = "ok" ]; then
    echo "<result>Configured</result>"
elif [ "$npm_s" = "ok" ]; then
    echo "<result>Configured (npm only)</result>"
elif [ "$pip_s" = "ok" ]; then
    echo "<result>Configured (pip only)</result>"
else
    echo "<result>Not Applicable</result>"
fi
