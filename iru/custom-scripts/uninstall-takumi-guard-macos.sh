#!/bin/bash
# ============================================
# Takumi Guard uninstall (Iru Custom Script - macOS)
# ============================================
# Reverts the npm registry / pip index-url configured by
# install-takumi-guard-macos.sh via "npm config delete" / "pip config unset"
# run once as the console user. Only the managed keys are removed; other
# settings are preserved. Run As: root.
# Same logic as jamf-pro/policies/uninstall-takumi-guard.sh; kept as a
# separate file because each MDM uploads its own copy.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "ERROR: No console user session"; exit 1 ;;
esac

# Single sudo: all revert operations run in one login shell as the console user.
sudo -u "$CONSOLE_USER" -H bash -l <<'CHILD'
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
usable() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }

if usable npm; then
    npm config delete registry >/dev/null 2>&1
    echo "OK: npm reverted"
else
    echo "SKIP: npm not usable"
fi

pip=""
for c in pip3 pip; do usable "$c" && { pip="$c"; break; }; done
if [ -n "$pip" ]; then
    "$pip" config unset global.index-url >/dev/null 2>&1
    echo "OK: pip reverted"
else
    echo "SKIP: pip not usable"
fi
exit 0
CHILD

if [ $? -eq 0 ]; then
    echo "Takumi Guard settings reverted"
    exit 0
fi
echo "Takumi Guard revert failed"
exit 1
