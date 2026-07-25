#!/bin/bash
# ============================================
# Takumi Guard configuration (Jamf Pro Policy)
# ============================================
# Sets npm registry / pip index-url to Takumi Guard (anonymous, fixed values)
# via "npm config set" / "pip config set" run once as the console user, so
# existing settings are preserved. No Jamf parameters required.
# A package manager that is absent or cannot run is skipped.
# Package manager warnings are shown only when a command fails.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "ERROR: No console user session"; exit 1 ;;
esac

# Single sudo: all configuration runs in one login shell as the console user.
sudo -u "$CONSOLE_USER" -H bash -l <<'CHILD'
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
usable() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }

status=0

if usable npm; then
    if out=$(npm config set registry https://npm.flatt.tech/ 2>&1); then
        echo "OK: npm configured"
    else
        echo "ERROR: npm failed: $out"
        status=1
    fi
else
    echo "SKIP: npm not usable"
fi

pip=""
for c in pip3 pip; do usable "$c" && { pip="$c"; break; }; done
if [ -n "$pip" ]; then
    if out=$("$pip" config set global.index-url https://pypi.flatt.tech/simple/ 2>&1); then
        echo "OK: pip configured"
    else
        echo "ERROR: pip failed: $out"
        status=1
    fi
else
    echo "SKIP: pip not usable"
fi

exit $status
CHILD

if [ $? -eq 0 ]; then
    echo "Takumi Guard configuration completed"
    exit 0
fi
echo "Takumi Guard configuration failed"
exit 1
