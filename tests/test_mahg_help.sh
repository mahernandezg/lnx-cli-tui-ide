#!/usr/bin/env bash
# tests/test_mahg_help.sh — hermetic, mutation-verified suite for bin/mahg-help.
#
# Runs mahg-help against a CONTROLLED PATH (only fake agent shims + coreutils), so
# the real environment is invisible. Asserts it detects present vs absent agents by
# their real binary name, runs cleanly without a TTY, and that --no-color is escape
# free. Mutation check: a wrong binary name would flip a present agent to absent.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
HELP="$ROOT/bin/mahg-help"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT
mkdir -p "$TMP/home"

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

[[ -x "$HELP" ]] || { echo "[FAIL] $HELP not executable"; exit 1; }

# Shim dir: pi, codex, agy present; claude, grok, copilot absent.
BIN="$TMP/bin"; mkdir -p "$BIN"
for a in pi codex agy; do
  printf '#!/bin/sh\necho "%s 9.9.9"\n' "$a" >"$BIN/$a"; chmod +x "$BIN/$a"
done

OUT="$(PATH="$BIN:/usr/bin:/bin" HOME="$TMP/home" "$HELP" agents --no-color 2>/dev/null)"

present() { printf '%s\n' "$OUT" | grep -E "[[:space:]]$1[[:space:]]" | grep -qv "not installed"; }
absent()  { printf '%s\n' "$OUT" | grep -E "[[:space:]]$1[[:space:]]" | grep -q  "not installed"; }

for a in pi codex agy; do
  if present "$a"; then _pass "present agent detected: $a"; else _fail "$a should be present"; fi
done
for a in claude grok copilot; do
  if absent "$a"; then _pass "absent agent flagged: $a"; else _fail "$a should be flagged absent"; fi
done

# --no-color output must contain no ANSI escape sequences.
if printf '%s' "$OUT" | grep -q $'\033'; then
  _fail "--no-color still emitted ANSI escapes"
else
  _pass "--no-color output is escape-free"
fi

# --version is stable and parseable.
if "$HELP" --version | grep -qE '^mahg-help [0-9]+\.[0-9]+\.[0-9]+$'; then
  _pass "--version prints a version"
else
  _fail "--version output unexpected"
fi

# Full run must not error without a TTY (output piped here).
if PATH="$BIN:/usr/bin:/bin" HOME="$TMP/home" "$HELP" --no-color >/dev/null 2>&1; then
  _pass "full run exits 0 without a TTY"
else
  _fail "full run errored without a TTY"
fi

printf '\ntest_mahg_help: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
