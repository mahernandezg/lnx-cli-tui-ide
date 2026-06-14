#!/usr/bin/env bash
# modules/10-terminal.sh — terminal emulator.
#
# Hardware-adaptive choice (the central reason this engine exists):
#   - OpenGL >= 3.3 detected  -> kitty (uses the GPU; kitty graphics protocol is
#     why euporie can show inline plots).
#   - OpenGL < 3.3 or undetectable -> WezTerm in software-rendering mode
#     (front_end = "Software"), which still speaks the kitty graphics protocol.
#
# kitty install itself has its own fallback chain:
#   1. already present -> skip
#   2. official installer (newer than Debian stable) when online
#   3. apt (older, but works offline / when the installer fails)
#
# Config + desktop integration (menu entry, icon, default terminal) installed
# after a terminal is in place. Dotfiles are symlinked from the repo.

_kitty_present()  { have kitty; }
_wezterm_present(){ have wezterm; }

# ---- kitty methods ----------------------------------------------------------
method_kitty_present() {
  _kitty_present || return 1
  log_info "kitty already installed: $(kitty --version 2>/dev/null || echo present)"
}

method_kitty_official() {
  dry_skip "install kitty via the official installer (sw.kovidgoyal.net)" && return 0
  require_network "kitty" || return 1
  have curl || { log_warn "kitty: curl missing"; return 1; }
  # Official installer drops kitty under ~/.local/kitty.app and a launcher.
  run_quiet bash -c 'curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin' || return 1
  # Symlink the binaries onto PATH (installer puts them in ~/.local/kitty.app/bin).
  if [[ -x "$HOME/.local/kitty.app/bin/kitty" ]]; then
    run mkdir -p "$HOME/.local/bin"
    run ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
    run ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
    export PATH="$HOME/.local/bin:$PATH"
  fi
  _kitty_present
}

method_kitty_apt() {
  apt_install kitty || return 1
  verify _kitty_present
}

# ---- wezterm (software-render) fallback methods -----------------------------
method_wezterm_present() {
  _wezterm_present || return 1
  log_info "wezterm already installed: $(wezterm --version 2>/dev/null || echo present)"
}

method_wezterm_apt() {
  apt_install wezterm || return 1
  verify _wezterm_present
}

method_wezterm_release() {
  dry_skip "install WezTerm from a GitHub .deb release" && return 0
  require_network "wezterm" || return 1
  have curl || return 1
  local deb="/tmp/wezterm.deb" url
  # Use the distro-tagged nightly .deb; broad compatibility on Debian.
  url="https://github.com/wez/wezterm/releases/download/nightly/wezterm-nightly.Debian12.deb"
  run_quiet curl -L -o "$deb" "$url" || return 1
  run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb" || return 1
  run rm -f "$deb"
  verify _wezterm_present
}

# ---- desktop integration ----------------------------------------------------
# Register the chosen terminal in the application menu, install its icon, and set
# it as the x-terminal-emulator default when running under Debian's alternatives.
_install_kitty_desktop() {
  local app="$HOME/.local/kitty.app"
  # The official installer ships a desktop file + icon under the app dir.
  if [[ -d "$app" ]]; then
    run mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons"
    if [[ -f "$app/share/applications/kitty.desktop" ]]; then
      run cp "$app/share/applications/kitty.desktop" "$HOME/.local/share/applications/kitty.desktop"
      # Point Exec/Icon at the installed location.
      run sed -i "s|Icon=kitty|Icon=$app/share/icons/hicolor/256x256/apps/kitty.png|" \
        "$HOME/.local/share/applications/kitty.desktop" || true
      run sed -i "s|Exec=kitty|Exec=$HOME/.local/bin/kitty|" \
        "$HOME/.local/share/applications/kitty.desktop" || true
    fi
  fi
  _set_default_terminal kitty
}

_install_wezterm_desktop() {
  # apt/.deb installs already register a .desktop entry; just set the default.
  _set_default_terminal wezterm
}

# _set_default_terminal <bin> — register as x-terminal-emulator (Debian alternatives).
_set_default_terminal() {
  local bin="$1" path
  path="$(command -v "$bin" 2>/dev/null || true)"
  [[ -z "$path" ]] && return 0
  if have update-alternatives && [[ -n "$SUDO" || "$(id -u)" -eq 0 ]]; then
    run $SUDO update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$path" 50 || true
    run $SUDO update-alternatives --set x-terminal-emulator "$path" || true
    log_ok "default terminal set to $bin"
  else
    log_warn "cannot set default terminal (no sudo/update-alternatives); skipping"
  fi
}

