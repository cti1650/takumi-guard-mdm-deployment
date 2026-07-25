#!/bin/bash
# ============================================
# Takumi Guard status (Jamf Pro Extension Attribute)
# ============================================
# Data Type: String / Input Type: Script
# Output: <result>Configured</result> / <result>Not Configured</result> / <result>Error</result>
#
# Checks via "npm config get" / "pip config get" run once as the console user.
# A package manager that is absent or cannot run (e.g. a version-manager shim
# with no version set) is out of scope = configured.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "<result>Error</result>"; exit 0 ;;
esac

# Single sudo: all checks run in one login shell as the console user.
sudo -u "$CONSOLE_USER" -H bash -l >/dev/null 2>&1 <<'CHILD'
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
usable() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }
val() { "$@" 2>/dev/null | tr -d '[:space:]'; }

if usable npm; then
    v=$(val npm config get registry)
    [ "${v%/}" = "https://npm.flatt.tech" ] || exit 1
fi

pip=""
for c in pip3 pip; do usable "$c" && { pip="$c"; break; }; done
if [ -n "$pip" ]; then
    v=$(val "$pip" config get global.index-url)
    [ "${v%/}" = "https://pypi.flatt.tech/simple" ] || exit 1
fi
exit 0
CHILD

if [ $? -eq 0 ]; then
    echo "<result>Configured</result>"
else
    echo "<result>Not Configured</result>"
fi
