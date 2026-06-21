#!/usr/bin/env bash
# modules/05-ai-agents.sh — protect the Professor's AI coding agents.
#
# WHY: an agent (pi.dev) once vanished with no way to detect or restore it, because
# the agents were installed by hand, outside the repo. This module makes the repo
# the guardian: every run it VERIFIES each agent (non-destructive), RESTORES a
# missing one from its official installer (idempotent, --dry-run aware), and points
# at docs/ai-agents.md for where each one's data/login lives. It runs EARLY (05) so
# the agents are checked before anything else.
#
# Binary names are the REAL ones, NOT old aliases: pi, codex, claude, agy (NOT
# "antigravity"), grok, copilot. Google's Gemini CLI was discontinued (2026-06-18)
# and replaced by Antigravity (agy), so it is intentionally absent here.
#
# PROTECTED ZONE (for the lnx-gui-ide debloat, tracked separately): these six agent
# binaries plus /usr/local/bin and ~/.local/bin must NEVER be removed by any
# debloat. This module only verifies/installs/documents; wiring the debloat
# allowlist is a separate GUI task.

# Parallel arrays (NOT a delimited string — the installer commands contain '|' pipes).
# Index i across the three arrays describes one agent: real binary name, official
# installer command (empty = no auto-restore -> DEFER), and data/login location.
# Installers: pi & agy were verified live; claude & codex use their documented official
# methods; grok & copilot have no wired installer yet — they DEFER with a note rather
# than guess (never invent an installer).
_AI_BIN=(pi codex claude agy grok copilot)
_AI_INSTALL=(
  "curl -fsSL https://pi.dev/install.sh | sh"
  "npm install -g @openai/codex"
  "curl -fsSL https://claude.ai/install.sh | bash"
  "curl -fsSL https://antigravity.google/cli/install.sh | bash"
  ""
  ""
)
# shellcheck disable=SC2088  # these are human-readable location labels; the '~' is shown verbatim, never expanded.
_AI_DATA=(
  "~/.pi/ (config + history); alt installer: npm i -g @mariozechner/pi-coding-agent"
  "~/.codex/ (config + auth)"
  "~/.local/share/claude + ~/.claude/ (config, sessions)"
  "system keyring + ~/.gemini/antigravity-cli/"
  "~/.grok/ (binary ~/.grok/bin/grok, login under ~/.grok/) — wire the official xAI installer when known"
  "GitHub Copilot CLI; data under ~/.config — wire the official installer when known"
)

# Best-effort version string: non-interactive, never hangs (EOF on stdin + timeout).
_agent_version() {
  local bin="$1" v
  v="$(timeout 6 "$bin" --version </dev/null 2>/dev/null | head -1 || true)"
  [[ -z "$v" ]] && v="present (version n/a)"
  printf '%s' "$v"
}

_verify_or_restore_agent() {
  local bin="$1" installer="$2" data="$3"
  if have "$bin"; then
    record_outcome PRESENT "$bin" "$(_agent_version "$bin") · data: $data"
    return 0
  fi
  # Missing — exactly the failure mode this module exists to catch.
  log_warn "ai-agents: '$bin' is MISSING — see docs/ai-agents.md to restore"
  if [[ -z "$installer" ]]; then
    record_outcome DEFERRED "$bin" "missing; no auto-installer wired — restore from the official source (docs/ai-agents.md), then re-run"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] would restore $bin via: $installer"
    record_outcome NOTE "$bin" "dry-run; would restore via: $installer"
    return 0
  fi
  if ! require_network "$bin"; then
    record_outcome DEFERRED "$bin" "missing + offline; rerun on an open network to restore via: $installer"
    return 0
  fi
  log_warn "ai-agents: restoring '$bin' via its official installer: $installer"
  if run bash -c "$installer"; then
    export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
    if have "$bin"; then
      record_outcome INSTALLED "$bin" "restored via official installer"
    else
      record_outcome DEFERRED "$bin" "installer ran but '$bin' not on PATH yet — open a new shell or finish a login/manual step"
    fi
  else
    record_outcome DEFERRED "$bin" "auto-restore failed; install manually from the official source (docs/ai-agents.md)"
  fi
}

# PATH guard — the agents live in /usr/local/bin and ~/.local/bin. Warn (never
# silently rewrite) if either is missing from PATH; ~/.bashrc already exports them.
_check_path_guard() {
  local d miss=0
  for d in "/usr/local/bin" "$HOME/.local/bin"; do
    case ":$PATH:" in
      *":$d:"*) : ;;
      *) log_warn "ai-agents: PATH is missing $d (AI agent binaries live there) — add it to ~/.bashrc"; miss=1 ;;
    esac
  done
  [[ "$miss" -eq 0 ]] && log_info "ai-agents: PATH includes /usr/local/bin and ~/.local/bin"
  return 0
}

# ---- Orchestrate ------------------------------------------------------------
log_step "AI agents — verify & protect (pi, codex, claude, agy, grok, copilot)"
_check_path_guard
for _i in "${!_AI_BIN[@]}"; do
  _verify_or_restore_agent "${_AI_BIN[$_i]}" "${_AI_INSTALL[$_i]}" "${_AI_DATA[$_i]}"
done
log_ok "ai-agents module done (verified ${#_AI_BIN[@]} agents)"
