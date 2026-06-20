#!/usr/bin/env bash
# tests/test_pypi.sh — resilience regression guard for a BLOCKED PyPI.
#
# Background (the motivating incident): on a corporate WSL Debian,
# files.pythonhosted.org was blocked. euporie, ruff, and basedpyright each let
# `uv tool install` burn ~45-50s x3 before giving up — hanging the terminal for
# minutes — and the run still printed "without fatal errors" while three tools
# were missing. This test encodes the fix so it cannot regress:
#
#   (a) the closed path is detected FAST, BEFORE uv is ever invoked (no hang),
#   (b) ruff falls back to its GitHub release binary,
#   (c) euporie and basedpyright are DEFERRED (not FAILED),
#   (d) the final summary reports the pending items honestly (exit 2), never
#       "without fatal errors",
#   and the vtsls-without-Node case is an informational NOTE (not a deferral and
#   not a failure), because a rerun cannot fix a missing prerequisite.
#
# Hermetic: a curated PATH of just the needed coreutils plus shims. The real
# tools (euporie/ruff/basedpyright/vtsls/hx/uv) and npm are deliberately NOT on
# this PATH, so the deferral/fallback/NOTE branches trigger deterministically on
# any host. curl is shimmed to block files.pythonhosted.org (the incident) while
# answering the GitHub API (so the ruff fallback can resolve a tag). Plain bash.
#
# shellcheck disable=SC2016  # the fast-fail bash -c body is single-quoted ON
# PURPOSE: $VARS inside it must expand in the child shell (from exported env).
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
export REPO_ROOT

PASS=0
FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

# build_core_bin <dir> — symlink in only the real coreutils the installer needs
# on its --dry-run path. Deliberately omitted: npm, hx, euporie, ruff,
# basedpyright, vtsls, jq, cargo — so those read as "not installed".
build_core_bin() {
  local dir="$1" c src
  local cmds="bash sh env printf date mkdir rmdir rm cat cp mv ln install find \
sort head tail grep sed awk cut tr uname id mktemp chmod sleep timeout tee \
dirname basename readlink ls expr"
  for c in $cmds; do
    src="$(command -v "$c" 2>/dev/null || true)"
    # if-form (not A && B || C): keeps shellcheck SC2015-clean and the intent
    # explicit — link the tool when present, ignore link errors, never fail.
    if [[ -n "$src" ]]; then ln -s "$src" "$dir/$c" 2>/dev/null || true; fi
  done
}
_mkshim() { printf '#!/bin/sh\n%s\n' "$2" >"$1/$3"; chmod +x "$1/$3"; }

# A curl shim that reproduces the incident: block files.pythonhosted.org, answer
# the GitHub API with a real tag (so the ruff release fallback resolves), and
# treat everything else (github.com reachability) as reachable.
_write_blocking_curl() {
  cat >"$1/curl" <<'EOF'
#!/bin/sh
url=""
for a in "$@"; do case "$a" in http*) url="$a";; esac; done
case "$url" in
  *pythonhosted*)   exit 28 ;;                       # simulate the block (timeout)
  *api.github.com*) echo '{"tag_name":"0.15.17"}'; exit 0 ;;
  *)                exit 0 ;;                         # reachable
esac
EOF
  chmod +x "$1/curl"
}

# =============================================================================
# (a) FAST-FAIL PROOF — genuine, non-dry reproduction of the hang.
#
# A SLOW uv shim stands in for the ~45-50s blocked-retry loop AND drops a
# sentinel when called. With the pre-check intact, euporie DEFERS and uv is
# NEVER invoked -> fast, no sentinel. If pypi_reachable is disabled, the module
# reaches `uv tool install`, the slow shim runs, and the whole thing is killed by
# the outer timeout -> this assertion bites. (Mutation-verified: disabling
# pypi_reachable flips this to FAIL.)
# =============================================================================
echo "== (a) fast-fail proof (DRY_RUN=0, slow-uv hang reproduction) =="
FF="$(mktemp -d)"
build_core_bin "$FF"
mkdir -p "$FF/home" "$FF/logs"
SENTINEL="$FF/uv_was_called"
printf '#!/bin/sh\necho called >>"%s"\nsleep 30\n' "$SENTINEL" >"$FF/uv"
chmod +x "$FF/uv"
_write_blocking_curl "$FF"

SECONDS=0
PATH="$FF" HOME="$FF/home" DRY_RUN=0 VERBOSE=0 DETECT_NETWORK=1 \
  OUTCOME_FILE="$FF/led.tsv" LOG_DIR="$FF/logs" REPO_ROOT="$REPO_ROOT" \
  timeout -k 2 8 bash -c '
    . "$REPO_ROOT/lib/log.sh"
    . "$REPO_ROOT/lib/detect.sh"
    . "$REPO_ROOT/lib/fallback.sh"
    . "$REPO_ROOT/lib/outcome.sh"
    DETECT_ARCH="$(uname -m)"; DETECT_HEADLESS=1
    log_init >/dev/null 2>&1
    . "$REPO_ROOT/modules/30-euporie.sh"
  ' >"$FF/out" 2>&1
