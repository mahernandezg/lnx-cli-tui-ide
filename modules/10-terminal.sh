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
#
# On Termux (Android) the terminal IS Termux, which has no fontconfig and renders
# from a single ~/.termux/font.ttf. There the module takes a different path
# (_install_termux_font): it writes that one TTF and reloads, skipping the
# fontconfig/DejaVu branch entirely. See the orchestration block at the bottom.

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

# ---- Termux font (Android: the terminal IS Termux) --------------------------
# Termux has no fontconfig and no separate emulator: it renders from a single TTF
# at ~/.termux/font.ttf, applied with `termux-reload-settings`. So on Android the
# "terminal font" is that one file. We drop in the JetBrainsMono Nerd Font (Mono
# Regular) so yazi/lazygit icons and the Starship glyphs render. Idempotent: an
# existing font.ttf is left untouched; non-fatal and offline-graceful throughout.
_install_termux_font() {
  local termux_dir="$HOME/.termux"
  local dest="$termux_dir/font.ttf"
  if [[ -f "$dest" ]]; then
    record_outcome PRESENT termux-font "$dest already present; leaving it in place"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would fetch JetBrainsMono Nerd Font, write ~/.termux/font.ttf, then termux-reload-settings"
    record_outcome NOTE termux-font "dry-run; would install Nerd Font as ~/.termux/font.ttf"
    return 0
  fi
  require_network "termux-font" || {
    record_outcome DEFERRED termux-font "no network; rerun online to fetch the Nerd Font"
    return 0
  }
  have curl || {
    record_outcome NOTE termux-font "curl missing; 'pkg install curl' then rerun for terminal icons"
    return 0
  }
  if ! have unzip; then
    apt_install unzip || {
      record_outcome NOTE termux-font "unzip unavailable; 'pkg install unzip' then rerun"
      return 0
    }
  fi
  run mkdir -p "$termux_dir"
  local tmp="${TMPDIR:-/tmp}"
  local zip="$tmp/JetBrainsMono.zip"
  local work="$tmp/jbm-nerd"
  run_quiet curl -L -o "$zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" || {
      record_outcome DEFERRED termux-font "Nerd Font download failed; rerun online"
      return 0
    }
  run rm -rf "$work"
  run mkdir -p "$work"
  if ! run_quiet unzip -o "$zip" -d "$work"; then
    record_outcome DEFERRED termux-font "could not unzip Nerd Font archive; rerun"
    run rm -f "$zip"
    return 0
  fi
  # Pick a single-width Mono Regular face; fall back progressively. The `|| true`
  # keeps a SIGPIPE from `head` closing the pipe early from tripping set -e.
  local face="" pat
  for pat in '*NerdFontMono-Regular.ttf' '*NerdFont-Regular.ttf' '*-Regular.ttf' '*.ttf'; do
    face="$(find "$work" -type f -iname "$pat" 2>/dev/null | head -n1 || true)"
    [[ -n "$face" ]] && break
  done
  if [[ -z "$face" ]]; then
    record_outcome DEFERRED termux-font "no .ttf found in Nerd Font archive; rerun"
    run rm -rf "$zip" "$work"
    return 0
  fi
  run cp "$face" "$dest"
  run rm -rf "$zip" "$work"
  if have termux-reload-settings; then run_quiet termux-reload-settings || true; fi
  record_outcome INSTALLED termux-font "JetBrainsMono Nerd Font -> $dest (reloaded)"
}

# ---- Orchestrate ------------------------------------------------------------
if [[ "${DETECT_PLATFORM:-debian}" == "termux" ]]; then
  log_info "terminal: Termux IS the terminal on Android; installing its font (~/.termux/font.ttf)"
  _install_termux_font
  log_ok "terminal module done (Termux font; emulator = Termux)"
else
  log_info "terminal: using the system GNOME Terminal; installing terminal fonts only"
  _install_nerd_font
  _install_glyph_fallback_font
  log_ok "terminal module done (fonts; emulator = system GNOME Terminal)"
fi
