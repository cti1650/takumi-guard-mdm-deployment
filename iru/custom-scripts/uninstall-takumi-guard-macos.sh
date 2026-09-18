#!/bin/bash
# ============================================
# Takumi Guard uninstall (Iru Custom Script - macOS)
# ============================================
# Reverts the npm registry / pip index-url configured by
# install-takumi-guard-macos.sh via "npm config delete" / "pip config unset"
# run once as the console user. Only the managed keys are removed; other
# settings are preserved.
#
# Iru always runs macOS custom scripts as root, so the revert must be handed to
# the console user's own session (see run_as_console_user below); npm / pip
# settings are per-user and root's are not the ones that were configured.
# ============================================

# Apple's documented source for the GUI session owner. /dev/console is kept as
# a fallback for the rare case where the dynamic store lookup returns nothing.
CONSOLE_USER=$(echo "show State:/Users/ConsoleUser" | scutil 2>/dev/null \
    | awk '/[[:space:]]Name[[:space:]]*:/ { print $3 }')
[ -n "$CONSOLE_USER" ] || CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "ERROR: No console user session"; exit 1 ;;
esac

CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null)
if [ -z "$CONSOLE_UID" ]; then
    echo "ERROR: Could not resolve console user UID"
    exit 1
fi

# The user's real login shell, so a login shell picks up the profile that
# actually configures their PATH (zsh since Catalina, not bash). Anything
# outside the POSIX-compatible family would not understand the child script,
# so fall back to the macOS default shell.
USER_SHELL=$(dscl . -read "/Users/$CONSOLE_USER" UserShell 2>/dev/null | awk '{ print $2 }')
case "$USER_SHELL" in
    */zsh|*/bash|*/sh|*/ksh) [ -x "$USER_SHELL" ] || USER_SHELL="" ;;
    *) USER_SHELL="" ;;
esac
[ -n "$USER_SHELL" ] || USER_SHELL="/bin/zsh"

# Enter the console user's GUI (Aqua) session rather than only switching uid:
# the child runs a login shell, i.e. arbitrary profile code, and profile code
# that touches the per-user launchd domain or Keychain fails outside it.
# The non-root branches keep the script runnable standalone (CI / manual test).
run_as_console_user() { # command...
    if [ "$(id -u)" -eq 0 ]; then
        launchctl asuser "$CONSOLE_UID" sudo -u "$CONSOLE_USER" -H "$@"
    elif [ "$(id -un)" = "$CONSOLE_USER" ]; then
        "$@"
    else
        sudo -u "$CONSOLE_USER" -H "$@"
    fi
}

# The child is passed as a file, not on stdin: profile code that reads stdin
# would otherwise swallow the script body.
CHILD_SCRIPT=$(mktemp /var/tmp/takumi-guard-uninstall.XXXXXX) || {
    echo "ERROR: Could not create work file"
    exit 1
}
trap 'rm -f "$CHILD_SCRIPT"' EXIT

cat > "$CHILD_SCRIPT" <<'CHILD'
# Load the interactive rc as well. nvm / fnm / asdf installers append their
# PATH setup to ~/.zshrc (or ~/.bashrc), which a login shell alone never reads,
# and a package manager we cannot see would keep the Takumi Guard setting.
if [ -n "${ZSH_VERSION:-}" ]; then
    [ -r "$HOME/.zshrc" ] && . "$HOME/.zshrc" >/dev/null 2>&1
elif [ -n "${BASH_VERSION:-}" ]; then
    [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc" >/dev/null 2>&1
fi
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

# Marker line: the verdict travels on stdout because launchctl asuser is not a
# reliable carrier for a child exit code. The exit code is still set so the
# CHILD body stays usable standalone (CI fallback mode extracts and runs it).
echo "TG_RESULT:0"
exit 0
CHILD
chmod 644 "$CHILD_SCRIPT"

CHILD_OUT=$(run_as_console_user "$USER_SHELL" -l "$CHILD_SCRIPT" </dev/null 2>/dev/null)

# Report only our own lines; login-shell profile noise is dropped. Matching is
# not anchored to the start of the line: shell integration in the user's rc
# (iTerm2 / Warp / VS Code) wraps every line of output in escape sequences.
printf '%s\n' "$CHILD_OUT" | grep -Eo '(OK|SKIP|ERROR):.*'

case "$(printf '%s\n' "$CHILD_OUT" | sed -n 's/.*TG_RESULT:\([0-9]\).*/\1/p' | tail -n 1)" in
    0)
        echo "Takumi Guard settings reverted"
        exit 0 ;;
    *)
        echo "Takumi Guard revert failed"
        exit 1 ;;
esac
