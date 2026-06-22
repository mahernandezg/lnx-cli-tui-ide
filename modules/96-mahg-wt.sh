#!/usr/bin/env bash
# modules/96-mahg-wt.sh — install the `mahg-wt-apply` helper (WSL only).
#
# mahg-wt-apply applies the mahg-dark scheme to Windows Terminal from inside WSL. It
# is only useful there, so this module symlinks it onto PATH ONLY under WSL; on a
# native (non-WSL) machine it records a NOTE and does nothing. Idempotent.

_is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; }

if ! _is_wsl; then
  record_outcome NOTE mahg-wt-apply "WSL-only helper; not on WSL — skipped (run bin/mahg-wt-apply by hand if ever needed)"
else
  _src="$REPO_ROOT/bin/mahg-wt-apply"
  _dest="$HOME/.local/bin/mahg-wt-apply"
  if [[ -L "$_dest" && "$(readlink -f "$_dest" 2>/dev/null)" == "$(readlink -f "$_src" 2>/dev/null)" ]]; then
    record_outcome PRESENT mahg-wt-apply "already linked at ~/.local/bin/mahg-wt-apply"
  elif link_dotfile "$_src" "$_dest"; then
    record_outcome INSTALLED mahg-wt-apply "symlinked to ~/.local/bin/mahg-wt-apply (WSL)"
  else
    record_outcome FAILED mahg-wt-apply "could not link ~/.local/bin/mahg-wt-apply"
  fi
fi

log_ok "mahg-wt module done"
