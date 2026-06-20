#!/usr/bin/env bash
# tests/test_tab_title.sh — hermetic, mutation-verified guard for the tab-title
# managed block written to ~/.bashrc by modules/75-tab-title.sh.
#
# Everything runs against a throwaway $HOME so the real ~/.bashrc is never
# touched. The module is sourced (it auto-runs _tab_title_apply once on source,
# exactly like the installer dispatch does); we pre-seed $HOME/.bashrc to put the
# module into the state under test, then assert on the result. Plain bash + the
# repo's own lib/log.sh + lib/outcome.sh; no network, no real tools.
#
# Cases (each mutation-verified — see the header note above each one):
#   T1 insertion preserves foreign content + makes one backup
#   T2 idempotency: a second apply changes nothing and makes no second backup
#   T3 ordering: our block lands AFTER the Starship block
#   T4 wrap: a hand-rolled hook (no markers, placed BEFORE Starship) is stripped,
#      wrapped, de-duplicated, and relocated after Starship
#   T5 revert: removes ONLY our block, preserving Starship + foreign content
#   T6 dry-run: changes nothing and makes no backup
set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
export REPO_ROOT

PASS=0
FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

BEGIN_TT="# >>> lnx-cli-tui-ide: tab-title >>>"
END_TT="# <<< lnx-cli-tui-ide: tab-title <<<"
BEGIN_SS="# >>> lnx-cli-tui-ide: starship >>>"
END_SS="# <<< lnx-cli-tui-ide: starship <<<"

# seed_starship <file> — write a representative .bashrc with foreign content and
# a Starship managed block (the real-world layout our hook must come after).
seed_starship() {
  cat >"$1" <<EOF
# ~/.bashrc seeded by the test
export EDITOR=hx
alias ll='ls -la'
FOREIGN_SENTINEL=keepme

$BEGIN_SS
command -v starship >/dev/null 2>&1 && eval "\$(starship init bash)"
$END_SS
EOF
}

# seed_manual_before_starship <file> — the user's real situation: the exact
# validated hook placed BY HAND (no markers) BEFORE the Starship block.
seed_manual_before_starship() {
  cat >"$1" <<EOF
# ~/.bashrc seeded by the test
FOREIGN_SENTINEL=keepme

__set_tab_title() {
  if [ "\$PWD" = "\$HOME" ]; then
    printf '\033]0;~\a'
  else
    printf '\033]0;%s\a' "\${PWD##*/}"
  fi
}
PROMPT_COMMAND="__set_tab_title;\${PROMPT_COMMAND}"

$BEGIN_SS
command -v starship >/dev/null 2>&1 && eval "\$(starship init bash)"
$END_SS
EOF
}

# count_baks <home> — how many ~/.bashrc.bak.* backups exist.
count_baks() { find "$1" -maxdepth 1 -name '.bashrc.bak.*' 2>/dev/null | wc -l | tr -d ' '; }

# lineno <pattern> <file> — 1-based line number of the first exact-line match.
lineno() { awk -v p="$1" '$0==p {print NR; exit}' "$2"; }

# run_apply <home> [DRY] — source the module against $home as $HOME (auto-applies).
run_apply() {
  local home="$1" dry="${2:-0}"
  HOME="$home" DRY_RUN="$dry" VERBOSE=0 \
    OUTCOME_FILE="$home/.led" LOG_DIR="$home/.logs" REPO_ROOT="$REPO_ROOT" \
    bash -c '
      . "$REPO_ROOT/lib/log.sh"
      . "$REPO_ROOT/lib/outcome.sh"
      . "$REPO_ROOT/modules/75-tab-title.sh"
    ' >"$home/.out" 2>&1
}

# =============================================================================
# T1 — insertion preserves foreign content and makes exactly one backup.
# MUTATION BITE: if apply truncated/replaced the file (e.g. `> "$rc"` instead of
# strip+append), FOREIGN_SENTINEL and the Starship block would vanish -> FAIL.
# =============================================================================
echo "== T1 insertion preserves foreign content =="
H="$(mktemp -d)"; seed_starship "$H/.bashrc"
run_apply "$H"
if grep -q '^FOREIGN_SENTINEL=keepme$' "$H/.bashrc" \
   && grep -qF "$BEGIN_SS" "$H/.bashrc" \
   && grep -qF "$BEGIN_TT" "$H/.bashrc" \
   && grep -qF "$END_TT"   "$H/.bashrc" \
   && [[ "$(count_baks "$H")" == "1" ]]; then
  _pass "T1 foreign + starship preserved, tab-title block added, one backup"
else
  _fail "T1 unexpected state (baks=$(count_baks "$H")); out: $(tr '\n' '|' <"$H/.out")"
fi
rm -rf "$H"

# =============================================================================
# T2 — idempotency: a second apply is a no-op and makes NO second backup.
# MUTATION BITE: an append-always implementation would add a second block and a
# second backup on the rerun -> the diff is non-empty / baks==2 -> FAIL.
# =============================================================================
echo "== T2 idempotency (no change, no second backup) =="
H="$(mktemp -d)"; seed_starship "$H/.bashrc"
run_apply "$H"                       # first apply: add
cp "$H/.bashrc" "$H/.after1"
baks_after1="$(count_baks "$H")"
run_apply "$H"                       # second apply: must be a no-op
if diff -q "$H/.after1" "$H/.bashrc" >/dev/null \
   && [[ "$baks_after1" == "1" && "$(count_baks "$H")" == "1" ]] \
   && grep -q 'already current' "$H/.out"; then
  _pass "T2 second apply changed nothing and made no second backup"