# ---- Nerd Font (icons for yazi & lazygit) -----------------------------------
_install_nerd_font() {
  local font_dir="$HOME/.local/share/fonts"
  if ls "$font_dir"/*NerdFont* "$font_dir"/*"Nerd Font"* >/dev/null 2>&1; then
    log_info "Nerd Font already present; skipping"
    return 0
  fi
  require_network "nerd-font" || { log_warn "no network for Nerd Font; relying on system fonts"; return 0; }
  have curl || { log_warn "curl missing; skipping Nerd Font"; return 0; }
  run mkdir -p "$font_dir"
  local zip="/tmp/JetBrainsMono.zip"
  run_quiet curl -L -o "$zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || {
      log_warn "Nerd Font download failed"; return 0; }
  if ! have unzip; then
    apt_install unzip || { log_warn "unzip unavailable; cannot install Nerd Font"; return 0; }
  fi
  run_quiet unzip -o "$zip" -d "$font_dir/JetBrainsMonoNerdFont" || true
  run rm -f "$zip"
  if have fc-cache; then
    run_quiet fc-cache -f "$font_dir" || true
  fi
  log_ok "Nerd Font (JetBrainsMono) installed"
}

# ---- Orchestrate ------------------------------------------------------------
TERMINAL_CHOSEN=""

if opengl_ge_33; then
  log_info "terminal: OpenGL >= 3.3 -> preferring kitty (GPU)"
  if try_methods "kitty" method_kitty_present method_kitty_official method_kitty_apt; then
    TERMINAL_CHOSEN="kitty"
  else
    log_warn "terminal: kitty failed despite capable GPU; falling back to WezTerm"
    if try_methods "wezterm" method_wezterm_present method_wezterm_apt method_wezterm_release; then
      TERMINAL_CHOSEN="wezterm"
    fi
  fi
else
  log_info "terminal: OpenGL < 3.3 or undetectable -> WezTerm software-render"
  if try_methods "wezterm" method_wezterm_present method_wezterm_apt method_wezterm_release; then
    TERMINAL_CHOSEN="wezterm"
  else
    log_warn "terminal: WezTerm failed; last resort kitty via apt (may need software GL)"
    if try_methods "kitty" method_kitty_present method_kitty_apt; then
      TERMINAL_CHOSEN="kitty"
    fi
  fi
fi

if [[ -z "$TERMINAL_CHOSEN" ]]; then
  log_error "terminal: no emulator could be installed"
  return 1
fi
log_ok "terminal chosen: $TERMINAL_CHOSEN"

# ---- Fonts + config + desktop integration -----------------------------------
_install_nerd_font

# Size kitty scrollback to RAM by templating the value into the linked config.
# We symlink the static config, then write a small machine-local include that
# kitty.conf pulls in (keeps the committed config clean of per-machine values).
SCROLLBACK="$(scrollback_lines_for_ram)"

if [[ "$TERMINAL_CHOSEN" == "kitty" ]]; then
  link_dotfile "$REPO_ROOT/dotfiles/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
  link_dotfile "$REPO_ROOT/dotfiles/kitty/ssh.conf"   "$HOME/.config/kitty/ssh.conf"
  # Machine-local include (not a symlink; per-host tuning lives here).
  local_inc="$HOME/.config/kitty/local.conf"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would write scrollback_lines $SCROLLBACK to $local_inc"
  else
    run mkdir -p "$HOME/.config/kitty"
    {
      printf '# Generated by lnx-cli-tui-ide on this machine. Not committed.\n'
      printf 'scrollback_lines %s\n' "$SCROLLBACK"
    } >"$local_inc"
    log_ok "kitty: scrollback_lines=$SCROLLBACK -> $local_inc"
  fi
  _install_kitty_desktop
else
  link_dotfile "$REPO_ROOT/dotfiles/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
  # WezTerm reads scrollback from its lua; write a machine-local override file.
  wez_local="$HOME/.config/wezterm/local.lua"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would write scrollback_lines $SCROLLBACK to $wez_local"
  else
    run mkdir -p "$HOME/.config/wezterm"
    {
      printf -- '-- Generated by lnx-cli-tui-ide. Not committed.\n'
      printf 'return { scrollback_lines = %s }\n' "$SCROLLBACK"
    } >"$wez_local"
    log_ok "wezterm: scrollback_lines=$SCROLLBACK -> $wez_local"
  fi
  _install_wezterm_desktop
fi

log_ok "terminal module done (chosen: $TERMINAL_CHOSEN)"
