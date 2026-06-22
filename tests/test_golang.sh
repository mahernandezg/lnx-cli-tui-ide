#!/usr/bin/env bash
# tests/test_golang.sh — hermetic, mutation-verified suite for modules/02-golang.sh.
#
# Drives the module against a CONTROLLED PATH (a fake `go` shim or none), a throwaway
# $HOME/.bashrc, and GOLANG_ROOT pointing at an empty temp dir. DETECT_NETWORK is left
# unset, so an absent-Go run DEFERs at the network check and NEVER downloads/installs.
# Asserts:
#   - go present (>= min) -> recorded PRESENT (no install); PATH guard written.
#   - go absent (offline) -> DEFERRED (points to manual install); PATH guard still written.
#   - go absent (--dry-run) -> NOTE 'would install' and nothing written.
#   - PATH guard adds /usr/local/go/bin and ~/go/bin, and is idempotent (no duplicate).
# Mutation check: dropping a PATH entry from the block fails the guard assertions.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
chk()  { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }
has()  { if grep -qF "$2" "$1" 2>/dev/null; then _pass "$3"; else _fail "$3"; fi; }

BIN="$TMP/bin"; mkdir -p "$BIN"
EMPTY_ROOT="$TMP/noroot"; mkdir -p "$EMPTY_ROOT"   # exists but has no bin/go

# _run <home> <ledger> <dry>: controlled PATH + throwaway HOME + GOLANG_ROOT.
# DETECT_NETWORK is unset -> require_network() fails -> an absent-Go real run DEFERs
# (no download). The real /usr/local/go is hidden via GOLANG_ROOT.
_run() {
  local home="$1" out="$2" dry="$3"
  : >"$out"
  PATH="$BIN:/usr/bin:/bin" DRY_RUN="$dry" REPO_ROOT="$ROOT" LOG_DIR="$TMP/logs" \
  OUTCOME_FILE="$out" HOME="$home" GOLANG_ROOT="$EMPTY_ROOT" bash -c '
    set -uo pipefail
    # shellcheck disable=SC1090,SC1091
    . "$REPO_ROOT/lib/log.sh"; . "$REPO_ROOT/lib/detect.sh"
    . "$REPO_ROOT/lib/fallback.sh"; . "$REPO_ROOT/lib/apt.sh"; . "$REPO_ROOT/lib/outcome.sh"
    log_init >/dev/null 2>&1 || true
    . "$REPO_ROOT/modules/02-golang.sh"
  ' >/dev/null 2>&1
}
status_of() { awk -F '\t' -v b="$2" '$2==b{print $1; exit}' "$1"; }

LEDGER="$TMP/out.tsv"

# ---- Case A: go present on PATH (go1.26.4), real run -> PRESENT + guard write -
printf '#!/bin/sh\necho "go version go1.26.4 linux/amd64"\n' >"$BIN/go"; chmod +x "$BIN/go"
HA="$TMP/homeA"; mkdir -p "$HA"; RC="$HA/.bashrc"
_run "$HA" "$LEDGER" 0
chk "A: existing Go (>=1.26) kept (PRESENT, no install)" "$(status_of "$LEDGER" go)" "PRESENT"
chk "A: PATH guard written (INSTALLED)"                  "$(status_of "$LEDGER" golang-path)" "INSTALLED"
has "$RC" '# >>> lnx-cli-tui-ide: golang PATH >>>' "A: managed marker present in .bashrc"
has "$RC" 'export PATH="/usr/local/go/bin'         "A: /usr/local/go/bin added to PATH"
has "$RC" 'HOME/go/bin"'                            "A: ~/go/bin (GOPATH) added to PATH"

# ---- Case A2: idempotent — second run is a no-op, no duplicate block ----------
_run "$HA" "$LEDGER" 0
chk "A2: PATH guard idempotent (PRESENT on re-run)" "$(status_of "$LEDGER" golang-path)" "PRESENT"
chk "A2: no duplicate block" "$(grep -cF '# >>> lnx-cli-tui-ide: golang PATH >>>' "$RC")" "1"

# ---- Case B: go absent, real run, offline -> DEFERRED + guard still written ---
rm -f "$BIN/go"
HB="$TMP/homeB"; mkdir -p "$HB"
_run "$HB" "$LEDGER" 0
chk "B: missing Go -> DEFERRED (offline; points to manual install)" "$(status_of "$LEDGER" go)" "DEFERRED"
has "$HB/.bashrc" 'export PATH="/usr/local/go/bin' "B: PATH guard applied even when Go absent"

# ---- Case C: go absent, --dry-run -> NOTE 'would install', nothing written ----
HC="$TMP/homeC"; mkdir -p "$HC"
_run "$HC" "$LEDGER" 1
chk "C: missing Go under --dry-run -> NOTE 'would install'" "$(status_of "$LEDGER" go)" "NOTE"
if [[ ! -s "$HC/.bashrc" ]]; then _pass "C: --dry-run wrote nothing to .bashrc"; else _fail "C: --dry-run modified .bashrc"; fi

printf '\ntest_golang: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
