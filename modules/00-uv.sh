#!/usr/bin/env bash
# modules/00-uv.sh — install uv first; everything Python depends on it.
# No venv / python -m venv ever: uv is the only Python toolchain manager.
#
# Methods (in order):
#   1. already present  -> skip
#   2. official astral installer (curl | sh) when online
#   3. apt (Debian trixie+ ships a 'uv' package; older releases won't have it)
#   4. pip-free fallback: pipx is intentionally NOT used; if all else fails we
#      log and let the engine report failure (no venv fallback by design).
#
# Sourced by install.sh; inherits run(), log_*, have(), apt_*, try_methods.

_uv_present() { have uv; }

method_uv_present() {
  _uv_present || return 1
  log_info "uv already installed: $(uv --version 2>/dev/null || echo present)"
}

method_uv_official() {
  require_network "uv" || return 1
  have curl || { log_warn "uv: curl missing for official installer"; return 1; }
  # Astral's installer drops uv into ~/.local/bin by default.
  run_quiet bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' || return 1
  # Make it visible to the rest of this run.
  export PATH="$HOME/.local/bin:$PATH"
  verify _uv_present
}

method_uv_apt() {
  apt_can_use || return 1
  # Only worthwhile where the package exists; apt_install fails cleanly otherwise.
  apt_install uv || return 1
  verify _uv_present
}

# Ensure ~/.local/bin is on PATH in future shells (idempotent append).
_uv_ensure_path_persisted() {
  # Single quotes are intentional: we write the literal $HOME expansion into
  # .bashrc so it resolves at shell-startup time, not now.
  # shellcheck disable=SC2016
  local line='export PATH="$HOME/.local/bin:$PATH"'
  local rc="$HOME/.bashrc"
  # Create ~/.bashrc if absent: a fresh Termux/Android home often ships none, and
  # without this line ~/.local/bin (uv tools, the AI agents) is never on PATH.
  if [[ ! -f "$rc" && "$DRY_RUN" != "1" ]]; then
    run mkdir -p "$(dirname "$rc")"
    : >"$rc"
  fi
  if [[ -f "$rc" ]] && grep -qF "$line" "$rc" 2>/dev/null; then
    log_debug "uv: PATH already persisted in $rc"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would append ~/.local/bin to PATH in $rc"
  else
    printf '\n# Added by lnx-cli-tui-ide (uv tools)\n%s\n' "$line" >>"$rc"
    log_ok "uv: ensured ~/.local/bin on PATH in $rc"
  fi
}

try_methods "uv" \
  method_uv_present \
  method_uv_official \
  method_uv_apt

if _uv_present; then
  _uv_ensure_path_persisted
else
  log_error "uv: not installed — Python-based modules (euporie) will be skipped"
fi
