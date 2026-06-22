#!/usr/bin/env bash
# modules/45-micro.sh — micro: the default editor (simple, modeless), plus EDITOR.
#
# micro is the stack's DEFAULT editor — the "GUI-like in a TUI" option (Ctrl+S save,
# Ctrl+C/V copy/paste, Ctrl+Q quit) for everyday edits; vim handles the heavy
# lifting. Installs the official latest-stable binary into ~/.local/bin (already on
# PATH; no sudo), with apt as a fallback; sets EDITOR/VISUAL=micro via a managed
# ~/.bashrc block; and links a tiny QoL config. VERIFY non-destructive; INSTALL
# idempotent; honors --dry-run and DEFERs honestly offline. Sourced by install.sh
# (inherits try_methods, github_latest_tag, release_install_bin, apt_install,
# link_dotfile, run, log_*, record_outcome, DRY_RUN, DETECT_ARCH, HOME).

RC="$HOME/.bashrc"
ENV_BEGIN="# >>> lnx-cli-tui-ide: shell env >>>"
ENV_END="# <<< lnx-cli-tui-ide: shell env <<<"

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

# EDITOR/VISUAL=micro via a managed ~/.bashrc block (idempotent; replaces any prior
# "shell env" block, e.g. a legacy EDITOR=hx). New shells pick it up.
_micro_editor_env() {
  local block extract
  block="$(printf '%s\nexport EDITOR=micro\nexport VISUAL=micro\n%s\n' "$ENV_BEGIN" "$ENV_END")"
  if [[ -f "$RC" ]] && grep -qF "$ENV_BEGIN" "$RC" 2>/dev/null; then
    extract="$(awk -v b="$ENV_BEGIN" -v e="$ENV_END" '$0==b{i=1} i{print} $0==e&&i{exit}' "$RC")"
    if [[ "$extract" == "$block" ]]; then
      log_info "micro: EDITOR/VISUAL=micro block already current in $RC"
      return 0
    fi
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] micro: would set EDITOR/VISUAL=micro in a managed block in $RC"
    return 0
  fi
  local stripped newrc
  if [[ -f "$RC" ]]; then
    run cp -- "$RC" "$RC.bak.$(date +%Y%m%d-%H%M%S)"
    stripped="$(awk -v b="$ENV_BEGIN" -v e="$ENV_END" '$0==b{i=1;next} i{if($0==e)i=0;next} {print}' "$RC")"
  else
    run mkdir -p "$(dirname "$RC")"; stripped=""
  fi
  newrc="$(mktemp)"
  { [[ -n "$stripped" ]] && printf '%s\n\n' "$stripped"; printf '%s\n' "$block"; } >"$newrc"
  cat "$newrc" >"$RC"; rm -f "$newrc"
  log_ok "micro: EDITOR/VISUAL=micro set in $RC (new shells; 'source $RC' for the current one)"
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
_micro_editor_env

log_ok "micro module done"
