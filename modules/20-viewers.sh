#!/usr/bin/env bash
# modules/20-viewers.sh — viewers & navigation: bat, glow, yazi, ripgrep, fzf.
#
# Debian stable ships some of these old or not at all. Each tool declares:
#   apt (when recent enough) -> official release binary / cargo -> done.
# ripgrep and fzf are fine from apt on modern Debian; bat ships as 'batcat';
# glow and yazi often need a release binary.

# ---- helpers ----------------------------------------------------------------
# Release-binary installs go through release_install_bin() in lib/release.sh, so
# the fetch/extract/install logic lives in one place and is shared with the ruff
# GitHub fallback in modules/40-helix.sh.

# ---- bat --------------------------------------------------------------------
# bat: code with syntax colors + git gutter. On Debian the binary is 'batcat';
# we add a 'bat' shim so muscle memory and downstream tools work.
_bat_present() { have bat || have batcat; }
method_bat_present() { _bat_present || return 1; log_info "bat already present"; }
method_bat_apt() { apt_install bat || return 1; verify _bat_present; }
_bat_shim() {
  if have batcat && ! have bat; then
    run mkdir -p "$HOME/.local/bin"
    run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    export PATH="$HOME/.local/bin:$PATH"
    log_ok "bat: added 'bat' -> batcat shim"
  fi
}

# ---- ripgrep ----------------------------------------------------------------
method_rg_present() { have rg || return 1; log_info "ripgrep already present"; }
method_rg_apt() { apt_install ripgrep || return 1; verify have rg; }

# ---- fzf --------------------------------------------------------------------
method_fzf_present() { have fzf || return 1; log_info "fzf already present"; }
method_fzf_apt() { apt_install fzf || return 1; verify have fzf; }
method_fzf_git() {
  dry_skip "clone junegunn/fzf and build the binary" && return 0
  require_network "fzf" || return 1
  [[ -d "$HOME/.fzf" ]] || run git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" || return 1
  run "$HOME/.fzf/install" --bin || return 1
  run mkdir -p "$HOME/.local/bin"
  run ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
  export PATH="$HOME/.local/bin:$PATH"
  verify have fzf
}

# ---- glow (rendered Markdown) ----------------------------------------------
method_glow_present() { have glow || return 1; log_info "glow already present"; }
method_glow_apt() { apt_version_ge glow 1.5 || return 1; apt_install glow || return 1; verify have glow; }
method_glow_release() {
  local v="2.0.0" arch
  case "$DETECT_ARCH" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "glow: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  release_install_bin glow \
    "https://github.com/charmbracelet/glow/releases/download/v${v}/glow_${v}_Linux_${arch}.tar.gz" \
    "glow"
}

# ---- yazi (file manager) ----------------------------------------------------
method_yazi_present() { have yazi || return 1; log_info "yazi already present"; }
method_yazi_apt() { apt_install yazi || return 1; verify have yazi; }
# Primary path: resolve the latest stable release at runtime (no pinned version).
method_yazi_release() {
  local target tag url
  case "$DETECT_ARCH" in
    x86_64)  target="x86_64-unknown-linux-gnu" ;;
    aarch64) target="aarch64-unknown-linux-gnu" ;;
    *) log_warn "yazi: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tag="$(github_latest_tag sxyazi/yazi)" || return 1   # fall through (apt/cargo) on failure
  url="https://github.com/sxyazi/yazi/releases/download/${tag}/yazi-${target}.zip"
  log_info "yazi: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install yazi ${tag} (no fetch performed)"
    return 0
  fi
  release_install_bin yazi "$url" "yazi"
}
method_yazi_cargo() {
  have cargo || return 1
  run cargo install --locked yazi-fs yazi-cli 2>/dev/null || run cargo install --locked yazi || return 1
  verify have yazi
}

# ---- run all ----------------------------------------------------------------
try_methods "bat"     method_bat_present method_bat_apt
_bat_shim
try_methods "ripgrep" method_rg_present  method_rg_apt
try_methods "fzf"     method_fzf_present method_fzf_apt method_fzf_git
try_methods "glow"    method_glow_present method_glow_apt method_glow_release
# yazi: prefer the latest-resolved release binary; apt (when packaged) then cargo as fallbacks.
try_methods "yazi"    method_yazi_present method_yazi_release method_yazi_apt method_yazi_cargo

# yazi config: show hidden files/folders by default and tint them so they stand out
# (backed up then symlinked by the shared helper).
link_dotfile "$REPO_ROOT/dotfiles/yazi/yazi.toml"  "$HOME/.config/yazi/yazi.toml"
link_dotfile "$REPO_ROOT/dotfiles/yazi/theme.toml" "$HOME/.config/yazi/theme.toml"

log_ok "viewers module done"
