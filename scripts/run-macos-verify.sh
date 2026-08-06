#!/bin/bash
# ============================================================
# macOS E2E verify for Takumi Guard MDM scripts (Jamf Pro / Iru).
# ============================================================
# Verifies the full state transition: broken-shim detect (all skipped) ->
# unconfigured audit/EA -> jamf policy install -> configured audit/EA ->
# jamf uninstall -> reverted audit/EA, then repeats configure/detect/uninstall
# with the Iru macOS install/uninstall scripts.
#
# Two modes, chosen from the console user probe:
#   e2e      : console user is a real login (e.g. runner) -> run full product
#              scripts (which sudo into the console user) end to end.
#   fallback : no console user (root/loginwindow/empty) -> product scripts would
#              bail with Error; instead extract each script's CHILD heredoc body
#              and run the logic directly (sudoless) against the current user.
#
# Product scripts under jamf-pro/ and iru/ are never modified.
# Revert uses the product uninstall scripts; inline revert is only for the
# initial state cleanup.
# ============================================================

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DETECT_SH="$REPO_ROOT/iru/custom-scripts/detect-takumi-guard.sh"
IRU_INSTALL_SH="$REPO_ROOT/iru/custom-scripts/install-takumi-guard-macos.sh"
IRU_UNINSTALL_SH="$REPO_ROOT/iru/custom-scripts/uninstall-takumi-guard-macos.sh"
JAMF_INSTALL_SH="$REPO_ROOT/jamf-pro/policies/install-takumi-guard.sh"
JAMF_UNINSTALL_SH="$REPO_ROOT/jamf-pro/policies/uninstall-takumi-guard.sh"
JAMF_EA_SH="$REPO_ROOT/jamf-pro/extension-attributes/takumi-guard-status.sh"

NPM_EXPECTED="https://npm.flatt.tech"
PIP_EXPECTED="https://pypi.flatt.tech/simple"

CONSOLE_USER="${CONSOLE_USER:-$(stat -f "%Su" /dev/console 2>/dev/null)}"
case "$CONSOLE_USER" in
  ""|root|loginwindow) MODE="fallback" ;;
  *)                   MODE="e2e" ;;
esac

echo "== Takumi Guard macOS verify =="
echo "repo         : $REPO_ROOT"
echo "console user : '${CONSOLE_USER}'"
echo "mode         : $MODE"

# ---------- result tracking ----------
STEP_NAMES=(); STEP_EXPECTED=(); STEP_ACTUAL=(); STEP_STATUS=()
FAIL=0

record() { # name expected actual ok(0/1)
  STEP_NAMES+=("$1"); STEP_EXPECTED+=("$2"); STEP_ACTUAL+=("$3")
  if [ "$4" -eq 0 ]; then STEP_STATUS+=("PASS"); else STEP_STATUS+=("FAIL"); FAIL=$((FAIL+1)); fi
  local s; [ "$4" -eq 0 ] && s="PASS" || s="FAIL"
  echo "[$s] $1 | expected='$2' actual='$3'"
}

assert_exit() { # name actual expected
  if [ "$2" -eq "$3" ]; then record "$1" "exit $3" "exit $2" 0; else record "$1" "exit $3" "exit $2" 1; fi
}

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then record "$1" "$2" "$3" 0; else record "$1" "$2" "$3" 1; fi
}

# ---------- CHILD body extraction ----------
# Pull the heredoc body between <<'CHILD' and the closing CHILD line.
child_body() { sed -n "/<<'CHILD'/,/^CHILD\$/p" "$1" | sed '1d;$d'; }

# ---------- user-context command runners ----------
# In e2e mode, commands must run as the console user (matching the product
# scripts). In fallback mode, run directly. These are used for value assertions
# and for the inline revert, mirroring the install scripts' user context.
run_as_user() { # command...
  if [ "$MODE" = "e2e" ]; then
    sudo -u "$CONSOLE_USER" -H bash -l -c "export PATH=\"\$PATH:/opt/homebrew/bin:/usr/local/bin\"; $*"
  else
    bash -l -c "export PATH=\"\$PATH:/opt/homebrew/bin:/usr/local/bin\"; $*"
  fi
}

