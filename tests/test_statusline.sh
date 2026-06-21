#!/usr/bin/env bash
# tests/test_statusline.sh — the mahg Claude Code statusline
# (dotfiles/claude-code/statusline.sh). Hermetic: feeds sample JSON on stdin and
# asserts the rendered line (ANSI stripped). No Claude Code, no network.
#
# Cases:
#   A full   — repo bracketed (amber), dir abbreviated to ~, session shown
#   B no-repo — non-git dir is shown but NOT inside the [ ] (empty repo must not
#               collapse into the dir; this is why the script joins with \x1f, a
#               non-whitespace separator, instead of a tab)
#   C empty   — {} renders the stable "claude" fallback
#   D invalid — non-JSON renders "claude" (never errors)
#
# MUTATIONS (each makes a named assertion bite):
#   - statusline.sh: join with a whitespace separator (tab) + IFS=$'\t' -> the
#     empty repo collapses and B shows "[ /tmp/foo ]" -> "B no-repo: dir NOT
#     bracketed" bites.
#   - statusline.sh: wrong repo path (.workspace.name) -> "A full: repo bracketed"
#     bites.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
ROOT_DIR="$(cd "$TESTS_DIR/.." >/dev/null 2>&1 && pwd -P)"
SL="$ROOT_DIR/dotfiles/claude-code/statusline.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  [PASS] %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  [FAIL] %s\n' "$1"; }

# render <json> — run the statusline on the JSON, strip ANSI SGR escapes.
render() { printf '%s' "$1" | bash "$SL" | sed -r 's/\x1b\[[0-9;]*m//g'; }

# Deterministic HOME so the ~ abbreviation is testable regardless of the runner.
export HOME=/home/tester

# want <haystack> <needle> <msg> — pass when haystack CONTAINS needle.
want()    { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3 (got '$1')" ;; esac; }
wantnot() { case "$1" in *"$2"*) bad "$3 (got '$1')" ;; *) ok "$3" ;; esac; }
eq()      { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (got '$1')"; fi; }

# A — full
A="$(render '{"workspace":{"current_dir":"/home/tester/code/app","repo":{"name":"app"}},"session_name":"sess1"}')"
want    "$A" "[ app ]"               "A full: repo bracketed (amber)"
want    "$A" "/code/app"             "A full: dir shown"
wantnot "$A" "/home/tester/code/app" "A full: \$HOME abbreviated (no absolute home path)"
want    "$A" "sess1"                  "A full: session_name shown"

# B — no repo (non-git): dir shown, NOT bracketed
B="$(render '{"workspace":{"current_dir":"/tmp/foo"}}')"
want    "$B" "/tmp/foo" "B no-repo: dir shown"
wantnot "$B" "[ "       "B no-repo: dir NOT bracketed (empty repo preserved)"

# C / D — fallbacks
eq "$(render '{}')"       "claude" "C empty {} -> claude"
eq "$(render 'not json')" "claude" "D invalid JSON -> claude"

echo
echo "test_statusline: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
