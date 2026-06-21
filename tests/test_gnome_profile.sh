#!/usr/bin/env bash
# tests/test_gnome_profile.sh — hermetic, mutation-verified guard for the GNOME
# Terminal "mahg-dark" profile created by modules/80-gnome-terminal-profile.sh.
#
# All dconf I/O runs inside `dbus-run-session` with an isolated XDG_CONFIG_HOME, so
# the real user dconf database is NEVER touched — each scenario gets a throwaway
# session bus + a throwaway dconf db under a temp dir. The module is sourced (it
# auto-runs _gnome_profile_apply once, exactly like the installer dispatch does).
#
# Self-skipping: if dconf / dbus-run-session / python3 are missing, OR a smoke
# `dconf write` cannot round-trip in this environment (no activatable dconf
# service), the suite prints SKIP and exits 0 — it never false-fails on a box that
# simply cannot run dconf (e.g. a minimal CI image without dconf-cli).
#
# Cases (each mutation-verified):
#   G1 create: fresh db -> the mahg-dark/mahg-light PAIR, both in the list,
#      mahg-dark set as default, keys actually written (background-color +
#      cursor-shape='underline' for each)
#   G2 idempotency: a second apply on the same db adds no duplicate of EITHER
#      profile -> PRESENT
#   G3 preserve + revert: a pre-seeded foreign profile survives apply; revert
#      removes BOTH ours and resets the default, foreign intact
#   G4 list helper: _profiles_list_edit dedups, seeds the stock UUID on an unset
#      list, and removes
#   G5 dry-run: changes nothing and prints [DRY]
#   G6 upgrade: a box that already has mahg-dark gets ONLY mahg-light added; the
#      user's manual default is left untouched
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
export REPO_ROOT

PASS=0
FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

have() { command -v "$1" >/dev/null 2>&1; }

# ---- Dependency + capability gate (self-skip, never false-fail) --------------
if ! have dconf || ! have dbus-run-session || ! have python3; then
  echo "SKIP test_gnome_profile: need dconf + dbus-run-session + python3 (missing on this box)"
  exit 0
fi

# probe: can a throwaway dconf actually round-trip a write in this environment?
_probe_dir="$(mktemp -d)"
mkdir -p "$_probe_dir/.config" "$_probe_dir/run"
chmod 700 "$_probe_dir/run"
# shellcheck disable=SC2016  # the $(...) must expand in the child shell, not here
if ! HOME="$_probe_dir" XDG_CONFIG_HOME="$_probe_dir/.config" XDG_RUNTIME_DIR="$_probe_dir/run" \
      dbus-run-session -- bash -c 'dconf write /lnx/probe "true" && [ "$(dconf read /lnx/probe)" = "true" ]' \
      >/dev/null 2>&1; then
  rm -rf "$_probe_dir"
  echo "SKIP test_gnome_profile: dconf cannot round-trip here (no activatable dconf service)"
  exit 0
fi
rm -rf "$_probe_dir"

# ---- Child driver -----------------------------------------------------------
# Written once, run under dbus-run-session per scenario. Emits KEY=VALUE facts on
# stdout; the outer script asserts on them. Quoted heredoc -> no shell expansion.
DRIVER="$(mktemp)"
cat >"$DRIVER" <<'DRIVER_EOF'
#!/usr/bin/env bash
set -uo pipefail
: "${REPO_ROOT:?}"
BASE="/org/gnome/terminal/legacy/profiles:"
have() { command -v "$1" >/dev/null 2>&1; }   # lib/detect.sh provides this in real runs
. "$REPO_ROOT/lib/log.sh"
. "$REPO_ROOT/lib/outcome.sh"

list_uuids() {
  dconf read "$BASE/list" 2>/dev/null | python3 -c '
import ast, sys
raw = sys.stdin.read().strip()
for u in (ast.literal_eval(raw) if raw else []):
    print(u)
'
}
name_uuid() {
  local want="$1" u
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    [ "$(dconf read "$BASE/:$u/visible-name" 2>/dev/null)" = "'$want'" ] && { printf '%s' "$u"; return 0; }
  done < <(list_uuids)
}
count_name() {
  local want="$1" u n=0
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    [ "$(dconf read "$BASE/:$u/visible-name" 2>/dev/null)" = "'$want'" ] && n=$((n + 1))
  done < <(list_uuids)
  printf '%s' "$n"
}

