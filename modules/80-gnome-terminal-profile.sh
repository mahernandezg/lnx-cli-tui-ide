#!/usr/bin/env bash
# modules/80-gnome-terminal-profile.sh — branded "mahg-dark" GNOME Terminal profile.
#
# Creates a GNOME Terminal legacy profile from the vendored dconf dump
# (profiles/gnome-terminal/mahg-dark.dconf) under a NEW, per-machine UUID, adds it
# to the profiles list WITHOUT deleting any existing profile, and sets it as the
# default. Cosmetic sibling of 75-tab-title.sh (also GNOME-Terminal-specific),
# numbered after it and before the gated 90-vscodium.
#
# dconf layout (legacy GNOME Terminal):
#   /org/gnome/terminal/legacy/profiles:/list      -> array of profile UUIDs
#   /org/gnome/terminal/legacy/profiles:/default   -> the default profile UUID
#   /org/gnome/terminal/legacy/profiles:/:<uuid>/  -> one profile's keys
#
# Idempotent: the visible-name is the identity. If any profile already has
# visible-name='mahg-dark', we do nothing (no duplicate). A fresh UUID is minted
# per machine (python3 uuid.uuid4()), so two machines never collide and a rerun
# elsewhere is independent. The whole profiles:/ tree is backed up before any
# write, which also captures the prior `default` so a revert can restore it.
#
# Non-GNOME boxes: when `dconf` (or python3) is absent there is nothing to do and
# no rerun can fix it -> recorded as a NOTE, never a failure.
#
# NOTE: a running GNOME Terminal picks up the new profile on a new window/tab.
#
# Sourced by install.sh; inherits run(), log_*, record_outcome, have(), DRY_RUN.

BASE="/org/gnome/terminal/legacy/profiles:"
BACKUP_DIR="$HOME/.config/lnx-cli-tui-ide/backups"
PROFILE_FILE="$REPO_ROOT/profiles/gnome-terminal/mahg-dark.dconf"
# Well-known UUID of GNOME Terminal's implicit default profile. Used only to seed
# the list when it is unset, so we never orphan the stock profile.
DEFAULT_PROFILE_UUID="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"

# _profiles_list_edit <add|remove> <current-list-gvariant> <uuid> — print a new
# GVariant array string. `add` dedups and (on an unset list) seeds the stock
# default UUID first so it is not orphaned; `remove` drops the uuid. Pure: no
# dconf I/O, so it is unit-testable without a session bus.
_profiles_list_edit() {
  python3 - "$1" "$2" "$3" "$DEFAULT_PROFILE_UUID" <<'PY'
import ast, sys
op, raw, uuid, default_uuid = sys.argv[1], sys.argv[2].strip(), sys.argv[3], sys.argv[4]
items = []
if raw:
    try:
        items = list(ast.literal_eval(raw))
    except (ValueError, SyntaxError):
        items = []
if op == "add":
    if not items:
        items = [default_uuid]
    if uuid not in items:
        items.append(uuid)
elif op == "remove":
    items = [i for i in items if i != uuid]
print("[" + ", ".join("'%s'" % i for i in items) + "]")
PY
}

# _profiles_list_uuids <list-gvariant> — print one UUID per line (empty on unset).
_profiles_list_uuids() {
  python3 - "$1" <<'PY'
import ast, sys
raw = sys.argv[1].strip()
try:
    for u in ast.literal_eval(raw):
        print(u)
except (ValueError, SyntaxError):
    pass
PY
}

# _gnome_profile_find — print the UUID of an existing visible-name='mahg-dark'
# profile, or nothing. Read-only (safe in --dry-run). Quiet on stdout except the
# UUID so callers can capture it.
_gnome_profile_find() {
  local list uuid name
  list="$(dconf read "$BASE/list" 2>/dev/null || true)"
  [[ -z "$list" ]] && return 0
  while IFS= read -r uuid; do
    [[ -z "$uuid" ]] && continue
    name="$(dconf read "$BASE/:$uuid/visible-name" 2>/dev/null || true)"
    if [[ "$name" == "'mahg-dark'" ]]; then
      printf '%s\n' "$uuid"
      return 0
    fi
  done < <(_profiles_list_uuids "$list")
}

