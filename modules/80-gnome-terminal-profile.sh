#!/usr/bin/env bash
# modules/80-gnome-terminal-profile.sh — branded "mahg-dark" + "mahg-light"
# GNOME Terminal profiles (a dark/light pair).
#
# Creates two GNOME Terminal legacy profiles from the vendored dconf dumps
# (profiles/gnome-terminal/mahg-{dark,light}.dconf), each under a NEW, per-machine
# UUID, adds them to the profiles list WITHOUT deleting any existing profile, and
# sets mahg-dark as the default. Cosmetic sibling of 75-tab-title.sh (also
# GNOME-Terminal-specific), numbered after it and before the gated 90-vscodium.
#
# dconf layout (legacy GNOME Terminal):
#   /org/gnome/terminal/legacy/profiles:/list      -> array of profile UUIDs
#   /org/gnome/terminal/legacy/profiles:/default   -> the default profile UUID
#   /org/gnome/terminal/legacy/profiles:/:<uuid>/  -> one profile's keys
#
# Idempotent: the visible-name is the identity, checked PER profile. A profile is
# (re)created only when no profile with its visible-name exists, so re-runs add no
# duplicates and an existing box that has mahg-dark but not yet mahg-light gets
# only the missing one. A fresh UUID is minted per machine (python3 uuid.uuid4()),
# so two machines never collide. The default is set to mahg-dark ONLY when we
# freshly create it, so a rerun never overrides a user's manual default choice.
# The whole profiles:/ tree is backed up before any write, which also captures the
# prior `default` so a revert can restore it.
#
# Switching dark<->light: GNOME Terminal does NOT follow the desktop color-scheme
# automatically. Pick the active profile by hand (Preferences) or write
# .../default from a script — see README §11 for an optional color-scheme watcher.
#
# Non-GNOME boxes: when `dconf` (or python3) is absent there is nothing to do and
# no rerun can fix it -> recorded as a NOTE, never a failure.
#
# NOTE: a running GNOME Terminal picks up the new profiles on a new window/tab.
#
# Sourced by install.sh; inherits run(), log_*, record_outcome, have(), DRY_RUN.

BASE="/org/gnome/terminal/legacy/profiles:"
BACKUP_DIR="$HOME/.config/lnx-cli-tui-ide/backups"
PROFILE_DIR="$REPO_ROOT/profiles/gnome-terminal"
# Managed profiles, in order. The FIRST is the one set as default on creation.
MANAGED_PROFILES=(mahg-dark mahg-light)
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

# _gnome_profile_find <visible-name> — print the UUID of an existing profile with
# that visible-name, or nothing. Read-only (safe in --dry-run). Quiet on stdout
# except the UUID so callers can capture it.
_gnome_profile_find() {
  local want="$1" list uuid name
  list="$(dconf read "$BASE/list" 2>/dev/null || true)"
  [[ -z "$list" ]] && return 0
  while IFS= read -r uuid; do
    [[ -z "$uuid" ]] && continue
    name="$(dconf read "$BASE/:$uuid/visible-name" 2>/dev/null || true)"
    if [[ "$name" == "'$want'" ]]; then
      printf '%s\n' "$uuid"
      return 0
    fi
  done < <(_profiles_list_uuids "$list")
}

# _gnome_profile_create <name> — mint a fresh UUID, dconf-load the vendored
# profiles/gnome-terminal/<name>.dconf into it, and append the UUID to the list
# (existing profiles preserved). Sets _CREATED_UUID to the new UUID on success.
# Real-run only (callers guard --dry-run). Returns non-zero on a failed load.
_CREATED_UUID=""
_gnome_profile_create() {
  local name="$1" file uuid curlist newlist
  _CREATED_UUID=""
  file="$PROFILE_DIR/$name.dconf"
  uuid="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  # dconf load needs stdin, so it is a direct call (post dry-run guard).
  if ! dconf load "$BASE/:$uuid/" <"$file"; then
    log_error "gnome-terminal-profile: dconf load failed for $name (uuid=$uuid)"
    return 1
  fi
  curlist="$(dconf read "$BASE/list" 2>/dev/null || true)"
  newlist="$(_profiles_list_edit add "$curlist" "$uuid")"
  run dconf write "$BASE/list" "$newlist"
  _CREATED_UUID="$uuid"
}

