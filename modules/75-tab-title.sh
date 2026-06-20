#!/usr/bin/env bash
# modules/75-tab-title.sh — GNOME Terminal tab-title hook for bash.
#
# Sets the terminal tab title to the current directory's basename (and "~" when
# in $HOME) on every prompt, via a PROMPT_COMMAND hook written to ~/.bashrc.
#
# ORDER CONTRACT (critical): this block MUST sit AFTER the Starship activation in
# ~/.bashrc. Starship's `eval "$(starship init bash)"` rewrites PROMPT_COMMAND;
# if our hook ran first, Starship would clobber it and the title would never
# update (observed by hand). Two guarantees enforce the order:
#   1. Module number 75 > 70 (70-starship.sh) -> the dispatch runs us after it.
#   2. Every write removes our prior block (wherever it is) and re-appends a
#      fresh copy at END-OF-FILE. EOF is always past Starship's block (Starship
#      was appended earlier in the run, or in a prior run), so ours lands
#      physically after it. This also relocates a hand-rolled hook (the "wrap"
#      case) to EOF, fixing the order even if the user put it before Starship.
#
# Idempotent: when our marker block is present AND its content equals the
# canonical block, we do nothing (no duplicate, no second backup). Otherwise we
# back up ~/.bashrc to ~/.bashrc.bak.<ts> before writing. Honors --dry-run.
#
# NOTE: the change applies to NEW shells. An already-open session needs
# `source ~/.bashrc` or a fresh terminal.
#
# Sourced by install.sh; inherits run(), log_*, record_outcome, DRY_RUN, HOME.

RC="$HOME/.bashrc"
BEGIN_MARK="# >>> lnx-cli-tui-ide: tab-title >>>"
END_MARK="# <<< lnx-cli-tui-ide: tab-title <<<"

# _tab_title_block — emit the canonical managed block (markers + validated hook).
# The body is written VERBATIM into ~/.bashrc and must resolve at shell startup,
# not here, so the escapes and ${...} expansions stay literal in the file.
# The marker lines below must stay byte-identical to $BEGIN_MARK / $END_MARK.
_tab_title_block() {
  cat <<'BLOCK'
# >>> lnx-cli-tui-ide: tab-title >>>
# Managed by lnx-cli-tui-ide. Sets the GNOME Terminal tab title to the current
# directory (or "~" in $HOME) on every prompt. MUST stay after Starship init so
# Starship's PROMPT_COMMAND rewrite does not clobber this hook.
__set_tab_title() {
  if [ "$PWD" = "$HOME" ]; then
    printf '\033]0;~\a'
  else
    printf '\033]0;%s\a' "${PWD##*/}"
  fi
}
PROMPT_COMMAND="__set_tab_title;${PROMPT_COMMAND}"
# <<< lnx-cli-tui-ide: tab-title <<<
BLOCK
}

# _tab_title_extract <file> — print our managed block (begin..end inclusive),
# first occurrence only. Empty when no block is present.
_tab_title_extract() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b {inb=1}
    inb   {print}
    $0==e && inb {exit}
  ' "$1" 2>/dev/null
}

# _tab_title_strip <file> — print <file> with BOTH our managed marker block and
# any hand-rolled hook removed:
#   - the marker block (begin..end), and
#   - a standalone __set_tab_title() {...} function (start at a line beginning
#     "__set_tab_title()", end at the first line that is exactly "}"), and
#   - the standalone PROMPT_COMMAND="__set_tab_title;..." wiring line.
# Marker-block lines are consumed first, so the function/PROMPT_COMMAND lines
# INSIDE our own block never re-trigger the hand-rolled rules.
_tab_title_strip() {
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b { inblk=1; next }
    inblk { if ($0==e) inblk=0; next }
    infn==0 && /^__set_tab_title\(\)/ { infn=1; next }
    infn==1 { if ($0=="}") infn=0; next }
    /^PROMPT_COMMAND=.*__set_tab_title/ { next }
    { print }
  ' "$1" 2>/dev/null
}

