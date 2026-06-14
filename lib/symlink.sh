#!/usr/bin/env bash
# lib/symlink.sh — dotfile symlinking with backup. Bash-only (no GNU Stow).
#
# link_dotfile <src-in-repo> <dest-in-home>:
#   - If dest already points at src: nothing to do (idempotent).
#   - If dest is some other real file/dir/symlink: back it up to
#     dest.bak.<timestamp>, then symlink.
#   - Creates parent directories as needed.
# Everything mutating goes through run(), so --dry-run is honored.
[[ -n "${_LIB_SYMLINK_SOURCED:-}" ]] && return 0
_LIB_SYMLINK_SOURCED=1

link_dotfile() {
  local src="$1" dest="$2"

  if [[ ! -e "$src" ]]; then
    log_error "link: source missing: $src"
    return 1
  fi

  # Already linked to our repo file? Idempotent no-op.
  if [[ -L "$dest" ]]; then
    local cur
    cur="$(readlink -f "$dest" 2>/dev/null || true)"
    if [[ "$cur" == "$(readlink -f "$src")" ]]; then
      log_debug "link: already linked: $dest -> $src"
      return 0
    fi
  fi

  run mkdir -p "$(dirname "$dest")"

  # Back up an existing real target (or a symlink pointing elsewhere).
  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup
    backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    log_warn "link: backing up existing $dest -> $backup"
    run mv -- "$dest" "$backup"
  fi

  run ln -s -- "$src" "$dest"
  log_ok "link: $dest -> $src"
}
