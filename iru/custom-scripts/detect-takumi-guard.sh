#!/bin/bash
# ============================================
# Takumi Guard status detection (Iru Audit Script - macOS)
# ============================================
# Exit 0 = Compliant (configured) / Exit 1 = Non-Compliant (not configured)
#
# Checks via "npm config get" / "pip config get" run once as the console user.
# A package manager that is absent or cannot run (e.g. a version-manager shim
# with no version set) is out of scope = compliant.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "NON-COMPLIANT: No console user session"; exit 1 ;;
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
    echo "COMPLIANT: Takumi Guard configured (npm/PyPI)"
    exit 0
fi
echo "NON-COMPLIANT: Takumi Guard not configured"
exit 1
