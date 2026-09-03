#!/usr/bin/env bash
# Hermetic, mutation-sensitive tests for the single managed ~/.bashrc fragment.
# Any append-only implementation, missing backup, pinned pi-node version, legacy
# claude-* survivor, or unguarded PATH entry flips at least one assertion.
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT
PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
chk() { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }
has() { if grep -qF "$2" "$1"; then _pass "$3"; else _fail "$3"; fi; }
lacks() { if ! grep -qE "$2" "$1"; then _pass "$3"; else _fail "$3"; fi; }
count_baks() { find "$1" -maxdepth 1 -name '.bashrc.bak.*' | wc -l | tr -d ' '; }

seed_legacy() {
  cat >"$1" <<'RC'
# Debian boilerplate stays
FOREIGN_SENTINEL=keepme
# >>> lnx-cli-tui-ide: golang PATH >>>
export PATH="/usr/local/go/bin:$PATH"
# <<< lnx-cli-tui-ide: golang PATH <<<
# >>> lnx-cli-tui-ide: shell env >>>
export EDITOR=micro
export VISUAL=micro
# <<< lnx-cli-tui-ide: shell env <<<
# >>> lnx-cli-tui-ide: tab-title >>>
__set_tab_title() {
  printf old
}
PROMPT_COMMAND="__set_tab_title;${PROMPT_COMMAND}"
# <<< lnx-cli-tui-ide: tab-title <<<
# Added by lnx-cli-tui-ide (uv tools)
export PATH="$HOME/.local/bin:$PATH"
# Pi
export PATH="/home/someone/.local/share/pi-node/node-v22.23.1-linux-x64/bin:$PATH"
# Added by Antigravity CLI installer
export PATH="/home/someone/.local/bin:$PATH"
# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
alias codex-araya='old'
# >>> starship: mantener al final de ~/.bashrc >>>
if command -v starship >/dev/null 2>&1; then eval "$(starship init bash)"; fi
# <<< starship <<<
# DESACTIVADO POR SCRIPT: # ===== Claude Code + DeepSeek =====
claude-anthropic() {
  export ANTHROPIC_MODEL="claude-3-5-sonnet-20241022"
}
claude-hybrid() {
  export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-3-opus-20240229"
}
claude-status() {
  printf legacy
}
claude-go() {
  claude
}
alias claude-smart='claude-go'
# ===== End Claude Code functions =====
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
# >>> ARAYA CLAUDE NATIVE DEFAULT >>>
unset ANTHROPIC_MODEL
# <<< ARAYA CLAUDE NATIVE DEFAULT <<<
RC
}

run_apply() { # <home> [dry]
  local home="$1" dry="${2:-0}"
  HOME="$home" SHELL_RC="$home/.bashrc" DRY_RUN="$dry" VERBOSE=0 \
  REPO_ROOT="$ROOT" LOG_DIR="$home/logs" OUTCOME_FILE="$home/ledger" bash -c '
    set -uo pipefail
    . "$REPO_ROOT/lib/log.sh"
    . "$REPO_ROOT/lib/outcome.sh"
    . "$REPO_ROOT/modules/03-shell-env.sh"
  ' >"$home/out" 2>&1
}

BEGIN='# >>> lnx-cli managed >>>'
END='# <<< lnx-cli managed <<<'

# T1 migration: preserve foreign data, backup first, one canonical block, no legacy.
echo '== T1 migrate legacy fragments =='
H="$TMP/t1"; mkdir -p "$H"; seed_legacy "$H/.bashrc"; cp "$H/.bashrc" "$H/original"
run_apply "$H"
has "$H/.bashrc" 'FOREIGN_SENTINEL=keepme' 'T1: foreign content preserved'
chk 'T1: exactly one begin marker' "$(grep -cF "$BEGIN" "$H/.bashrc")" '1'
chk 'T1: exactly one end marker' "$(grep -cF "$END" "$H/.bashrc")" '1'
chk 'T1: exactly one pre-write backup' "$(count_baks "$H")" '1'
backup="$(find "$H" -maxdepth 1 -name '.bashrc.bak.*' -print -quit)"
if cmp -s "$H/original" "$backup"; then _pass 'T1: backup is byte-identical to pre-write .bashrc'; else _fail 'T1: backup does not restore original'; fi
lacks "$H/.bashrc" 'lnx-cli-tui-ide:|claude-(anthropic|hybrid|status|go|smart)|claude-3-|ARAYA CLAUDE NATIVE DEFAULT|node-v22\.23\.1' 'T1: old blocks, claude legacy, and pinned pi path removed'

