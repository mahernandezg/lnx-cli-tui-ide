#!/usr/bin/env bash
# modules/70-starship.sh — Starship cross-shell prompt (two-line).
#
# Chain (primary first):
#   1. present            -> already on PATH, skip (idempotent)
#   2. release-latest     -> latest stable tag via lib/github.sh, install binary
#                            to ~/.local/bin (no pinned version)
#   3. official installer -> sh.starship.rs script, only if the release path fails
#
# Config (dotfiles/starship/starship.toml) is symlinked to ~/.config/starship.toml
# with the shared backup-then-link helper. Bash activation is written to ~/.bashrc
# exactly once, guarded by a managed marker block so re-runs never duplicate it.

_starship_present() { have starship; }

method_starship_present() {
  _starship_present || return 1
  log_info "starship already present: $(starship --version 2>/dev/null | head -1 || echo present)"
}

# Primary install path: resolve the latest stable release at runtime (no pinned version).
method_starship_release() {
  local arch tag url tmp
  case "$DETECT_ARCH" in
    x86_64)  arch="x86_64-unknown-linux-gnu" ;;
    aarch64) arch="aarch64-unknown-linux-gnu" ;;
    *) log_warn "starship: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tag="$(github_latest_tag starship/starship)" || return 1   # fall through to official installer
  url="https://github.com/starship/starship/releases/download/${tag}/starship-${arch}.tar.gz"
  log_info "starship: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install starship ${tag} (no fetch performed)"
    return 0
  fi
  require_network "starship" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/starship.tar.gz" "$url" || { rm -rf "$tmp"; return 1; }
  run_quiet tar -xzf "$tmp/starship.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run install -m 0755 "$tmp/starship" "$HOME/.local/bin/starship"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  verify _starship_present
}

# Later fallback: the official installer script.
method_starship_official() {
  dry_skip "install starship via the official installer (sh.starship.rs)" && return 0
  require_network "starship" || return 1
  have curl || { log_warn "starship: curl missing"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run_quiet bash -c "curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir '$HOME/.local/bin' --yes" || return 1
  export PATH="$HOME/.local/bin:$PATH"
  verify _starship_present
}

# ---- Bash activation (idempotent, marker-guarded) ---------------------------
_starship_activate_bash() {
  local rc="$HOME/.bashrc"
  local begin="# >>> lnx-cli-tui-ide: starship >>>"
  local end="# <<< lnx-cli-tui-ide: starship <<<"
  # Written verbatim into .bashrc; it must resolve at shell startup, not here.
  # Guarded so a machine without starship on PATH doesn't error on shell startup.
  # shellcheck disable=SC2016
  local init_line='command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"'

  # Already activated? The unique marker is the single source of truth — never
  # append twice on a re-run.
  if [[ -f "$rc" ]] && grep -qF "$begin" "$rc" 2>/dev/null; then
    log_info "starship: bash activation already present in $rc (skipping)"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would append the following managed block to $rc:"
    log_info "[DRY]   $begin"
    log_info "[DRY]   $init_line"
    log_info "[DRY]   $end"
    return 0
  fi

  {
    printf '\n%s\n' "$begin"
    printf '%s\n' "$init_line"
    printf '%s\n' "$end"
  } >>"$rc"
  log_ok "starship: added bash activation to $rc"
}

# ---- Orchestrate ------------------------------------------------------------
try_methods "starship" \
  method_starship_present \
  method_starship_release \
  method_starship_official

# Two-line prompt config (backed up then symlinked by the shared helper).
link_dotfile "$REPO_ROOT/dotfiles/starship/starship.toml" "$HOME/.config/starship.toml"

# Write bash activation to ~/.bashrc (the required target). Only ~/.bashrc is
# managed; for a non-bash login shell we leave a clear TODO and never touch its rc.
_starship_activate_bash
case "${SHELL:-}" in
  */zsh)  log_info "starship: login shell is zsh — TODO: add 'eval \"\$(starship init zsh)\"' to ~/.zshrc (not written automatically)." ;;
  */fish) log_info "starship: login shell is fish — TODO: add 'starship init fish | source' to ~/.config/fish/config.fish (not written automatically)." ;;
esac

log_ok "starship module done"
