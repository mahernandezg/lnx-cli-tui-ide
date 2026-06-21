#!/usr/bin/env bash
# modules/95-mahg-help.sh — install the `mahg-help` environment cheatsheet on PATH.
#
# Symlinks the vendored bin/mahg-help to ~/.local/bin/mahg-help (already on PATH via
# the repo's ~/.bashrc block). Idempotent, backs up any existing file, --dry-run safe.

_src="$REPO_ROOT/bin/mahg-help"
_dest="$HOME/.local/bin/mahg-help"

if [[ -L "$_dest" && "$(readlink -f "$_dest" 2>/dev/null)" == "$(readlink -f "$_src" 2>/dev/null)" ]]; then
  record_outcome PRESENT mahg-help "already linked at ~/.local/bin/mahg-help"
elif link_dotfile "$_src" "$_dest"; then
  record_outcome INSTALLED mahg-help "symlinked to ~/.local/bin/mahg-help"
else
  record_outcome FAILED mahg-help "could not link ~/.local/bin/mahg-help"
fi

log_ok "mahg-help module done (run: mahg-help)"
