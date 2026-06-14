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
# vtsls (TypeScript) via npm if available; ruff & basedpyright via uv tool.
_install_lsps() {
  # ruff: fast Python linter/formatter + LSP. Isolated uv tool install.
  if have uv; then
    have ruff || run uv tool install ruff || log_warn "lsp: ruff install failed"
    # basedpyright present-but-disabled: install the binary, keep it off in config.
    have basedpyright || run uv tool install basedpyright || log_warn "lsp: basedpyright install failed"
  else
    log_warn "lsp: uv missing; skipping ruff/basedpyright"
  fi

  # vtsls: TypeScript language server. Prefer npm global; warn if no node.
  if have vtsls; then
    log_info "lsp: vtsls already present"
  elif have npm; then
    run npm install -g @vtsls/language-server || log_warn "lsp: vtsls npm install failed"
  else
    log_warn "lsp: npm/node not found — install Node to get vtsls for TypeScript projects (see README)"
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
