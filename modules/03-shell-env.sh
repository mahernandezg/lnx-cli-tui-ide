#!/usr/bin/env bash
# modules/03-shell-env.sh — one portable, managed ~/.bashrc fragment.
#
# The Professor's .bashrc keeps Debian boilerplate and personal content. This
# module owns only `# >>> lnx-cli managed >>>` ... `# <<< lnx-cli managed <<<`.
# It also migrates blocks written by older repo versions and the explicitly
# retired claude-* routing helpers. Existing files are backed up before writes;
# a byte-identical second run is a no-op with no second backup.

SHELL_RC="${SHELL_RC:-$HOME/.bashrc}"
SHELL_BEGIN="# >>> lnx-cli managed >>>"
SHELL_LAST_BACKUP=""

_shell_env_block() {
  cat <<'BLOCK'
# >>> lnx-cli managed >>>
# Managed by lnx-cli-tui-ide. Portable shell environment; safe to source twice.
case ":$PATH:" in
  *":/usr/local/go/bin:"*) ;;
  *) export PATH="/usr/local/go/bin:$PATH" ;;
esac
case ":$PATH:" in
  *":$HOME/go/bin:"*) ;;
  *) export PATH="$PATH:$HOME/go/bin" ;;
esac
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# pi.dev ships its own Node tree. Select the newest installed tree at shell
# startup instead of pinning a node-vNN.NN.N-linux-ARCH directory.
_pi_node_bin="$(
  for _pi_node_dir in "$HOME"/.local/share/pi-node/node-*; do
    [ -d "$_pi_node_dir/bin" ] && printf '%s\n' "$_pi_node_dir/bin"
  done | sort -V | tail -n 1
)"
if [ -n "$_pi_node_bin" ]; then
  case ":$PATH:" in
    *":$_pi_node_bin:"*) ;;
    *) export PATH="$_pi_node_bin:$PATH" ;;
  esac
fi
unset _pi_node_bin _pi_node_dir

export EDITOR=micro
export VISUAL=micro

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

if [ -x "$HOME/.grok/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.grok/bin:"*) ;;
    *) export PATH="$HOME/.grok/bin:$PATH" ;;
  esac
  [ -r "$HOME/.grok/completions/bash/grok.bash" ] && source "$HOME/.grok/completions/bash/grok.bash"
fi

[ -f "$HOME/.claude/.env" ] && source "$HOME/.claude/.env"
alias codex-araya='codex --sandbox danger-full-access --ask-for-approval never --search'

# Optional locale override — uncomment only when C.UTF-8 is desired here.
# export LANG=C.UTF-8
# export LC_ALL=C.UTF-8

# Starship must initialize before the tab-title hook extends PROMPT_COMMAND.
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
__set_tab_title() {
  if [ "$PWD" = "$HOME" ]; then
    printf '\033]0;~\a'
  else
    printf '\033]0;%s\a' "${PWD##*/}"
  fi
}
case ";${PROMPT_COMMAND:-};" in
  *";__set_tab_title;"*) ;;
  *) PROMPT_COMMAND="__set_tab_title${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac
# <<< lnx-cli managed <<<
BLOCK
}