FF_RC=$?
FF_EL=$SECONDS
ff_deferred=1
awk -F'\t' '$1=="DEFERRED" && $2=="euporie" {f=1} END{exit f?0:1}' "$FF/led.tsv" || ff_deferred=0

if [[ "$FF_RC" -ne 124 && "$FF_EL" -lt 8 && ! -f "$SENTINEL" && "$ff_deferred" -eq 1 ]]; then
  _pass "(a) closed path detected fast — uv was NEVER invoked, euporie deferred (${FF_EL}s)"
else
  _fail "(a) NOT fast/short-circuited — rc=$FF_RC el=${FF_EL}s uv_called=$([[ -f "$SENTINEL" ]] && echo yes || echo no) deferred=$ff_deferred"
fi
rm -rf "$FF"

# =============================================================================
# (b)(c)(d) + NOTE — end-to-end honest summary via the real installer (--dry-run).
# =============================================================================
echo "== (b)(c)(d) honest summary (real installer, --dry-run) =="
SHIM="$(mktemp -d)"
trap 'rm -rf "$SHIM" 2>/dev/null || true' EXIT
build_core_bin "$SHIM"
mkdir -p "$SHIM/home"
_write_blocking_curl "$SHIM"
_mkshim "$SHIM" 'exit 0' uv        # present so the `have uv` gate passes
_mkshim "$SHIM" 'exit 0' glxinfo   # present but empty -> OpenGL undetectable
_mkshim "$SHIM" 'exit 0' sudo
_mkshim "$SHIM" 'exit 0' apt-get

OUT="$SHIM/out.txt"
LEDGER="$SHIM/outcomes.tsv"
PATH="$SHIM" HOME="$SHIM/home" DRY_RUN=0 VERBOSE=0 \
  OUTCOME_FILE="$LEDGER" LOG_DIR="$SHIM/logs" \
  timeout 60 "$REPO_ROOT/install.sh" --dry-run --only euporie --only helix \
  >"$OUT" 2>&1
RC=$?
echo "   exit=$RC  ledger=$(wc -l <"$LEDGER" 2>/dev/null || echo 0) lines"

# led <STATUS> <tool> — true if the ledger has that status for that tool.
led() { awk -F'\t' -v s="$1" -v t="$2" '$1==s && $2==t {found=1} END{exit found?0:1}' "$LEDGER"; }

# (b) ruff fell back to the GitHub release path.
if led INSTALLED ruff && awk -F'\t' '$1=="INSTALLED" && $2=="ruff" && $3 ~ /github/ {ok=1} END{exit ok?0:1}' "$LEDGER"; then
  _pass "(b) ruff installed via the GitHub release fallback"
else
  _fail "(b) ruff did NOT fall back to github — ledger: $(grep -P '\truff\t' "$LEDGER" | tr '\n' '|')"
fi

# (c) euporie & basedpyright DEFERRED, not FAILED.
if led DEFERRED euporie && ! led FAILED euporie; then
  _pass "(c) euporie DEFERRED (not failed)"
else
  _fail "(c) euporie not deferred-cleanly — ledger: $(grep -P '\teuporie\t' "$LEDGER" | tr '\n' '|')"
fi
if led DEFERRED basedpyright && ! led FAILED basedpyright; then
  _pass "(c) basedpyright DEFERRED (not failed)"
else
  _fail "(c) basedpyright not deferred-cleanly — ledger: $(grep -P '\tbasedpyright\t' "$LEDGER" | tr '\n' '|')"
fi

# (d) honest summary: pending status, exit 2, and NOT "without fatal errors".
if [[ "$RC" -eq 2 ]] \
   && grep -q "WITH PENDING items" "$OUT" \
   && ! grep -q "without fatal errors" "$OUT"; then
  _pass "(d) summary honest: exit 2, pending section shown, no false success line"
else
  _fail "(d) summary dishonest (exit=$RC, pending=$(grep -c 'WITH PENDING items' "$OUT"), falseok=$(grep -c 'without fatal errors' "$OUT"))"
fi

# vtsls-without-Node is an informational NOTE — not DEFERRED, not FAILED.
if led NOTE vtsls && ! led DEFERRED vtsls && ! led FAILED vtsls; then
  _pass "vtsls (no Node) is a NOTE — does not gate the exit code"
else
  _fail "vtsls not a clean NOTE — ledger: $(grep -P '\tvtsls\t' "$LEDGER" | tr '\n' '|')"
fi

# ---- Summary ----------------------------------------------------------------
echo
echo "Summary: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -ne 0 ]]; then
  echo "---- installer output (for triage) ----"
  sed -n '/===== Summary/,$p' "$OUT" 2>/dev/null || true
fi
[[ "$FAIL" -eq 0 ]]