else
  _fail "T2 not idempotent (baks1=$baks_after1 baks2=$(count_baks "$H"), diff rc=$?)"
fi
rm -rf "$H"

# =============================================================================
# T3 — ordering: our block lands AFTER the Starship block.
# MUTATION BITE: a prepend/insert-before-starship implementation would put our
# begin marker above Starship's end marker -> the line-number test flips -> FAIL.
# =============================================================================
echo "== T3 ordering (tab-title after starship) =="
H="$(mktemp -d)"; seed_starship "$H/.bashrc"
run_apply "$H"
ln_ss_end="$(lineno "$END_SS" "$H/.bashrc")"
ln_tt_begin="$(lineno "$BEGIN_TT" "$H/.bashrc")"
if [[ -n "$ln_ss_end" && -n "$ln_tt_begin" && "$ln_tt_begin" -gt "$ln_ss_end" ]]; then
  _pass "T3 tab-title begin (line $ln_tt_begin) is after starship end (line $ln_ss_end)"
else
  _fail "T3 ordering wrong (starship_end=$ln_ss_end tab_title_begin=$ln_tt_begin)"
fi
rm -rf "$H"

# =============================================================================
# T4 — wrap: a hand-rolled hook placed BEFORE Starship (no markers) is stripped,
# wrapped in markers, de-duplicated, and relocated AFTER Starship.
# MUTATION BITE: an append-only implementation (no strip) would leave TWO
# __set_tab_title() definitions, with the hand-rolled one still before Starship
# -> the dedup/order asserts flip -> FAIL.
# =============================================================================
echo "== T4 wrap hand-rolled hook (dedup + relocate after starship) =="
H="$(mktemp -d)"; seed_manual_before_starship "$H/.bashrc"
run_apply "$H"
n_func="$(grep -c '^__set_tab_title()' "$H/.bashrc")"
n_pc="$(grep -c '^PROMPT_COMMAND=.*__set_tab_title' "$H/.bashrc")"
ln_ss_end="$(lineno "$END_SS" "$H/.bashrc")"
ln_tt_begin="$(lineno "$BEGIN_TT" "$H/.bashrc")"
if [[ "$n_func" == "1" && "$n_pc" == "1" ]] \
   && grep -qF "$BEGIN_TT" "$H/.bashrc" \
   && [[ -n "$ln_ss_end" && -n "$ln_tt_begin" && "$ln_tt_begin" -gt "$ln_ss_end" ]] \
   && grep -q '^FOREIGN_SENTINEL=keepme$' "$H/.bashrc" \
   && [[ "$(count_baks "$H")" == "1" ]]; then
  _pass "T4 hand-rolled hook wrapped once and relocated after starship (no dup)"
else
  _fail "T4 wrap wrong (func=$n_func pc=$n_pc ss_end=$ln_ss_end tt_begin=$ln_tt_begin baks=$(count_baks "$H"))"
fi
# Second apply on the wrapped result must now be idempotent.
cp "$H/.bashrc" "$H/.afterwrap"
run_apply "$H"
if diff -q "$H/.afterwrap" "$H/.bashrc" >/dev/null; then
  _pass "T4b re-apply after wrap is idempotent"
else
  _fail "T4b re-apply after wrap changed the file"
fi
rm -rf "$H"

# =============================================================================
# T5 — revert removes ONLY our block, preserving Starship + foreign content.
# MUTATION BITE: a revert that truncates the file (or also deletes the Starship
# markers) would drop FOREIGN_SENTINEL / the Starship block -> FAIL.
# =============================================================================
echo "== T5 revert removes only our block =="
H="$(mktemp -d)"; seed_starship "$H/.bashrc"
HOME="$H" DRY_RUN=0 VERBOSE=0 OUTCOME_FILE="$H/.led" LOG_DIR="$H/.logs" REPO_ROOT="$REPO_ROOT" \
  bash -c '
    . "$REPO_ROOT/lib/log.sh"
    . "$REPO_ROOT/lib/outcome.sh"
    . "$REPO_ROOT/modules/75-tab-title.sh"   # auto-applies (adds our block)
    _tab_title_revert                        # then revert it
  ' >"$H/.out" 2>&1
if ! grep -qF "$BEGIN_TT" "$H/.bashrc" \
   && ! grep -q '__set_tab_title' "$H/.bashrc" \
   && grep -qF "$BEGIN_SS" "$H/.bashrc" \
   && grep -qF "$END_SS" "$H/.bashrc" \
   && grep -q '^FOREIGN_SENTINEL=keepme$' "$H/.bashrc"; then
  _pass "T5 revert removed our block only; starship + foreign intact"
else
  _fail "T5 revert wrong; rc: $(tr '\n' '|' <"$H/.bashrc")"
fi
rm -rf "$H"

# =============================================================================
# T6 — dry-run changes nothing and makes no backup.
# MUTATION BITE: if the DRY_RUN guard were removed, the file would change and a
# backup would appear -> byte-identity / baks==0 asserts flip -> FAIL.
# =============================================================================
echo "== T6 dry-run is a true no-op =="
H="$(mktemp -d)"; seed_starship "$H/.bashrc"; cp "$H/.bashrc" "$H/.before"
run_apply "$H" 1
if diff -q "$H/.before" "$H/.bashrc" >/dev/null \
   && [[ "$(count_baks "$H")" == "0" ]] \
   && grep -q '\[DRY\]' "$H/.out"; then
  _pass "T6 dry-run made no change and no backup"
else
  _fail "T6 dry-run mutated state (baks=$(count_baks "$H"))"
fi
rm -rf "$H"

# ---- Summary ----------------------------------------------------------------
echo
echo "Summary: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
