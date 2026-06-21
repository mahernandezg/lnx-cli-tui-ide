#!/usr/bin/env bash
# dotfiles/claude-code/statusline.sh — mahg-branded Claude Code status line.
#
# Claude Code pipes a JSON status object on stdin and renders this script's stdout
# as the status line INSIDE its UI. We print one compact, branded line that
# identifies the SESSION — repo · directory · optional session name — so the
# Professor can tell concurrent Claude Code sessions apart. This is the robust
# place for that identity because the terminal TAB TITLE is owned by Claude Code
# and is NOT configurable today (see README §13; upstream issues #21677/#18326/
# #55197). Pair with `/rename <name>` to label a session.
#
# Input fields used (verified against the Claude Code statusline schema):
#   .workspace.repo.name   (absent outside a git repo / no origin remote)
#   .workspace.current_dir
#   .session_name          (absent unless set via --name or /rename)
# Parsed with jq when present, else python3; missing fields degrade gracefully.
# Brand colours via truecolor ANSI (mahg palette): blue #4c86ff, amber #ffbf47,
# text #edf2ff. Foreground only (no background) so it sits on any statusline bg.
set -uo pipefail

# mahg palette as truecolor SGR escapes.
BLUE=$'\033[38;2;76;134;255m'    # #4c86ff
AMBER=$'\033[38;2;255;191;71m'   # #ffbf47
TEXT=$'\033[38;2;237;242;255m'   # #edf2ff
DIM=$'\033[2m'
RST=$'\033[0m'

input="$(cat)"

# Extract the 3 fields in ONE pass, separated by US (\x1f, a NON-whitespace byte)
# so empty fields survive `read` (a whitespace IFS like TAB would collapse a
# leading empty repo into the dir). `// ""` / `or ""` keep absent keys safe.
_parse() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -j \
      '[.workspace.repo.name // "", .workspace.current_dir // "", .session_name // ""] | join("")' \
      2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.stdout.write("\x1f\x1f"); sys.exit(0)
w = d.get("workspace") or {}
repo = (w.get("repo") or {}).get("name") or ""
sys.stdout.write("\x1f".join([repo, w.get("current_dir") or "", d.get("session_name") or ""]))
' 2>/dev/null && return 0
  fi
  printf '\037\037'   # no jq/python3 -> empty fields, line still renders
}

repo=""; dir=""; sess=""
IFS=$'\037' read -r repo dir sess < <(_parse)

# Abbreviate $HOME -> ~ in the directory for a compact path.
if [ -n "$dir" ]; then
  case "$dir" in
    "$HOME") dir="~" ;;
    "$HOME"/*) dir="~${dir#"$HOME"}" ;;
  esac
fi

# Compose: amber [ repo ] · blue dir · dim session. Each part only if present.
out=""
[ -n "$repo" ] && out="${AMBER}[ ${repo} ]${RST}"
[ -n "$dir" ]  && out="${out:+${out} }${BLUE}${dir}${RST}"
[ -n "$sess" ] && out="${out:+${out}  }${DIM}${TEXT}${sess}${RST}"
[ -z "$out" ] && out="${DIM}claude${RST}"   # nothing parsed -> still a stable line

printf '%s\n' "$out"