npm_registry() { run_as_user 'npm config get registry 2>/dev/null' | tr -d '[:space:]'; }
pip_index()    { run_as_user 'for c in pip3 pip; do command -v "$c" >/dev/null 2>&1 && { "$c" config get global.index-url 2>/dev/null; break; }; done' | tr -d '[:space:]'; }

# Run a detect-style script (iru audit). Returns its exit code.
run_detect() { # script_path
  if [ "$MODE" = "e2e" ]; then
    bash "$1" >/dev/null 2>&1; return $?
  else
    # Run the extracted CHILD logic directly (no sudo, no console-user guard).
    child_body "$1" | bash >/dev/null 2>&1; return $?
  fi
}

# Map a TG_STATUS:<npm>:<pip> line to the EA result string (same rules as the
# EA wrapper). Used to emulate the wrapper in fallback mode.
ea_from_status() { # status_line
  local npm_s pip_s
  npm_s=$(printf '%s' "$1" | cut -d: -f2)
  pip_s=$(printf '%s' "$1" | cut -d: -f3)
  if [ -z "$1" ]; then echo "<result>Error</result>"
  elif [ "$npm_s" = "ng" ] || [ "$pip_s" = "ng" ]; then echo "<result>Not Configured</result>"
  elif [ "$npm_s" = "ok" ] && [ "$pip_s" = "ok" ]; then echo "<result>Configured</result>"
  elif [ "$npm_s" = "ok" ]; then echo "<result>Configured (npm only)</result>"
  elif [ "$pip_s" = "ok" ]; then echo "<result>Configured (pip only)</result>"
  else echo "<result>Not Applicable</result>"
  fi
}

# Run the jamf EA and capture its <result>...</result> output.
run_ea() { # script_path
  if [ "$MODE" = "e2e" ]; then
    bash "$1" 2>/dev/null
  else
    # Emulate the EA wrapper around the extracted CHILD logic (marker line).
    ea_from_status "$(child_body "$1" | bash 2>/dev/null | grep '^TG_STATUS:' | tail -n1)"
  fi
}

# EA assertion: any "Configured" variant counts as configured (pip may be
# legitimately skipped on hosts where it is not usable). "Not Configured"
# does not match the prefix.
assert_ea_configured() { # name actual
  case "$2" in
    "<result>Configured"*) record "$1" "<result>Configured*" "$2" 0 ;;
    *)                     record "$1" "<result>Configured*" "$2" 1 ;;
  esac
}

# Run an install/uninstall script. Returns exit code.
run_install() { # script_path
  if [ "$MODE" = "e2e" ]; then
    bash "$1" >/dev/null 2>&1; return $?
  else
    child_body "$1" | bash >/dev/null 2>&1; return $?
  fi
}
run_uninstall() { run_install "$1"; }

# Inline revert for the INITIAL state cleanup only (scenario reverts use the
# product uninstall scripts), in the same user context the install scripts use.
revert_config() {
  run_as_user 'command -v npm >/dev/null 2>&1 && npm config delete registry >/dev/null 2>&1; for c in pip3 pip; do command -v "$c" >/dev/null 2>&1 && { "$c" config unset global.index-url >/dev/null 2>&1; break; }; done; true'
}

# ============================================================
# Scenario 1: broken-shim / no PM -> detect logic exit 0 (all skipped)
#   Extract the detect CHILD body and run it with a PATH whose npm/pip shims
#   exist but fail --version, so usable() is false and it exits 0.
# ============================================================
SHIMDIR="$(mktemp -d)"
for c in npm pip pip3; do
  cat > "$SHIMDIR/$c" <<'SHIM'
#!/bin/bash
[ "$1" = "--version" ] && { echo "no version set" >&2; exit 1; }
exit 1
SHIM
  chmod +x "$SHIMDIR/$c"
done
BODY="$(child_body "$DETECT_SH")"
# Prepend shim dir so it wins over the homebrew paths the body appends.
PATH="$SHIMDIR:/usr/bin:/bin" bash -c "$BODY" >/dev/null 2>&1
assert_exit "1. detect (broken shim = out of scope, compliant)" $? 0
rm -rf "$SHIMDIR"

