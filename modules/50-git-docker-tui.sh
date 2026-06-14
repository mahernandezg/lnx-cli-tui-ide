#!/usr/bin/env bash
# modules/50-git-docker-tui.sh — lazygit and lazydocker TUIs.
# Both are usually too old / absent in Debian stable: apt -> GitHub release binary.

# ---- lazygit ----------------------------------------------------------------
method_lazygit_present() { have lazygit || return 1; log_info "lazygit already present"; }
method_lazygit_apt() { apt_version_ge lazygit 0.40 || return 1; apt_install lazygit || return 1; verify have lazygit; }
# Primary path: resolve the latest stable release at runtime (no pinned version).
method_lazygit_release() {
  local arch tmp tag ver url
  case "$DETECT_ARCH" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "lazygit: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tag="$(github_latest_tag jesseduffield/lazygit)" || return 1   # fall through to apt on failure
  ver="${tag#v}"   # asset filename uses the bare version (no leading 'v')
  url="https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_${arch}.tar.gz"
  log_info "lazygit: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install lazygit ${tag} (no fetch performed)"
    return 0
  fi
  require_network "lazygit" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/lazygit.tar.gz" "$url" || { rm -rf "$tmp"; return 1; }
  run_quiet tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run install -m 0755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  verify have lazygit
}

# ---- lazydocker -------------------------------------------------------------
method_lazydocker_present() { have lazydocker || return 1; log_info "lazydocker already present"; }
method_lazydocker_apt() { apt_version_ge lazydocker 0.20 || return 1; apt_install lazydocker || return 1; verify have lazydocker; }
# Primary path: resolve the latest stable release at runtime (shared helper — same
# code path as the other three tools).
method_lazydocker_release() {
  local arch tmp tag ver url
  case "$DETECT_ARCH" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "lazydocker: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tag="$(github_latest_tag jesseduffield/lazydocker)" || return 1   # fall through to apt on failure
  ver="${tag#v}"   # asset filename uses the bare version (no leading 'v')
  url="https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${ver}_Linux_${arch}.tar.gz"
  log_info "lazydocker: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install lazydocker ${tag} (no fetch performed)"
    return 0
  fi
  require_network "lazydocker" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/lazydocker.tar.gz" "$url" || { rm -rf "$tmp"; return 1; }
  run_quiet tar -xzf "$tmp/lazydocker.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run install -m 0755 "$tmp/lazydocker" "$HOME/.local/bin/lazydocker"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  verify have lazydocker
}

# Both prefer the latest-resolved release binary; apt is the fallback (and is often
# absent / behind for these tools on Debian stable).
try_methods "lazygit"    method_lazygit_present    method_lazygit_release    method_lazygit_apt
try_methods "lazydocker" method_lazydocker_present method_lazydocker_release method_lazydocker_apt

if ! have docker; then
  log_info "note: docker engine not detected — lazydocker installs fine but needs Docker to be useful"
fi

log_ok "git/docker TUI module done"
