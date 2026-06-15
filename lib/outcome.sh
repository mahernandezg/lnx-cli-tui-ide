#!/usr/bin/env bash
# lib/outcome.sh — a per-tool outcome ledger so the final summary tells the truth.
#
# Modules run in isolated subshells (see install.sh dispatch), so a module cannot
# set a variable that install.sh reads back. Instead each module appends one line
# per tool to a shared ledger file; install.sh reads it at the end and prints an
# honest summary. The ledger path is exported, so subshell modules inherit it.
#
# Exactly one status per tool:
#   INSTALLED  — newly installed this run.
#   PRESENT    — already present; nothing to do.
#   DEFERRED   — a network/PyPI path was closed. NOT installed, NOT a failure;
#                a later `./install.sh` on an open network completes it (the
#                installer is idempotent). This is the only "rerun fixes it" state.
#   NOTE       — an informational prerequisite a rerun will NOT fix (e.g. a tool
#                that needs Node, which this installer does not install). Surfaced
#                in the summary but never affects the exit code.
#   FAILED     — all available paths exhausted with no network excuse. A real
#                failure.
[[ -n "${_LIB_OUTCOME_SOURCED:-}" ]] && return 0
_LIB_OUTCOME_SOURCED=1

# outcome_init — choose the ledger path (shared with subshell modules via the
# exported OUTCOME_FILE) and truncate it. Call once from install.sh after log_init.
# OUTCOME_FILE may be pre-set by the caller (the test harness does this).
outcome_init() {
  : "${LOG_DIR:=${REPO_ROOT:-.}/logs}"
  : "${OUTCOME_FILE:=$LOG_DIR/outcomes-$(date +%Y%m%d-%H%M%S).$$.tsv}"
  export OUTCOME_FILE
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  : >"$OUTCOME_FILE" 2>/dev/null || true
}

# record_outcome <status> <tool> [detail]
#   Append one tab-separated ledger line and emit a matching log line. No-ops the
#   file write (but still logs) when no ledger is configured, so a module run
#   standalone never errors. ALWAYS returns 0 — it must never abort a caller that
#   is running under `set -e`.
record_outcome() {
  local status="$1" tool="$2" detail="${3:-}"
  case "$status" in
    INSTALLED) log_ok    "$tool: installed${detail:+ (via $detail)}" ;;
    PRESENT)   log_info  "$tool: already present${detail:+ ($detail)}" ;;
    DEFERRED)  log_warn  "$tool: DEFERRED — ${detail:-path closed; rerun on open network}" ;;
    NOTE)      log_info  "$tool: ${detail:-prerequisite missing}" ;;
    FAILED)    log_error "$tool: FAILED — ${detail:-all install paths exhausted}" ;;
    *)         log_warn  "outcome: unknown status '$status' for $tool" ;;
  esac
  if [[ -n "${OUTCOME_FILE:-}" ]]; then
    printf '%s\t%s\t%s\n' "$status" "$tool" "$detail" >>"$OUTCOME_FILE" 2>/dev/null || true
  fi
  return 0
}
