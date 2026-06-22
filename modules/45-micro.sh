#!/usr/bin/env bash
# modules/45-micro.sh — micro: a simple, modeless terminal editor for quick edits.
#
# Complements Helix (the main, powerful editor): micro is the "GUI-like in a TUI"
# option — Ctrl+S save, Ctrl+C/V copy/paste, Ctrl+Q quit — for fast edits. Installs
# the official latest-stable binary into ~/.local/bin (already on PATH; no sudo),
# with apt as a fallback. VERIFY is non-destructive; INSTALL is idempotent; honors
# --dry-run and DEFERs honestly offline. A tiny QoL config is linked from the repo.
# Sourced by install.sh (inherits try_methods, github_latest_tag, release_install_bin,
# apt_install, link_dotfile, run, log_*, record_outcome, DRY_RUN, DETECT_ARCH, HOME).

method_micro_present() { have micro || return 1; log_info "micro already present"; }

# Primary: latest stable GitHub release binary -> ~/.local/bin (shared helper).
method_micro_release() {
  local arch tag ver url
  case "${DETECT_ARCH:-$(uname -m)}" in
    x86_64)  arch="linux64" ;;
    aarch64) arch="linux-arm64" ;;
    *) log_warn "micro: unsupported arch ${DETECT_ARCH:-$(uname -m)}"; return 1 ;;
  esac
  tag="$(github_latest_tag zyedidia/micro)" || return 1   # fall through to apt on failure
  ver="${tag#v}"   # asset filename uses the bare version (no leading 'v')
  url="https://github.com/zyedidia/micro/releases/download/${tag}/micro-${ver}-${arch}.tar.gz"
  log_info "micro: latest release ${tag} -> ${url}"
  release_install_bin micro "$url" "micro"
}

# Fallback: apt (older, but works offline / when the release path fails).
method_micro_apt() { apt_install micro || return 1; verify have micro; }

# Link the vendored QoL config (idempotent; backs up any existing file). The
# colorscheme stays micro's default — functional first; a branded scheme can come later.
_micro_config() {
  link_dotfile "$REPO_ROOT/dotfiles/micro/settings.json" "$HOME/.config/micro/settings.json"
}

# ---- Orchestrate ------------------------------------------------------------
if have micro; then
  record_outcome PRESENT micro "$(micro --version 2>/dev/null | head -1 || echo present)"
elif [[ "${DRY_RUN:-0}" == "1" ]]; then
  log_info "[DRY] would install micro (latest GitHub release -> ~/.local/bin, or apt fallback)"
  record_outcome NOTE micro "dry-run; would install micro"
elif try_methods "micro" method_micro_release method_micro_apt; then
  record_outcome INSTALLED micro "$(micro --version 2>/dev/null | head -1 || echo installed)"
else
  record_outcome DEFERRED micro "release + apt both unavailable (no network/curl?); rerun on an open network"
fi

_micro_config

log_ok "micro module done"
