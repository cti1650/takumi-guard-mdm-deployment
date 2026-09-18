#!/bin/bash
# ============================================
# Takumi Guard uninstall (Jamf Pro Policy)
# ============================================
# Reverts the npm registry / pip index-url configured by install-takumi-guard.sh
# via "npm config delete" / "pip config unset" run once as the console user.
# Only the managed keys are removed; other settings are preserved.
# A package manager that is absent or cannot run is skipped.
# ============================================

CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "ERROR: No console user session"; exit 1 ;;
esac

# Single sudo: all revert operations run in one login shell as the console user.
sudo -u "$CONSOLE_USER" -H bash -l <<'CHILD'
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
# /usr/bin/pip3 can be an xcode-select stub: probing one with --version is what
# pops the developer-tools install dialog at the console user. See
# docs/design.md#command-line-tools-のスタブ回避 for why the check is this shape.
usable() {
    tg_cmd_path=$(command -v "$1" 2>/dev/null) || return 1
    case "$tg_cmd_path" in
        /usr/bin/pip3|/usr/bin/pip)
            tg_dev_dir=${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p 2>/dev/null)}
            [ -n "$tg_dev_dir" ] && [ -d "$tg_dev_dir" ] || return 1 ;;
    esac
    "$1" --version >/dev/null 2>&1
}

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

# shellcheck disable=SC2181  # the command above is a heredoc-fed sudo, which
# cannot be placed inside "if" without splitting the CHILD body.
if [ $? -eq 0 ]; then
    echo "Takumi Guard settings reverted"
    exit 0
fi
echo "Takumi Guard revert failed"
exit 1