case "$1" in
  apply)
    . "$REPO_ROOT/modules/80-gnome-terminal-profile.sh" >/dev/null 2>&1 || true
    u="$(name_uuid mahg-dark)"
    l="$(name_uuid mahg-light)"
    echo "COUNT=$(count_name mahg-dark)"
    echo "LCOUNT=$(count_name mahg-light)"
    echo "UUID=$u"
    echo "LUUID=$l"
    echo "DEFAULT=$(dconf read "$BASE/default" 2>/dev/null)"
    echo "LIST=$(dconf read "$BASE/list" 2>/dev/null)"
    [ -n "$u" ] && echo "BG=$(dconf read "$BASE/:$u/background-color" 2>/dev/null)"
    [ -n "$u" ] && echo "CURSOR=$(dconf read "$BASE/:$u/cursor-shape" 2>/dev/null)"
    [ -n "$l" ] && echo "LBG=$(dconf read "$BASE/:$l/background-color" 2>/dev/null)"
    [ -n "$l" ] && echo "LCURSOR=$(dconf read "$BASE/:$l/cursor-shape" 2>/dev/null)"
    echo "OUTCOME=$(tail -n1 "${OUTCOME_FILE:-/dev/null}" 2>/dev/null)"
    ;;
  seed_foreign)
    dconf write "$BASE/:f0000000-0000-0000-0000-000000000001/visible-name" "'foreign'"
    dconf write "$BASE/list" "['f0000000-0000-0000-0000-000000000001']"
    dconf write "$BASE/default" "'f0000000-0000-0000-0000-000000000001'"
    echo "SEEDED=1"
    ;;
  seed_dark)
    # Pre-existing mahg-dark (as on an upgrading box), set as the user's default.
    dconf write "$BASE/:d0000000-0000-0000-0000-000000000002/visible-name" "'mahg-dark'"
    dconf write "$BASE/list" "['d0000000-0000-0000-0000-000000000002']"
    dconf write "$BASE/default" "'d0000000-0000-0000-0000-000000000002'"
    echo "SEEDED=1"
    ;;
  revert)
    . "$REPO_ROOT/modules/80-gnome-terminal-profile.sh" >/dev/null 2>&1 || true
    _gnome_profile_revert >/dev/null 2>&1 || true
    echo "COUNT=$(count_name mahg-dark)"
    echo "LCOUNT=$(count_name mahg-light)"
    echo "DEFAULT=$(dconf read "$BASE/default" 2>/dev/null)"
    echo "LIST=$(dconf read "$BASE/list" 2>/dev/null)"
    ;;
  helper)
    # DRY_RUN=1 in env -> auto-apply is a no-op; we only exercise the pure helper.
    . "$REPO_ROOT/modules/80-gnome-terminal-profile.sh" >/dev/null 2>&1 || true
    echo "ADD=$(_profiles_list_edit add "['a', 'b']" 'c')"
    echo "DEDUP=$(_profiles_list_edit add "['a', 'b']" 'b')"
    echo "UNSET=$(_profiles_list_edit add '' 'c')"
    echo "REMOVE=$(_profiles_list_edit remove "['a', 'b', 'c']" 'b')"
    ;;
  dryrun)
    # DRY_RUN=1 in env. Do NOT suppress output: we assert the [DRY] marker.
    . "$REPO_ROOT/modules/80-gnome-terminal-profile.sh" 2>&1 || true
    echo "COUNT=$(count_name mahg-dark)"
    echo "LCOUNT=$(count_name mahg-light)"
    ;;
esac
DRIVER_EOF

# drive <tmp> <scenario> [dry] — run one scenario under an isolated session bus +
# dconf db rooted at <tmp>. Reusing the same <tmp> persists the db across calls.
drive() {
  local tmp="$1" scen="$2" dry="${3:-0}"
  mkdir -p "$tmp/.config" "$tmp/run" "$tmp/.cache" "$tmp/.logs"
  chmod 700 "$tmp/run"
  HOME="$tmp" XDG_CONFIG_HOME="$tmp/.config" XDG_RUNTIME_DIR="$tmp/run" \
    XDG_CACHE_HOME="$tmp/.cache" OUTCOME_FILE="$tmp/.led" LOG_DIR="$tmp/.logs" \
    REPO_ROOT="$REPO_ROOT" DRY_RUN="$dry" \
    dbus-run-session -- bash "$DRIVER" "$scen" 2>&1
}