# ============================================================
# Scenario 2: unconfigured -> iru audit exit 1 / jamf EA Not Configured
#   Ensure a clean starting state first.
# ============================================================
revert_config
run_detect "$DETECT_SH"; assert_exit "2. iru audit (unconfigured -> flagged; exit 1 is correct)" $? 1
ea="$(run_ea "$JAMF_EA_SH")"; assert_eq "2. jamf EA (unconfigured)" "<result>Not Configured</result>" "$ea"

# ============================================================
# Scenario 3: jamf policy install -> exit 0 + real values
# ============================================================
run_install "$JAMF_INSTALL_SH"; assert_exit "3. jamf install" $? 0
assert_eq "3a. npm registry value" "$NPM_EXPECTED" "$(npm_registry | sed 's:/*$::')"
pipval="$(pip_index | sed 's:/*$::')"
if [ -z "$pipval" ]; then
  # pip may be absent on the runner; treat empty as skipped-compliant.
  record "3b. pip index-url value" "$PIP_EXPECTED or (pip absent)" "(empty/skipped)" 0
else
  assert_eq "3b. pip index-url value" "$PIP_EXPECTED" "$pipval"
fi

# ============================================================
# Scenario 4: configured -> iru audit exit 0 / jamf EA Configured*
# ============================================================
run_detect "$DETECT_SH"; assert_exit "4. iru audit (configured)" $? 0
ea="$(run_ea "$JAMF_EA_SH")"; assert_ea_configured "4. jamf EA (configured)" "$ea"

# ============================================================
# Scenario 5: jamf uninstall script -> exit 0
# ============================================================
run_uninstall "$JAMF_UNINSTALL_SH"; assert_exit "5. jamf uninstall" $? 0

# ============================================================
# Scenario 6: reverted -> iru audit exit 1 / jamf EA Not Configured
# ============================================================
run_detect "$DETECT_SH"; assert_exit "6. iru audit (reverted -> flagged; exit 1 is correct)" $? 1
ea="$(run_ea "$JAMF_EA_SH")"; assert_eq "6. jamf EA (reverted)" "<result>Not Configured</result>" "$ea"

# ============================================================
# Scenario 7: Iru macOS install/uninstall = same logic; one cycle
# ============================================================
run_install "$IRU_INSTALL_SH"; assert_exit "7. iru install (configure)" $? 0
assert_eq "7a. iru npm registry value" "$NPM_EXPECTED" "$(npm_registry | sed 's:/*$::')"
run_detect "$DETECT_SH"; assert_exit "7b. iru audit (configured)" $? 0
ea="$(run_ea "$JAMF_EA_SH")"; assert_ea_configured "7c. jamf EA (iru configured)" "$ea"
run_uninstall "$IRU_UNINSTALL_SH"; assert_exit "7d. iru uninstall" $? 0
run_detect "$DETECT_SH"; assert_exit "7e. iru audit (reverted -> flagged; exit 1 is correct)" $? 1

# ============================================================
# Summary
# ============================================================
echo ""
echo "==========================================="
echo "   MACOS VERIFY SUMMARY (mode=$MODE FAIL=$FAIL)"
echo "==========================================="
for i in "${!STEP_NAMES[@]}"; do
  printf '%-6s %s\n' "${STEP_STATUS[$i]}" "${STEP_NAMES[$i]}"
done

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## macOS verify (mode: $MODE, console user: '${CONSOLE_USER}')"
    echo ""
    if [ "$MODE" = "fallback" ]; then
      echo "> No console user session on the runner; ran in **CHILD-extraction fallback** mode (product-script logic tested sudoless)."
    else
      echo "> Console user present; ran full product scripts **end to end** (sudo into the console user)."
    fi
    echo ""
    echo "| Step | Expected | Actual | Status |"
    echo "|------|----------|--------|--------|"
    for i in "${!STEP_NAMES[@]}"; do
      printf '| %s | %s | %s | %s |\n' "${STEP_NAMES[$i]}" "${STEP_EXPECTED[$i]}" "${STEP_ACTUAL[$i]}" "${STEP_STATUS[$i]}"
    done
    echo ""
    echo "FAIL=$FAIL total=${#STEP_NAMES[@]}"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$FAIL" -gt 0 ]; then
  echo "macOS verify failed ($FAIL step(s))."
  exit 1
fi
echo "macOS verify passed."
exit 0
