#!/usr/bin/env bash
# modules/20-viewers.sh — viewers & navigation: bat, glow, yazi, ripgrep, fzf.
#
# Debian stable ships some of these old or not at all. Each tool declares:
#   apt (when recent enough) -> official release binary / cargo -> done.
# ripgrep and fzf are fine from apt on modern Debian; bat ships as 'batcat';
# glow and yazi often need a release binary.

# ---- helpers ----------------------------------------------------------------
# install a single static binary from a tarball release into ~/.local/bin.
# _release_bin <name> <url> <path-inside-archive>
_release_bin() {
  local name="$1" url="$2" inner="$3" tmp
  dry_skip "download and install '$name' from a release archive" && return 0
  require_network "$name" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/archive" "$url" || { rm -rf "$tmp"; return 1; }
  if [[ "$url" == *.tar.gz || "$url" == *.tgz ]]; then
    run_quiet tar -xzf "$tmp/archive" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  elif [[ "$url" == *.zip ]]; then
    have unzip || apt_install unzip || true
    run_quiet unzip -o "$tmp/archive" -d "$tmp" || { rm -rf "$tmp"; return 1; }
  fi
  local found
  found="$(find "$tmp" -type f -name "$inner" | head -n1)"
  [[ -z "$found" ]] && { log_warn "$name: binary '$inner' not found in archive"; rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run install -m 0755 "$found" "$HOME/.local/bin/$inner"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  have "$inner"
}

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
  _release_bin glow \
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
  _release_bin yazi "$url" "yazi"
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

log_ok "viewers module done"