field() { sed -n "s/^$1=//p" <<<"$2" | head -n1; }

# =============================================================================
# G1 — create: fresh db gets the dark/light PAIR, both listed, mahg-dark
# defaulted, keys actually written (dark background + cursor-shape='underline',
# light background + cursor-shape='underline').
# MUTATION BITE: a no-op apply, a bad dconf load, a missing default-write, a
# dropped cursor-shape key, or a module that creates only ONE profile all flip
# one of COUNT/LCOUNT/DEFAULT/BG/CURSOR/LBG/LCURSOR.
# =============================================================================
echo "== G1 create (dark+light pair, listed, mahg-dark default, keys written) =="
T1="$(mktemp -d)"
o1="$(drive "$T1" apply)"
u1="$(field UUID "$o1")"
l1="$(field LUUID "$o1")"
if [[ "$(field COUNT "$o1")" == "1" ]] \
   && [[ "$(field LCOUNT "$o1")" == "1" ]] \
   && [[ -n "$u1" ]] && [[ -n "$l1" ]] && [[ "$u1" != "$l1" ]] \
   && [[ "$(field DEFAULT "$o1")" == "'$u1'" ]] \
   && [[ "$(field LIST "$o1")" == *"$u1"* ]] \
   && [[ "$(field LIST "$o1")" == *"$l1"* ]] \
   && [[ "$(field BG "$o1")" == "'#070b16'" ]] \
   && [[ "$(field CURSOR "$o1")" == "'underline'" ]] \
   && [[ "$(field LBG "$o1")" == "'#eef1f8'" ]] \
   && [[ "$(field LCURSOR "$o1")" == "'underline'" ]] \
   && [[ "$(field OUTCOME "$o1")" == INSTALLED* ]]; then
  _pass "G1 created mahg-dark ($u1) + mahg-light ($l1); both listed, dark default, backgrounds + underline cursors written"
else
  _fail "G1 unexpected: $(tr '\n' '|' <<<"$o1")"
fi

# =============================================================================
# G2 — idempotency: a second apply on the SAME db adds no duplicate of EITHER
# profile.
# MUTATION BITE: an apply that keyed off UUID instead of visible-name, or that
# recreated the pair unconditionally, would mint a second profile -> COUNT=2 or
# LCOUNT=2 and OUTCOME=INSTALLED.
# =============================================================================
echo "== G2 idempotency (no duplicate of either profile on re-apply) =="
o2="$(drive "$T1" apply)"   # same T1 -> db persists
if [[ "$(field COUNT "$o2")" == "1" ]] \
   && [[ "$(field LCOUNT "$o2")" == "1" ]] \
   && [[ "$(field OUTCOME "$o2")" == PRESENT* ]] \
   && [[ "$(field LIST "$o2")" == "$(field LIST "$o1")" ]]; then
  _pass "G2 re-apply added no duplicate (dark+light still one each; PRESENT; list unchanged)"
else
  _fail "G2 not idempotent: $(tr '\n' '|' <<<"$o2")"
fi
rm -rf "$T1"

# =============================================================================
# G3 — preserve a foreign profile through apply, then revert removes BOTH ours
# (dark AND light) and resets the default, foreign intact.
# MUTATION BITE: a list rebuild that dropped existing entries would lose the
# foreign UUID; a revert that only removed mahg-dark would leave LCOUNT=1 or the
# light UUID still in the list.
# =============================================================================
echo "== G3 preserve foreign + revert removes both ours =="
T3="$(mktemp -d)"
FUUID="f0000000-0000-0000-0000-000000000001"
drive "$T3" seed_foreign >/dev/null
o3a="$(drive "$T3" apply)"
o3b="$(drive "$T3" revert)"
if [[ "$(field COUNT "$o3a")" == "1" ]] \
   && [[ "$(field LCOUNT "$o3a")" == "1" ]] \
   && [[ "$(field LIST "$o3a")" == *"$FUUID"* ]] \
   && [[ "$(field COUNT "$o3b")" == "0" ]] \
   && [[ "$(field LCOUNT "$o3b")" == "0" ]] \
   && [[ "$(field LIST "$o3b")" == *"$FUUID"* ]] \
   && [[ "$(field LIST "$o3b")" != *"$(field UUID "$o3a")"* ]] \
   && [[ "$(field LIST "$o3b")" != *"$(field LUUID "$o3a")"* ]] \
   && [[ "$(field DEFAULT "$o3b")" != "$(field DEFAULT "$o3a")" ]]; then
  _pass "G3 foreign preserved through apply; revert removed mahg-dark + mahg-light + reset default"