# _tab_title_apply — write/refresh the managed block in ~/.bashrc, after Starship.
_tab_title_apply() {
  local rc="$RC" ts backup action stripped newrc
  local has_markers=0 has_func=0 has_pc=0 has_any=0

  if [[ -f "$rc" ]]; then
    grep -qF "$BEGIN_MARK" "$rc" 2>/dev/null && has_markers=1
    grep -q '^__set_tab_title()' "$rc" 2>/dev/null && has_func=1
    grep -q '^PROMPT_COMMAND=.*__set_tab_title' "$rc" 2>/dev/null && has_pc=1
    grep -q '__set_tab_title' "$rc" 2>/dev/null && has_any=1
  fi

  # MARKED-CURRENT: our block is present and already canonical -> no-op.
  if [[ "$has_markers" == "1" && "$(_tab_title_extract "$rc")" == "$(_tab_title_block)" ]]; then
    record_outcome PRESENT tab-title "managed block already current in $rc"
    return 0
  fi

  # MANUAL but malformed: a __set_tab_title reference exists without our markers
  # and is NOT the canonical func+PROMPT_COMMAND pair. Be conservative: never
  # clobber unrecognized user content.
  if [[ "$has_markers" == "0" && "$has_any" == "1" ]] && { [[ "$has_func" == "0" ]] || [[ "$has_pc" == "0" ]]; }; then
    log_warn "tab-title: found a '__set_tab_title' reference in $rc that is not the expected shape."
    log_warn "tab-title: leaving it untouched to avoid clobbering. TODO(ask): wrap or remove it by hand, then re-run."
    record_outcome NOTE tab-title "unrecognized hand-rolled hook left untouched in $rc"
    return 0
  fi

  # Pick the action label (for logging / --dry-run honesty).
  if [[ "$has_markers" == "1" ]]; then
    action="refresh"                                   # marked but drifted
  elif [[ "$has_func" == "1" && "$has_pc" == "1" ]]; then
    action="wrap"                                      # hand-rolled -> wrap+relocate
  else
    action="add"                                       # absent (or no .bashrc)
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] tab-title: action=$action — would update the managed block in $rc (placed after Starship)"
    [[ "$action" == "wrap" ]] && log_info "[DRY]   would strip the hand-rolled __set_tab_title hook and re-add it wrapped at EOF"
    [[ -f "$rc" ]] && log_info "[DRY]   would back up $rc -> $rc.bak.<ts> first"
    _tab_title_block | sed 's/^/[DRY]   /'
    return 0
  fi

  # --- mutate (real run only) ---
  if [[ -f "$rc" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    backup="$rc.bak.$ts"
    run cp -- "$rc" "$backup"
    log_info "tab-title: backed up $rc -> $backup"
  else
    run mkdir -p "$(dirname "$rc")"
    : >"$rc"
  fi

  # Rebuild: everything else (our old block + any hand-rolled hook removed), then
  # the fresh canonical block appended at EOF -> guaranteed after Starship.
  stripped="$(_tab_title_strip "$rc")"
  newrc="$(mktemp)"
  {
    if [[ -n "$stripped" ]]; then
      printf '%s\n\n' "$stripped"
    fi
    _tab_title_block
  } >"$newrc"
  cat "$newrc" >"$rc"          # preserves the .bashrc inode/permissions
  rm -f "$newrc"

  record_outcome INSTALLED tab-title "$action -> managed block written to $rc (new shells; 'source $rc' for the current one)"
  log_ok "tab-title: $action complete in $rc — applies to new shells; run 'source $rc' or open a new terminal"
}

# _tab_title_revert — remove ONLY our managed block (begin..end), preserving the
# rest of ~/.bashrc (Starship and everything else). Backs up first. Honors
# --dry-run. Defined and exercised by tests/test_tab_title.sh; intentionally NOT
# auto-invoked by this module (no ad-hoc env toggle).
# shellcheck disable=SC2329  # invoked by tests/test_tab_title.sh, not in this file
_tab_title_revert() {
  local rc="$RC" ts backup newrc
  if [[ ! -f "$rc" ]]; then
    log_info "tab-title: $rc absent — nothing to revert"
    return 0
  fi
  if ! grep -qF "$BEGIN_MARK" "$rc" 2>/dev/null; then
    log_info "tab-title: no managed block in $rc — nothing to revert"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] tab-title: would back up $rc and remove the managed block (begin..end)"
    return 0
  fi
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="$rc.bak.$ts"
  run cp -- "$rc" "$backup"
  newrc="$(mktemp)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0==b { inblk=1; next }
    inblk { if ($0==e) inblk=0; next }
    { print }
  ' "$rc" >"$newrc"
  # Collapse the trailing blank line left where the block used to be.
  printf '%s\n' "$(<"$newrc")" >"$rc"
  rm -f "$newrc"
  log_ok "tab-title: reverted — removed managed block from $rc (backup: $backup)"
}

# ---- Run --------------------------------------------------------------------
_tab_title_apply

log_ok "tab-title module done"