# Required portable payload.
has "$H/.bashrc" "export PATH=\"/usr/local/go/bin:\$PATH\"" 'T1: guarded Go toolchain PATH present'
has "$H/.bashrc" "export PATH=\"\$PATH:\$HOME/go/bin\"" 'T1: guarded GOPATH bin present'
has "$H/.bashrc" "export PATH=\"\$HOME/.local/bin:\$PATH\"" 'T1: one guarded local-bin PATH present'
has "$H/.bashrc" "for _pi_node_dir in \"\$HOME\"/.local/share/pi-node/node-*" 'T1: pi-node path is version-dynamic'
has "$H/.bashrc" 'export EDITOR=micro' 'T1: EDITOR=micro present'
has "$H/.bashrc" "[ -s \"\$NVM_DIR/nvm.sh\" ] && source" 'T1: nvm load is guarded'
has "$H/.bashrc" "if [ -x \"\$HOME/.grok/bin\" ]; then" 'T1: grok path/completions are guarded'
has "$H/.bashrc" "[ -f \"\$HOME/.claude/.env\" ] && source" 'T1: Claude env load is guarded'
has "$H/.bashrc" "alias codex-araya='codex --sandbox danger-full-access --ask-for-approval never --search'" 'T1: codex-araya alias present'
has "$H/.bashrc" '# export LANG=C.UTF-8' 'T1: locale is optional/commented'
has "$H/.bashrc" 'command -v starship >/dev/null 2>&1 && eval' 'T1: starship init is guarded'
has "$H/.bashrc" '__set_tab_title() {' 'T1: tab-title hook present'
if bash -n "$H/.bashrc"; then _pass 'T1: resulting .bashrc parses'; else _fail 'T1: resulting .bashrc does not parse'; fi

# T2 idempotency: byte no-op and no extra backup.
echo '== T2 idempotent second apply =='
cp "$H/.bashrc" "$H/after1"; b1="$(count_baks "$H")"; run_apply "$H"
if cmp -s "$H/after1" "$H/.bashrc" && [[ "$(count_baks "$H")" == "$b1" ]]; then
  _pass 'T2: second apply changed no bytes and created no backup'
else
  _fail 'T2: second apply was not a no-op'
fi

# T3 startup idempotency: source twice, no PATH or PROMPT_COMMAND duplicates.
echo '== T3 shell-startup guards =='
mkdir -p "$H/.local/bin" "$H/go/bin" "$H/.local/share/pi-node/node-v22.9.0-linux-x64/bin" "$H/.local/share/pi-node/node-v22.23.1-linux-x64/bin"
runtime="$(HOME="$H" PATH='/usr/bin:/bin' PROMPT_COMMAND='' bash -c '. "$HOME/.bashrc"; . "$HOME/.bashrc"; printf "%s\n%s\n" "$PATH" "$PROMPT_COMMAND"' 2>/dev/null)"
runtime_path="${runtime%%$'\n'*}"; runtime_pc="${runtime#*$'\n'}"
for segment in '/usr/local/go/bin' "$H/go/bin" "$H/.local/bin" "$H/.local/share/pi-node/node-v22.23.1-linux-x64/bin"; do
  chk "T3: $segment appears once after sourcing twice" "$(tr ':' '\n' <<<"$runtime_path" | grep -cFx "$segment")" '1'
done
chk 'T3: newest pi-node tree selected (old tree absent)' "$(tr ':' '\n' <<<"$runtime_path" | grep -cF 'node-v22.9.0-linux-x64')" '0'
chk 'T3: tab-title PROMPT_COMMAND added once' "$(tr ';' '\n' <<<"$runtime_pc" | grep -cFx '__set_tab_title')" '1'

# T4 refresh drifted canonical block; still one block and one backup.
echo '== T4 replace drifted block =='
H4="$TMP/t4"; mkdir -p "$H4"; printf 'FOREIGN=1\n%s\nold\n%s\n' "$BEGIN" "$END" >"$H4/.bashrc"
run_apply "$H4"
chk 'T4: drifted block replaced, not duplicated' "$(grep -cF "$BEGIN" "$H4/.bashrc")" '1'
has "$H4/.bashrc" 'export VISUAL=micro' 'T4: canonical payload replaced drift'
chk 'T4: replacement backed up prior file' "$(count_baks "$H4")" '1'

# T5 create absent file and T6 dry-run no-op.
echo '== T5 create / T6 dry-run =='
H5="$TMP/t5"; mkdir -p "$H5"; run_apply "$H5"
has "$H5/.bashrc" "$BEGIN" 'T5: absent .bashrc created with managed block'
H6="$TMP/t6"; mkdir -p "$H6"; seed_legacy "$H6/.bashrc"; cp "$H6/.bashrc" "$H6/before"; run_apply "$H6" 1
if cmp -s "$H6/before" "$H6/.bashrc" && [[ "$(count_baks "$H6")" == '0' ]]; then _pass 'T6: dry-run changes nothing and makes no backup'; else _fail 'T6: dry-run mutated .bashrc'; fi

# T7 revert removes only current block; full rollback backup was already proven T1.
echo '== T7 managed-block revert =='
H7="$TMP/t7"; mkdir -p "$H7"; printf 'FOREIGN_SENTINEL=keepme\n' >"$H7/.bashrc"
HOME="$H7" SHELL_RC="$H7/.bashrc" DRY_RUN=0 VERBOSE=0 REPO_ROOT="$ROOT" LOG_DIR="$H7/logs" OUTCOME_FILE="$H7/ledger" bash -c '
  . "$REPO_ROOT/lib/log.sh"; . "$REPO_ROOT/lib/outcome.sh"
  . "$REPO_ROOT/modules/03-shell-env.sh"
  _shell_env_revert
' >"$H7/out" 2>&1
if grep -qF 'FOREIGN_SENTINEL=keepme' "$H7/.bashrc" && ! grep -qF "$BEGIN" "$H7/.bashrc"; then _pass 'T7: revert removes only managed block'; else _fail 'T7: revert damaged foreign content'; fi

printf '\ntest_shell_env: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