# _gnome_profile_apply — create + register + default the mahg-dark profile.
_gnome_profile_apply() {
  if ! have dconf; then
    record_outcome NOTE gnome-terminal-profile "dconf not found — GNOME Terminal not installed; a rerun cannot fix this"
    return 0
  fi
  if ! have python3; then
    record_outcome NOTE gnome-terminal-profile "python3 not found — needed for the per-machine UUID and safe list edit"
    return 0
  fi
  if [[ ! -f "$PROFILE_FILE" ]]; then
    log_error "gnome-terminal-profile: vendored profile missing: $PROFILE_FILE"
    return 1
  fi

  # Idempotency: identity is the visible-name, not the UUID.
  local existing
  existing="$(_gnome_profile_find)"
  if [[ -n "$existing" ]]; then
    record_outcome PRESENT gnome-terminal-profile "visible-name='mahg-dark' already present (uuid=$existing)"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] gnome-terminal-profile: would back up the $BASE/ tree to $BACKUP_DIR/"
    log_info "[DRY] would mint a new UUID and 'dconf load' these keys into $BASE/:<uuid>/ :"
    sed 's/^/[DRY]   /' "$PROFILE_FILE"
    log_info "[DRY] would append the new UUID to $BASE/list (existing profiles preserved)"
    log_info "[DRY] would set the new profile as default ($BASE/default)"
    return 0
  fi

  # --- mutate (real run only) ---
  local ts backup uuid curlist newlist
  ts="$(date +%Y%m%d-%H%M%S)"
  run mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/gnome-terminal-profiles.$ts.dconf"
  # Direct redirection (read-only on dconf): dump the whole tree so a revert can
  # restore the prior list AND default. Past the dry-run guard, mirroring 75-tab-title.
  if dconf dump "$BASE/" >"$backup" 2>/dev/null; then
    log_info "gnome-terminal-profile: backed up profiles tree -> $backup"
  else
    log_warn "gnome-terminal-profile: could not dump existing profiles (continuing; backup may be empty)"
  fi

  uuid="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  # Write all keys. dconf load needs stdin, so it is a direct call (post-guard).
  if ! dconf load "$BASE/:$uuid/" <"$PROFILE_FILE"; then
    log_error "gnome-terminal-profile: dconf load failed for uuid=$uuid"
    return 1
  fi

  curlist="$(dconf read "$BASE/list" 2>/dev/null || true)"
  newlist="$(_profiles_list_edit add "$curlist" "$uuid")"
  run dconf write "$BASE/list" "$newlist"
  run dconf write "$BASE/default" "'$uuid'"

  record_outcome INSTALLED gnome-terminal-profile "uuid=$uuid (added to list, set as default; backup=$backup)"
  log_ok "gnome-terminal-profile: created mahg-dark (uuid=$uuid) and set as default — open a NEW GNOME Terminal window/tab to see it"
}

# _gnome_profile_revert — remove ONLY our profile: drop it from the list, reset
# `default` if it pointed at us, and reset the profile's keys. Other profiles are
# untouched. Backs up first. Honors --dry-run. Defined and exercised by
# tests/test_gnome_profile.sh; intentionally NOT auto-invoked here.
# shellcheck disable=SC2329  # invoked by tests/test_gnome_profile.sh, not in this file
_gnome_profile_revert() {
  have dconf || { log_info "gnome-terminal-profile: dconf absent — nothing to revert"; return 0; }
  have python3 || { log_info "gnome-terminal-profile: python3 absent — cannot edit the list to revert"; return 0; }
  local existing
  existing="$(_gnome_profile_find)"
  if [[ -z "$existing" ]]; then
    log_info "gnome-terminal-profile: no mahg-dark profile — nothing to revert"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] gnome-terminal-profile: would remove uuid=$existing, drop it from the list, reset default if it points at it"
    return 0
  fi
  local ts backup curlist newlist curdef
  ts="$(date +%Y%m%d-%H%M%S)"
  run mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/gnome-terminal-profiles.$ts.dconf"
  dconf dump "$BASE/" >"$backup" 2>/dev/null || true
  curlist="$(dconf read "$BASE/list" 2>/dev/null || true)"
  newlist="$(_profiles_list_edit remove "$curlist" "$existing")"
  run dconf write "$BASE/list" "$newlist"
  curdef="$(dconf read "$BASE/default" 2>/dev/null || true)"
  if [[ "$curdef" == "'$existing'" ]]; then
    run dconf reset "$BASE/default"
  fi
  run dconf reset -f "$BASE/:$existing/"
  log_ok "gnome-terminal-profile: reverted — removed mahg-dark (uuid=$existing); backup: $backup"
}

# ---- Run --------------------------------------------------------------------
_gnome_profile_apply

log_ok "gnome-terminal-profile module done"
