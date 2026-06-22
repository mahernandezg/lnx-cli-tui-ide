#!/usr/bin/env bash
# tests/test_mahg_wt.sh — hermetic, mutation-verified suite for bin/mahg-wt-apply.
#
# Runs the helper against a FIXTURE settings.json (via --settings, which skips the
# WSL/Windows auto-detection) and asserts it: injects the mahg-dark scheme, sets
# colorScheme + cursorShape on WSL-source profiles ONLY, preserves everything else,
# keeps valid JSON, backs up before writing, and is idempotent. Self-skips if jq is
# absent (the helper itself DEFERs without jq). Mutation check: a wrong WSL-source
# match would leave the WSL profile's colorScheme unset.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
WT="$ROOT/bin/mahg-wt-apply"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
# chk <desc> <actual> <expected>
chk() { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed"
  exit 0
fi
[[ -x "$WT" ]] || { echo "[FAIL] $WT not executable"; exit 1; }

S="$TMP/settings.json"
cat >"$S" <<'JSON'
{
  "defaultProfile": "{guid-ps}",
  "schemes": [ { "name": "Campbell", "background": "#0C0C0C", "foreground": "#CCCCCC" } ],
  "profiles": {
    "defaults": { "fontFace": "JetBrainsMono Nerd Font" },
    "list": [
      { "guid": "{guid-ps}",  "name": "Windows PowerShell" },
      { "guid": "{guid-deb}", "name": "Debian", "source": "Windows.Terminal.Wsl" }
    ]
  }
}
JSON

# --- dry-run must NOT modify the file ---
before="$(cat "$S")"
"$WT" --settings "$S" --dry-run >/dev/null 2>&1
if [[ "$(cat "$S")" == "$before" ]]; then _pass "--dry-run changes nothing"; else _fail "--dry-run modified the file"; fi
if ls "$S".mahg.bak.* >/dev/null 2>&1; then _fail "--dry-run created a backup"; else _pass "--dry-run makes no backup"; fi

# --- apply ---
"$WT" --settings "$S" >/dev/null 2>&1

if jq -e . "$S" >/dev/null 2>&1; then _pass "result is valid JSON"; else _fail "result is not valid JSON"; fi

q() { jq -r "$1" "$S" 2>/dev/null; }
chk "mahg-dark scheme injected"          "$(q '[.schemes[].name] | index("mahg-dark") != null')" "true"
chk "existing Campbell scheme preserved" "$(q '[.schemes[].name] | index("Campbell") != null')"  "true"
chk "scheme background is brand navy"    "$(q '.schemes[] | select(.name=="mahg-dark") | .background')" "#070B16"
chk "WSL profile colorScheme = mahg-dark" "$(q '.profiles.list[] | select(.name=="Debian") | .colorScheme')" "mahg-dark"
chk "WSL profile cursorShape = filledBox" "$(q '.profiles.list[] | select(.name=="Debian") | .cursorShape')" "filledBox"
chk "non-WSL profile left untouched"     "$(q '.profiles.list[] | select(.name=="Windows PowerShell") | has("colorScheme")')" "false"
chk "unrelated keys preserved"           "$(q '.profiles.defaults.fontFace')" "JetBrainsMono Nerd Font"

# --- backup created on real write ---
if ls "$S".mahg.bak.* >/dev/null 2>&1; then _pass "backup created before writing"; else _fail "no backup created"; fi

# --- idempotency: 2nd run, no duplicate scheme, still valid ---
"$WT" --settings "$S" >/dev/null 2>&1
chk "idempotent (no duplicate scheme)" "$(q '[.schemes[].name] | map(select(. == "mahg-dark")) | length')" "1"

printf '\ntest_mahg_wt: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