# Remove only repo-owned historical fragments and the legacy explicitly retired
# by task 1000. Foreign Debian/personal content passes through byte-for-byte.
_shell_env_strip() {
  awk '
    function starts_block(line) {
      return line == "# >>> lnx-cli managed >>>" ||
             line ~ /^# >>> lnx-cli-tui-ide: .* >>>$/ ||
             line == "# >>> grok installer >>>" ||
             line == "# >>> starship: mantener al final de ~\/.bashrc >>>" ||
             line == "# >>> ARAYA CLAUDE NATIVE DEFAULT >>>" ||
             line == "# DESACTIVADO POR SCRIPT: # ===== Claude Code + DeepSeek ====="
    }
    function ends_block(line) {
      return line == "# <<< lnx-cli managed <<<" ||
             line ~ /^# <<< lnx-cli-tui-ide: .* <<<$/ ||
             line == "# <<< grok installer <<<" ||
             line == "# <<< starship <<<" ||
             line == "# <<< ARAYA CLAUDE NATIVE DEFAULT <<<" ||
             line == "# ===== End Claude Code functions ====="
    }
    starts_block($0) { inblock=1; next }
    inblock { if (ends_block($0)) inblock=0; next }

    /^(claude-anthropic|claude-hybrid|claude-status|claude-go|__set_tab_title)\(\)[[:space:]]*\{/ { infn=1; next }
    infn { if ($0 == "}") infn=0; next }

    /^# Added by lnx-cli-tui-ide \(uv tools\)$/ { next }
    /^# Added by Antigravity CLI installer$/ { next }
    /^# Pi$/ { next }
    /^export PATH="\$HOME\/\.local\/bin:\$PATH"$/ { next }
    /^export PATH="\/home\/[^/]+\/\.local\/bin:\$PATH"$/ { next }
    /^export PATH="\/home\/[^/]+\/\.local\/share\/pi-node\/node-[^"]+\/bin:\$PATH"$/ { next }
    /^export NVM_DIR=/ { next }
    /^\[ -s "\$NVM_DIR\/(nvm\.sh|bash_completion)" \] &&/ { next }
    /^alias codex-araya=/ { next }
    /^alias claude-smart=/ { next }
    /^PROMPT_COMMAND=.*__set_tab_title/ { next }
    /^command -v starship .*starship init bash/ { next }
    /^export (EDITOR|VISUAL)=micro$/ { next }
    /^export (LANG|LC_ALL)=C\.UTF-8$/ { next }
    { print }
  ' "$1" 2>/dev/null
}

_shell_env_render() {
  local rc="$1" stripped=""
  [[ -f "$rc" ]] && stripped="$(_shell_env_strip "$rc")"
  if [[ -n "$stripped" ]]; then
    printf '%s\n\n' "$stripped"
  fi
  _shell_env_block
}

_shell_env_backup() {
  local rc="$1" stamp backup n=0
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup="$rc.bak.$stamp"
  while [[ -e "$backup" ]]; do
    n=$((n + 1)); backup="$rc.bak.$stamp.$n"
  done
  run cp -- "$rc" "$backup" || return 1
  SHELL_LAST_BACKUP="$backup"
  log_info "shell-env: backed up $rc -> $backup"
}

_shell_env_apply() {
  local rc="$SHELL_RC" rendered
  rendered="$(mktemp)"
  _shell_env_render "$rc" >"$rendered"

  if [[ -f "$rc" ]] && cmp -s "$rendered" "$rc"; then
    rm -f "$rendered"
    record_outcome PRESENT shell-env "managed block already current in $rc"
    return 0
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] shell-env: would back up and update the managed block in $rc"
    _shell_env_block | sed 's/^/[DRY]   /'
    rm -f "$rendered"
    return 0
  fi

  if [[ -f "$rc" ]]; then
    _shell_env_backup "$rc" || { rm -f "$rendered"; record_outcome FAILED shell-env "could not back up $rc"; return 0; }
  else
    run mkdir -p "$(dirname "$rc")" || { rm -f "$rendered"; record_outcome FAILED shell-env "could not create parent directory"; return 0; }
    run touch "$rc" || { rm -f "$rendered"; record_outcome FAILED shell-env "could not create $rc"; return 0; }
  fi

  if run bash -c 'cat -- "$1" >"$2"' _ "$rendered" "$rc"; then
    record_outcome INSTALLED shell-env "managed block updated in $rc${SHELL_LAST_BACKUP:+; rollback backup: $SHELL_LAST_BACKUP}"
  else
    record_outcome FAILED shell-env "write failed; restore ${SHELL_LAST_BACKUP:-the prior backup}"
  fi
  rm -f "$rendered"
}

# Remove only the current managed block. A full pre-migration rollback uses the
# timestamped backup path logged by _shell_env_apply.
# shellcheck disable=SC2329 # exercised by tests/test_shell_env.sh
_shell_env_revert() {
  local rc="$SHELL_RC" rendered
  [[ -f "$rc" ]] || return 0
  grep -qF "$SHELL_BEGIN" "$rc" 2>/dev/null || return 0
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] shell-env: would back up $rc and remove its managed block"
    return 0
  fi
  _shell_env_backup "$rc" || return 1
  rendered="$(mktemp)"
  _shell_env_strip "$rc" >"$rendered"
  run bash -c 'cat -- "$1" >"$2"' _ "$rendered" "$rc"
  rm -f "$rendered"
}

_shell_env_apply
log_ok "shell-env module done (single managed ~/.bashrc fragment)"
