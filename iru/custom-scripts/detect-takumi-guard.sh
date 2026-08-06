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
# The child reports a per-package-manager state (ok / needs / skip) on a
# marker line; login-shell noise on stdout is ignored by the marker grep.
CHILD_OUT=$(sudo -u "$CONSOLE_USER" -H bash -l 2>/dev/null <<'CHILD'
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
usable() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }
val() { "$@" 2>/dev/null | tr -d '[:space:]'; }

n=skip
if usable npm; then
    v=$(val npm config get registry)
    if [ "${v%/}" = "https://npm.flatt.tech" ]; then n=ok; else n=needs; fi
fi

pip=""
for c in pip3 pip; do usable "$c" && { pip="$c"; break; }; done
p=skip
if [ -n "$pip" ]; then
    v=$(val "$pip" config get global.index-url)
    if [ "${v%/}" = "https://pypi.flatt.tech/simple" ]; then p=ok; else p=needs; fi
fi
echo "TG_STATE npm=$n pip=$p"
# Exit code keeps the original audit semantics (0 = compliant) so the CHILD
# body remains usable standalone (CI fallback mode extracts and runs it).
# Balanced-paren case pattern: macOS bash 3.2 cannot parse an unbalanced
# ")" inside $(...) command substitution.
case "$n$p" in (*needs*) exit 1 ;; esac
exit 0
CHILD
)

STATE=$(printf '%s\n' "$CHILD_OUT" | grep '^TG_STATE ' | tail -n 1)
if [ -z "$STATE" ]; then
    echo "NON-COMPLIANT: audit could not run as console user"
    exit 1
fi
NPM=${STATE#*npm=}; NPM=${NPM%% *}
PIP=${STATE#*pip=}

# Same status vocabulary as the Jamf extension attribute, so skips
# ("out of scope = compliant") are visible in the verdict line.
NEEDS=""
[ "$NPM" = "needs" ] && NEEDS="npm"
[ "$PIP" = "needs" ] && NEEDS="${NEEDS:+$NEEDS, }pip"
if [ -n "$NEEDS" ]; then
    echo "NON-COMPLIANT: Not Configured ($NEEDS)"
    exit 1
fi
if [ "$NPM" = "ok" ] && [ "$PIP" = "ok" ]; then STATUS="Configured"
elif [ "$NPM" = "ok" ]; then STATUS="Configured (npm only; pip not usable)"
elif [ "$PIP" = "ok" ]; then STATUS="Configured (pip only; npm not usable)"
else STATUS="Not Applicable (no usable package manager)"
fi
echo "COMPLIANT: $STATUS"
exit 0
