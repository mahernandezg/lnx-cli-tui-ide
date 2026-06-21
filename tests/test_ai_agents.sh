#!/usr/bin/env bash
# tests/test_ai_agents.sh — hermetic, mutation-verified suite for the AI-agents
# protection module (modules/05-ai-agents.sh).
#
# It drives the module against a CONTROLLED PATH containing only fake agent shims
# plus coreutils, so the real agents on the machine are invisible and nothing is
# ever installed (DRY_RUN=1). It asserts:
#   - all agents present        -> every one recorded PRESENT
#   - one agent missing         -> it is detected (NOTE "would restore"), rest PRESENT
#   - the REAL binary name      -> a stale alias ("antigravity") is NOT accepted for agy
# Mutation check: if the module looked for the wrong binary name, case A's PRESENT
# assertions would fail.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT
mkdir -p "$TMP/logs"

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

AGENTS="pi codex claude agy grok copilot"

# Build a shim dir holding the named fake agents (each answers --version).
_mk_bindir() {
  local dir="$1"; shift
  rm -rf "$dir"; mkdir -p "$dir"
  local a
  for a in "$@"; do
    printf '#!/bin/sh\necho "%s 9.9.9"\n' "$a" >"$dir/$a"
    chmod +x "$dir/$a"
  done
}

# Run the module with PATH = shim dir + coreutils only, DRY_RUN=1, writing outcomes
# to $2. Real agents (in /usr/local/bin, ~/.local/bin) are excluded from PATH.
_run() {
  local bindir="$1" out="$2"
  : >"$out"
  PATH="$bindir:/usr/bin:/bin" DRY_RUN=1 REPO_ROOT="$ROOT" LOG_DIR="$TMP/logs" \
  OUTCOME_FILE="$out" HOME="$TMP/home" bash -c '
    set -uo pipefail
    # shellcheck disable=SC1090,SC1091
    . "$REPO_ROOT/lib/log.sh"
    . "$REPO_ROOT/lib/detect.sh"
    . "$REPO_ROOT/lib/fallback.sh"
    . "$REPO_ROOT/lib/outcome.sh"
    log_init >/dev/null 2>&1 || true
    . "$REPO_ROOT/modules/05-ai-agents.sh"
  ' >/dev/null 2>&1
}

# status_of <binary> <ledger> -> prints the recorded status (PRESENT/NOTE/DEFERRED), or nothing.
status_of() { awk -F '\t' -v b="$2" '$2==b{print $1; exit}' "$1"; }

LEDGER="$TMP/out.tsv"
BIN="$TMP/bin"

# ---- Case A: all six agents present ----------------------------------------
# shellcheck disable=SC2086
_mk_bindir "$BIN" $AGENTS
_run "$BIN" "$LEDGER"
a_ok=1
for a in $AGENTS; do
  [[ "$(status_of "$LEDGER" "$a")" == "PRESENT" ]] || { a_ok=0; _fail "A: $a should be PRESENT (got '$(status_of "$LEDGER" "$a")')"; }
done
[[ "$a_ok" -eq 1 ]] && _pass "A: all six agents detected PRESENT (real binary names)"

# ---- Case B: pi missing -> detected, others still PRESENT -------------------
_mk_bindir "$BIN" codex claude agy grok copilot
_run "$BIN" "$LEDGER"
pi_status="$(status_of "$LEDGER" pi)"
if [[ "$pi_status" == "NOTE" ]]; then
  _pass "B: missing pi detected (NOTE 'would restore' under --dry-run)"
else
  _fail "B: missing pi not flagged as restorable (got '$pi_status')"
fi
if [[ "$(status_of "$LEDGER" codex)" == "PRESENT" && "$(status_of "$LEDGER" copilot)" == "PRESENT" ]]; then
  _pass "B: the other agents stay PRESENT"
else
  _fail "B: other agents not PRESENT"
fi
if grep -q $'\tpi\t' "$LEDGER" && ! grep -q $'PRESENT\tpi\t' "$LEDGER"; then
  _pass "B: pi is NOT falsely reported PRESENT"
else
  _fail "B: pi PRESENT leaked"
fi

# ---- Case C: stale alias 'antigravity' must NOT satisfy 'agy' ---------------
_mk_bindir "$BIN" pi codex claude grok copilot antigravity
_run "$BIN" "$LEDGER"
agy_status="$(status_of "$LEDGER" agy)"
if [[ "$agy_status" == "NOTE" || "$agy_status" == "DEFERRED" ]]; then
  _pass "C: agy checked by real name (stale 'antigravity' alias rejected)"
else
  _fail "C: agy wrongly satisfied (got '$agy_status')"
fi
if [[ -z "$(status_of "$LEDGER" antigravity)" ]]; then
  _pass "C: 'antigravity' is not a tracked agent"
else
  _fail "C: 'antigravity' leaked into the ledger"
fi

printf '\ntest_ai_agents: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