else
  _fail "G3 wrong: apply=[$(tr '\n' '|' <<<"$o3a")] revert=[$(tr '\n' '|' <<<"$o3b")]"
fi
rm -rf "$T3"

# =============================================================================
# G4 — list helper: dedup on add, stock-UUID seed on unset, and remove.
# MUTATION BITE: a naive append would duplicate 'b' in DEDUP; a missing unset-seed
# would drop the stock profile from UNSET.
# =============================================================================
echo "== G4 _profiles_list_edit (dedup / unset-seed / remove) =="
T4="$(mktemp -d)"
o4="$(drive "$T4" helper 1)"
STOCK="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
if [[ "$(field ADD "$o4")" == "['a', 'b', 'c']" ]] \
   && [[ "$(field DEDUP "$o4")" == "['a', 'b']" ]] \
   && [[ "$(field UNSET "$o4")" == "['$STOCK', 'c']" ]] \
   && [[ "$(field REMOVE "$o4")" == "['a', 'c']" ]]; then
  _pass "G4 helper add/dedup/unset-seed/remove all correct"
else
  _fail "G4 helper wrong: $(tr '\n' '|' <<<"$o4")"
fi
rm -rf "$T4"

# =============================================================================
# G5 — dry-run changes nothing and prints [DRY].
# MUTATION BITE: a dropped DRY_RUN guard would create the profile -> COUNT=1.
# =============================================================================
echo "== G5 dry-run is a true no-op =="
T5="$(mktemp -d)"
o5="$(drive "$T5" dryrun 1)"
if [[ "$(field COUNT "$o5")" == "0" ]] && [[ "$(field LCOUNT "$o5")" == "0" ]] \
   && grep -q '\[DRY\]' <<<"$o5"; then
  _pass "G5 dry-run created neither profile and printed [DRY]"
else
  _fail "G5 dry-run wrong: $(tr '\n' '|' <<<"$o5")"
fi
rm -rf "$T5"

# =============================================================================
# G6 — upgrade path: a box that already has mahg-dark (the user's default) gets
# ONLY the missing mahg-light added, and its manual default is left untouched.
# MUTATION BITE: a module that recreated mahg-dark would bump COUNT=2; one that
# rewrote `default` unconditionally would change DEFAULT off the seeded UUID.
# =============================================================================
echo "== G6 upgrade path (dark present -> add only light, keep default) =="
T6="$(mktemp -d)"
DUUID="d0000000-0000-0000-0000-000000000002"
drive "$T6" seed_dark >/dev/null
o6="$(drive "$T6" apply)"
if [[ "$(field COUNT "$o6")" == "1" ]] \
   && [[ "$(field LCOUNT "$o6")" == "1" ]] \
   && [[ "$(field UUID "$o6")" == "$DUUID" ]] \
   && [[ "$(field DEFAULT "$o6")" == "'$DUUID'" ]] \
   && [[ "$(field LIST "$o6")" == *"$DUUID"* ]] \
   && [[ "$(field LIST "$o6")" == *"$(field LUUID "$o6")"* ]] \
   && [[ "$(field OUTCOME "$o6")" == INSTALLED* ]]; then
  _pass "G6 added only mahg-light; mahg-dark + user default untouched"
else
  _fail "G6 wrong: $(tr '\n' '|' <<<"$o6")"
fi
rm -rf "$T6"

rm -f "$DRIVER"

# ---- Summary ----------------------------------------------------------------
echo
echo "Summary: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
