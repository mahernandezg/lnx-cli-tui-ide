#!/usr/bin/env bash
# tests/test_micro.sh — hermetic, mutation-verified suite for modules/45-micro.sh.
#
# Drives the module against a CONTROLLED PATH (a fake `micro` shim or none), a
# throwaway $HOME, and DRY_RUN, so nothing is ever downloaded/installed. Asserts:
#   - micro present -> recorded PRESENT (no install); QoL config linked.
#   - micro absent (--dry-run) -> NOTE 'would install', nothing linked.
# Mutation check: pointing the config link at a wrong source fails the link assertion.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
chk()  { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }

BIN="$TMP/bin"; mkdir -p "$BIN"

_run() {  # <home> <ledger> <dry>
  local home="$1" out="$2" dry="$3"
  : >"$out"
  PATH="$BIN:/usr/bin:/bin" DRY_RUN="$dry" REPO_ROOT="$ROOT" LOG_DIR="$TMP/logs" \
  OUTCOME_FILE="$out" HOME="$home" bash -c '
    set -uo pipefail
    # shellcheck disable=SC1090,SC1091
    . "$REPO_ROOT/lib/log.sh"; . "$REPO_ROOT/lib/detect.sh"; . "$REPO_ROOT/lib/fallback.sh"
    . "$REPO_ROOT/lib/github.sh"; . "$REPO_ROOT/lib/release.sh"; . "$REPO_ROOT/lib/apt.sh"
    . "$REPO_ROOT/lib/symlink.sh"; . "$REPO_ROOT/lib/outcome.sh"
    log_init >/dev/null 2>&1 || true
    . "$REPO_ROOT/modules/45-micro.sh"
  ' >/dev/null 2>&1
}
status_of() { awk -F '\t' -v b="$2" '$2==b{print $1; exit}' "$1"; }

LEDGER="$TMP/out.tsv"

# ---- Case A: micro present -> PRESENT (no install) + config linked -----------
printf '#!/bin/sh\necho "micro 2.0.14"\n' >"$BIN/micro"; chmod +x "$BIN/micro"
HA="$TMP/homeA"; mkdir -p "$HA"
_run "$HA" "$LEDGER" 0
chk "A: existing micro kept (PRESENT, no install)" "$(status_of "$LEDGER" micro)" "PRESENT"
CFG="$HA/.config/micro/settings.json"
if [[ -L "$CFG" && "$(readlink -f "$CFG")" == "$(readlink -f "$ROOT/dotfiles/micro/settings.json")" ]]; then
  _pass "A: QoL config linked to the vendored settings.json"
else
  _fail "A: config not linked correctly"
fi

# ---- Case B: micro absent, --dry-run -> NOTE 'would install', nothing linked -
rm -f "$BIN/micro"
HB="$TMP/homeB"; mkdir -p "$HB"
_run "$HB" "$LEDGER" 1
chk "B: missing micro under --dry-run -> NOTE 'would install'" "$(status_of "$LEDGER" micro)" "NOTE"
if [[ ! -e "$HB/.config/micro/settings.json" ]]; then _pass "B: --dry-run linked nothing"; else _fail "B: --dry-run created the config link"; fi

printf '\ntest_micro: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
