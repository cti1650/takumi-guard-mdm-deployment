#!/bin/bash
# ============================================
# Takumi Guard status detection (Iru Audit Script - macOS)
# ============================================
# Exit 0 = Compliant (configured) / Exit 1 = Non-Compliant (not configured)
#
# Iru always runs macOS custom scripts as root, so the check must be handed to
# the console user's own session (see run_as_console_user below); npm / pip
# settings are per-user and root's values are meaningless here.
#
# Checks via "npm config get" / "pip config get" run once as the console user.
# A package manager that is absent or cannot run (e.g. a version-manager shim
# with no version set) is out of scope = compliant.
# ============================================

# Apple's documented source for the GUI session owner. /dev/console is kept as
# a fallback for the rare case where the dynamic store lookup returns nothing.
CONSOLE_USER=$(echo "show State:/Users/ConsoleUser" | scutil 2>/dev/null \
    | awk '/[[:space:]]Name[[:space:]]*:/ { print $3 }')
[ -n "$CONSOLE_USER" ] || CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null)
case "$CONSOLE_USER" in
    ""|root|loginwindow) echo "NON-COMPLIANT: No console user session"; exit 1 ;;
esac

CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null)
if [ -z "$CONSOLE_UID" ]; then
    echo "NON-COMPLIANT: Could not resolve console user UID"
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
CHILD_SCRIPT=$(mktemp /var/tmp/takumi-guard-detect.XXXXXX) || {
    echo "NON-COMPLIANT: Could not create work file"
    exit 1
}
trap 'rm -f "$CHILD_SCRIPT"' EXIT

# The child reports a per-package-manager state (ok / needs / skip) on a
# marker line; login-shell noise on stdout is ignored by the marker grep.
cat > "$CHILD_SCRIPT" <<'CHILD'
# Load the interactive rc as well. nvm / fnm / asdf installers append their
# PATH setup to ~/.zshrc (or ~/.bashrc), which a login shell alone never reads,
# and a package manager we cannot see would be silently reported as skipped.
if [ -n "${ZSH_VERSION:-}" ]; then
    [ -r "$HOME/.zshrc" ] && . "$HOME/.zshrc" >/dev/null 2>&1
elif [ -n "${BASH_VERSION:-}" ]; then
    [ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc" >/dev/null 2>&1
fi
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
chmod 644 "$CHILD_SCRIPT"

CHILD_OUT=$(run_as_console_user "$USER_SHELL" -l "$CHILD_SCRIPT" </dev/null 2>/dev/null)

# Values are pulled out of the line rather than matched from its start: shell
# integration in the user's rc (iTerm2 / Warp / VS Code) wraps every line of
# output in escape sequences, so a "^TG_STATE" anchor never matches.
NPM=$(printf '%s\n' "$CHILD_OUT" | sed -n 's/.*npm=\([a-z][a-z]*\).*/\1/p' | tail -n 1)
PIP=$(printf '%s\n' "$CHILD_OUT" | sed -n 's/.*pip=\([a-z][a-z]*\).*/\1/p' | tail -n 1)
if [ -z "$NPM" ] || [ -z "$PIP" ]; then
    echo "NON-COMPLIANT: audit could not run as console user"
    exit 1
fi

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
