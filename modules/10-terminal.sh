#!/usr/bin/env bash
# modules/10-terminal.sh — terminal fonts.
#
# The stack's terminal emulator is the system's GNOME Terminal (VTE) — the
# installer does NOT install or replace a terminal. GNOME Terminal is kept for its
# tabs and integration, with tmux for splits (see the tmux module); euporie inline
# plots ride GNOME Terminal's own image support (sixel).
#
# So this module only installs the FONTS a terminal needs:
#   - JetBrainsMono Nerd Font — the icons used by yazi & lazygit.
#   - fonts-dejavu-core — fontconfig fallback for the few standard-Unicode glyphs
#     in the Starship prompt that the Nerd Font doesn't cover.
# Both are idempotent and degrade gracefully offline.

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

# ---- Glyph-fallback font (DejaVu) -------------------------------------------
# The Starship prompt uses a few STANDARD-Unicode glyphs — ⤳ (U+2933), ⋿ (U+22FF),
# ⋺ (U+22FA) in dotfiles/starship/starship.toml — that are NOT in the JetBrainsMono
# Nerd Font (they are not Nerd-Font PUA icons). They render via fontconfig FALLBACK
# to DejaVu, which DOES cover those blocks (verified: `fc-list :charset=2933`). On a
# minimal box without DejaVu the prompt would show tofu, so guarantee the fallback.
# fonts-dejavu-core is tiny; apt makes this idempotent.
_install_glyph_fallback_font() {
  local pkg="fonts-dejavu-core"
  if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    record_outcome PRESENT "$pkg" "DejaVu present — covers the Starship Unicode glyphs (⤳ ⋿ ⋺)"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would apt-get install $pkg (DejaVu — fontconfig fallback for the Starship glyphs)"
    record_outcome NOTE "$pkg" "dry-run; would install DejaVu glyph-fallback font"
    return 0
  fi
  if ! apt_can_use; then
    record_outcome NOTE "$pkg" "apt-get unavailable; install $pkg for full Starship glyph coverage"
    return 0
  fi
  if apt_install "$pkg"; then
    have fc-cache && run_quiet fc-cache -f >/dev/null 2>&1
    record_outcome INSTALLED "$pkg" "DejaVu — fontconfig fallback for the Starship Unicode glyphs"
  else
    record_outcome DEFERRED "$pkg" "apt install failed; rerun on open network for Starship glyph coverage"
  fi
}

# ---- Orchestrate ------------------------------------------------------------
log_info "terminal: using the system GNOME Terminal; installing terminal fonts only"
_install_nerd_font
_install_glyph_fallback_font

log_ok "terminal module done (fonts; emulator = system GNOME Terminal)"
