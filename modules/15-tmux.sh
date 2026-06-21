#!/usr/bin/env bash
# modules/15-tmux.sh — tmux (terminal multiplexer) + the vendored mahg config.
#
# tmux gives splits and persistent sessions on top of GNOME Terminal's tabs. It is
# NOT auto-started — it's launched by hand when needed (no .bashrc hook). This
# module installs tmux (apt, with an honest deferral when apt is unavailable) and
# symlinks the branded config to ~/.config/tmux/tmux.conf (XDG; tmux >= 3.1).
# Idempotent, backs up any existing config, honors --dry-run.

_tmux_present() { have tmux; }

_install_tmux() {
  local pkg="tmux"
  if _tmux_present; then
    record_outcome PRESENT "$pkg" "$(tmux -V 2>/dev/null || echo present)"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would apt-get install $pkg"
    record_outcome NOTE "$pkg" "dry-run; would install tmux"
    return 0
  fi
  if ! apt_can_use; then
    record_outcome NOTE "$pkg" "apt-get unavailable; install $pkg for splits/persistent sessions"
    return 0
  fi
  if apt_install "$pkg"; then
    record_outcome INSTALLED "$pkg" "apt"
  else
    record_outcome DEFERRED "$pkg" "apt install failed; rerun on open network"
  fi
}

# Link the branded config regardless of how the install went (it just waits for
# tmux to exist). XDG path keeps $HOME tidy; link_dotfile backs up any real file.
_link_tmux_conf() {
  link_dotfile "$REPO_ROOT/dotfiles/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
}

_install_tmux
_link_tmux_conf

log_ok "tmux module done (manual launch; prefix C-a, splits | and -)"