# _gnome_profile_apply — create + register both managed profiles; default the
# first (mahg-dark) only when freshly created. Idempotent per profile.
_gnome_profile_apply() {
  if ! have dconf; then
    record_outcome NOTE gnome-terminal-profile "dconf not found — GNOME Terminal not installed; a rerun cannot fix this"
    return 0
  fi
  if ! have python3; then
    record_outcome NOTE gnome-terminal-profile "python3 not found — needed for the per-machine UUID and safe list edit"
    return 0
  fi
  local name file
  for name in "${MANAGED_PROFILES[@]}"; do
    file="$PROFILE_DIR/$name.dconf"
    if [[ ! -f "$file" ]]; then
      log_error "gnome-terminal-profile: vendored profile missing: $file"
      return 1
    fi
  done

  # Idempotency: identity is the visible-name, checked per profile. Collect the
  # ones still missing; the default profile (first) is created last-resort below.
  local -a missing=()
  local existing default_name="${MANAGED_PROFILES[0]}"
  for name in "${MANAGED_PROFILES[@]}"; do
    existing="$(_gnome_profile_find "$name")"
    [[ -z "$existing" ]] && missing+=("$name")
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    record_outcome PRESENT gnome-terminal-profile "all managed profiles already present: ${MANAGED_PROFILES[*]}"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] gnome-terminal-profile: would back up the $BASE/ tree to $BACKUP_DIR/"
    for name in "${missing[@]}"; do
      log_info "[DRY] would mint a new UUID and 'dconf load' these keys into $BASE/:<uuid>/ ($name):"
      sed 's/^/[DRY]   /' "$PROFILE_DIR/$name.dconf"
      log_info "[DRY] would append the new UUID to $BASE/list (existing profiles preserved)"
    done
    [[ " ${missing[*]} " == *" $default_name "* ]] \
      && log_info "[DRY] would set $default_name as default ($BASE/default)"
    return 0
  fi

  # --- mutate (real run only) ---
  local ts backup
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

  local -a created=()
  local default_uuid=""
  for name in "${missing[@]}"; do
    _gnome_profile_create "$name" || return 1
    created+=("$name=$_CREATED_UUID")
    [[ "$name" == "$default_name" ]] && default_uuid="$_CREATED_UUID"
  done
  # Only steer `default` when we just created the default profile, so a rerun that
  # only adds the light mirror never overrides a user's manual default choice.
  if [[ -n "$default_uuid" ]]; then
    run dconf write "$BASE/default" "'$default_uuid'"
  fi

  record_outcome INSTALLED gnome-terminal-profile "created: ${created[*]} (added to list; backup=$backup)"
  log_ok "gnome-terminal-profile: created ${created[*]} — open a NEW GNOME Terminal window/tab to see it (mahg-dark is default; switch to mahg-light in Preferences)"
}

# _gnome_profile_revert — remove ONLY our profiles (both mahg-dark and
# mahg-light): drop each from the list, reset `default` if it pointed at one of
# them, and reset that profile's keys. Other profiles are untouched. Backs up
# first. Honors --dry-run. Defined and exercised by tests/test_gnome_profile.sh;
# intentionally NOT auto-invoked here.
# shellcheck disable=SC2329  # invoked by tests/test_gnome_profile.sh, not in this file
_gnome_profile_revert() {
  have dconf || { log_info "gnome-terminal-profile: dconf absent — nothing to revert"; return 0; }
  have python3 || { log_info "gnome-terminal-profile: python3 absent — cannot edit the list to revert"; return 0; }
  local name existing
  local -a found=()
  for name in "${MANAGED_PROFILES[@]}"; do
    existing="$(_gnome_profile_find "$name")"
    [[ -n "$existing" ]] && found+=("$name=$existing")
  done
  if [[ "${#found[@]}" -eq 0 ]]; then
    log_info "gnome-terminal-profile: no managed profiles — nothing to revert"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] gnome-terminal-profile: would remove ${found[*]}, drop them from the list, reset default if it points at one"
    return 0
  fi
  local ts backup curlist curdef uuid pair
  ts="$(date +%Y%m%d-%H%M%S)"
  run mkdir -p "$BACKUP_DIR"
  backup="$BACKUP_DIR/gnome-terminal-profiles.$ts.dconf"
  dconf dump "$BASE/" >"$backup" 2>/dev/null || true
  for pair in "${found[@]}"; do
    uuid="${pair#*=}"
    curlist="$(dconf read "$BASE/list" 2>/dev/null || true)"
    run dconf write "$BASE/list" "$(_profiles_list_edit remove "$curlist" "$uuid")"
    curdef="$(dconf read "$BASE/default" 2>/dev/null || true)"
    [[ "$curdef" == "'$uuid'" ]] && run dconf reset "$BASE/default"
    run dconf reset -f "$BASE/:$uuid/"
  done
  log_ok "gnome-terminal-profile: reverted — removed ${found[*]}; backup: $backup"
}

# ---- Run --------------------------------------------------------------------
_gnome_profile_apply

log_ok "gnome-terminal-profile module done"
