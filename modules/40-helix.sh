#!/usr/bin/env bash
# modules/40-helix.sh — Helix editor + config + language servers.
#
# Debian ships Helix only recently; declare apt -> official release binary -> cargo.
# LSPs: vtsls (TypeScript) and ruff (Python). basedpyright is
# installed but DISABLED by default in languages.toml to save RAM; enable per
# session when types are needed (see README).

_hx_present() { have hx; }

method_helix_present() { _hx_present || return 1; log_info "helix already present: $(hx --version 2>/dev/null || echo present)"; }
method_helix_apt() { apt_install helix || return 1; verify _hx_present; }
# Primary path: resolve the latest stable release at runtime (no pinned version).
method_helix_release() {
  local target tag url tmp
  case "$DETECT_ARCH" in
    x86_64)  target="x86_64-linux" ;;
    aarch64) target="aarch64-linux" ;;
    *) log_warn "helix: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tag="$(github_latest_tag helix-editor/helix)" || return 1   # fall through (apt/cargo) on failure
  # Helix release assets embed the tag verbatim (no leading 'v'), e.g. 25.07.1.
  url="https://github.com/helix-editor/helix/releases/download/${tag}/helix-${tag}-${target}.tar.xz"
  log_info "helix: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install helix ${tag} (+ runtime/) (no fetch performed)"
    return 0
  fi
  require_network "helix" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/hx.tar.xz" "$url" || { rm -rf "$tmp"; return 1; }
  run_quiet tar -xJf "$tmp/hx.tar.xz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  local dir
  dir="$(find "$tmp" -maxdepth 1 -type d -name 'helix-*' | head -n1)"
  [[ -z "$dir" ]] && { rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin" "$HOME/.config/helix"
  run install -m 0755 "$dir/hx" "$HOME/.local/bin/hx"
  # Helix needs its runtime/ directory; place it where hx looks by default.
  run cp -r "$dir/runtime" "$HOME/.config/helix/runtime"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  verify _hx_present
}
method_helix_cargo() {
  have cargo || return 1
  run cargo install --locked helix-term || return 1
  verify _hx_present
}

# ---- Language servers -------------------------------------------------------
# vtsls (TypeScript) via npm; ruff & basedpyright via PyPI. ruff additionally has
# a GitHub release-binary fallback so a blocked PyPI never leaves Python without a
# linter/formatter. All three feed the per-tool outcome ledger (lib/outcome.sh)
# so the final summary is honest about what installed, deferred, or failed.

# ruff path 1: PyPI via uv. Fast-fails when PyPI is unreachable so we don't burn a
# long uv retry loop; UV_HTTP_TIMEOUT caps any attempt that slips past the probe.
method_ruff_uv() {
  have uv || { log_warn "ruff: uv missing"; return 1; }
  pypi_reachable || { log_warn "ruff: PyPI unreachable — skipping uv path (fast-fail)"; return 1; }
  run env UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-10}" uv tool install ruff || return 1
  export PATH="$HOME/.local/bin:$PATH"
  verify have ruff
}

# ruff path 2: prebuilt GitHub release binary (no PyPI, no Python install needed).
# Uses the same latest-tag resolver + release_install_bin as the other binaries.
method_ruff_github() {
  local target tag url
  case "$DETECT_ARCH" in
    x86_64)  target="x86_64-unknown-linux-gnu" ;;
    aarch64) target="aarch64-unknown-linux-gnu" ;;
    *) log_warn "ruff: unsupported arch $DETECT_ARCH for github release"; return 1 ;;
  esac
  tag="$(github_latest_tag astral-sh/ruff)" || return 1   # fall through on failure
  # ruff assets embed the tag dir but a bare target filename, e.g.
  # ruff-x86_64-unknown-linux-gnu.tar.gz (tag has no leading 'v').
  url="https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-${target}.tar.gz"
  log_info "ruff: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install ruff ${tag} (no fetch performed)"
    return 0
  fi
  release_install_bin ruff "$url" "ruff"
}

_install_lsps() {
  # ---- ruff: uv (PyPI) -> GitHub release binary -> defer/fail ----
  if have ruff; then
    record_outcome PRESENT ruff
  elif try_methods "ruff" method_ruff_uv method_ruff_github; then
    record_outcome INSTALLED ruff "$LAST_METHOD"
  elif ! pypi_reachable; then
    # PyPI was the closed path AND the github fallback also failed -> a rerun on an
    # open network can still fix it, so this is a defer, not a hard failure.
    record_outcome DEFERRED ruff "PyPI unreachable and GitHub release fallback failed; rerun on open network"
  else
    record_outcome FAILED ruff "uv and GitHub release paths both failed with PyPI reachable"
  fi

  # ---- basedpyright: pure-Python, PyPI-only (present-but-disabled in config) ----
  # Its only second path is TIME: defer when PyPI is closed, never venv/pip.
  if have basedpyright; then
    record_outcome PRESENT basedpyright
  elif ! have uv; then
    record_outcome FAILED basedpyright "uv missing (module 00 failed?)"
  elif ! pypi_reachable; then
    record_outcome DEFERRED basedpyright "PyPI unreachable (files.pythonhosted.org); rerun on open network"
  elif run env UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-10}" uv tool install basedpyright; then
    record_outcome INSTALLED basedpyright "uv tool"
  else
    record_outcome FAILED basedpyright "uv tool install failed while PyPI was reachable"
  fi

  # ---- vtsls: TypeScript LSP via npm. Missing Node is a known prerequisite a
  # rerun cannot fix (this installer does not install Node), so it is an
  # informational NOTE, not a network-recoverable DEFERRED. ----
  if have vtsls; then
    record_outcome PRESENT vtsls
  elif ! have npm; then
    record_outcome NOTE vtsls "npm/node not found — install Node to get vtsls for TypeScript projects (see README)"
  elif run npm install -g @vtsls/language-server; then
    record_outcome INSTALLED vtsls "npm -g"
  else
    record_outcome FAILED vtsls "npm install failed"
  fi

  export PATH="$HOME/.local/bin:$PATH"
}

# helix: prefer the latest-resolved release binary; apt (when packaged) then cargo as fallbacks.
try_methods "helix" method_helix_present method_helix_release method_helix_apt method_helix_cargo

_install_lsps

# ---- Config -----------------------------------------------------------------
link_dotfile "$REPO_ROOT/dotfiles/helix/config.toml"    "$HOME/.config/helix/config.toml"
link_dotfile "$REPO_ROOT/dotfiles/helix/languages.toml" "$HOME/.config/helix/languages.toml"

# Surface LSP attachment readiness (full check is in tests/validate.sh).
if _hx_present; then
  log_info "helix LSP languages configured: typescript(vtsls), python(ruff); basedpyright disabled by default"
fi

log_ok "helix module done"
