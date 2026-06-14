#!/usr/bin/env bash
# tests/test_sete.sh — regression guard for the `set -e` abort bug class.
#
# Background: the installer once aborted on a real run because log_init ended in
# `[[ $DRY_RUN == 1 ]] && cmd`, which returns 1 when not in --dry-run; under
# `set -e` that killed the whole run. --dry-run could not catch it because the
# condition was inverted (true in dry-run). This test exercises the REAL path
# (DRY_RUN=0) under `set -euo pipefail` and asserts the functions return 0 /
# degrade safely instead of aborting.
#
# Hermetic: network and package commands are replaced by PATH shims, so nothing
# is ever downloaded or installed. Plain bash — no external test dependencies.
#
# shellcheck disable=SC2016  # the run_sete snippet strings are single-quoted ON
# PURPOSE: the $VARS inside them must expand in the child shell (via eval), here.
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
export REPO_ROOT

PASS=0
FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---- Hermetic shim PATH -----------------------------------------------------
# Offline (curl/wget fail), OpenGL undetectable (glxinfo prints nothing), and
# inert package tooling so no real install can happen on the test path.
SHIM="$(mktemp -d)"
trap 'rm -rf "$SHIM" 2>/dev/null || true' EXIT
mkdir -p "$SHIM/logs"
_mkshim() { printf '#!/bin/sh\n%s\n' "$2" >"$SHIM/$1"; chmod +x "$SHIM/$1"; }
_mkshim curl    'exit 1'    # simulate offline
_mkshim wget    'exit 1'    # simulate offline
_mkshim glxinfo 'exit 0'    # present but no output -> empty OpenGL parse
_mkshim apt-get 'exit 0'    # inert
_mkshim sudo    'exit 0'    # inert
_mkshim uv      'exit 0'    # inert
_mkshim npm     'exit 0'    # inert
SHIM_PATH="$SHIM:$PATH"

# run_sete <want-rc> <description> <snippet>
# Runs <snippet> in a fresh shell under `set -euo pipefail` with the shim PATH and
# all libs sourced (DRY_RUN=0). Asserts the resulting exit code equals <want-rc>;
# a real `set -e` abort surfaces as a non-zero rc and fails the assertion.
run_sete() {
  local want="$1" desc="$2" snippet="$3" rc
  SNIPPET="$snippet" PATH="$SHIM_PATH" DRY_RUN=0 VERBOSE=0 REPO_ROOT="$REPO_ROOT" \
    LOG_DIR="$SHIM/logs" bash -c '
      set -euo pipefail
      # shellcheck disable=SC1090,SC1091  # paths come from the exported REPO_ROOT
      . "$REPO_ROOT/lib/log.sh"
      . "$REPO_ROOT/lib/detect.sh"
      . "$REPO_ROOT/lib/fallback.sh"
      . "$REPO_ROOT/lib/apt.sh"
      . "$REPO_ROOT/lib/github.sh"
      eval "$SNIPPET"
    ' >/dev/null 2>&1
  rc=$?
  if [[ "$rc" -eq "$want" ]]; then _pass "$desc"; else _fail "$desc (rc=$rc, want $want)"; fi
}

echo "== set -e regression suite (DRY_RUN=0, hermetic) =="

# 1. Sourcing all libs under set -e must not abort.
run_sete 0 "all lib/*.sh source cleanly under set -e" 'true'

# 2. The original bug: log_init on the real (non-dry) path returns 0.
run_sete 0 "log_init returns 0 with DRY_RUN=0 (the original bug)" 'log_init'

# 3. Full detection completes offline AND reaches the end (sentinel = the final
#    assertion runs only if run_detection did not abort).
run_sete 0 "run_detection completes offline + reaches end" \
  'log_init; run_detection; [[ "${DETECT_NETWORK}" == "0" ]]'

# 4. Each detection helper degrades to rc 0 on the failure conditions.
run_sete 0 "_detect_network rc0 when offline" '_detect_network'
run_sete 0 "_detect_ram rc0 (numeric default)" '_detect_ram; [[ "$DETECT_RAM_MB" =~ ^[0-9]+$ ]]'
run_sete 0 "_detect_opengl rc0 with empty glxinfo (major=0)" '_detect_opengl; [[ "$DETECT_OPENGL_MAJOR" == "0" ]]'
run_sete 0 "_detect_debian rc0" '_detect_debian'

# 5. opengl_ge_33 is a predicate: false must not abort when used as a statement-less
#    condition (mirrors how modules call it).
run_sete 0 "opengl_ge_33 used as a condition does not abort" \
  '_detect_opengl; if opengl_ge_33; then :; else :; fi'

# 6. github_latest_tag degrades gracefully on a rate-limited body: it must reach
#    its own WARN + `return 1` (NOT abort at the grep|sed parse). This is exactly
#    what the `|| true` fix on the parse line protects.
test_github_graceful() {
  local sh2 out
  sh2="$(mktemp -d)"
  # curl emits a rate-limit JSON (no "tag_name") and succeeds, so the function
  # proceeds into the parse path that used to abort under set -e + pipefail.
  printf '#!/bin/sh\necho %s\nexit 0\n' \
    "'{\"message\":\"API rate limit exceeded for 1.2.3.4\"}'" >"$sh2/curl"
  chmod +x "$sh2/curl"
  out="$(PATH="$sh2:$PATH" DRY_RUN=0 VERBOSE=0 REPO_ROOT="$REPO_ROOT" bash -c '
      set -euo pipefail
      # shellcheck disable=SC1090,SC1091
      . "$REPO_ROOT/lib/log.sh"
      . "$REPO_ROOT/lib/detect.sh"
      . "$REPO_ROOT/lib/github.sh"
      if tag="$(github_latest_tag owner/repo)"; then
        echo "UNEXPECTED_OK:$tag"
      else
        echo "GRACEFUL_RC=$?"
      fi
    ' 2>&1)"
  rm -rf "$sh2" 2>/dev/null || true
  if printf '%s' "$out" | grep -q "GRACEFUL_RC=1" \
     && printf '%s' "$out" | grep -qi "rate-limited"; then
    _pass "github_latest_tag degrades gracefully on rate-limit (WARN kept, no abort)"
  else
    _fail "github_latest_tag rate-limit handling — got: $(printf '%s' "$out" | tr '\n' '|')"
  fi
}
test_github_graceful

# 7. Every script still parses (cheap structural backstop).
parse_ok=1
for f in "$REPO_ROOT"/install.sh "$REPO_ROOT"/lib/*.sh "$REPO_ROOT"/modules/*.sh "$REPO_ROOT"/tests/*.sh; do
  bash -n "$f" 2>/dev/null || { parse_ok=0; echo "    bash -n failed: $f"; }
done
if [[ "$parse_ok" -eq 1 ]]; then _pass "all scripts parse (bash -n)"; else _fail "a script failed bash -n"; fi

# ---- Summary ----------------------------------------------------------------
echo
echo "Summary: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
