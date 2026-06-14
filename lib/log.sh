#!/usr/bin/env bash
# lib/log.sh — logging, dry-run guard, and the run() wrapper.
#
# Everything that changes machine state MUST go through run(). In --dry-run the
# command is printed and skipped; otherwise it executes and its output is teed to
# the timestamped log file. This is the single choke point that makes --dry-run
# honest and the log complete.
#
# Sourced by install.sh and every module. Guard against double-sourcing.
[[ -n "${_LIB_LOG_SOURCED:-}" ]] && return 0
_LIB_LOG_SOURCED=1

# ---- Configuration (overridable by the caller before first use) -------------
: "${DRY_RUN:=0}"
: "${VERBOSE:=0}"
: "${REPO_ROOT:?REPO_ROOT must be set before sourcing log.sh}"
: "${LOG_DIR:=$REPO_ROOT/logs}"

# Colors only when stdout is a terminal.
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_DIM=$'\033[2m'; _C_RED=$'\033[31m'
  _C_YELLOW=$'\033[33m'; _C_GREEN=$'\033[32m'; _C_BLUE=$'\033[34m'
else
  _C_RESET=''; _C_DIM=''; _C_RED=''; _C_YELLOW=''; _C_GREEN=''; _C_BLUE=''
fi

# LOG_FILE is set by log_init. Until then, messages still print to the console.
LOG_FILE="${LOG_FILE:-}"

# log_init — create the log directory and open a timestamped log file.
log_init() {
  mkdir -p "$LOG_DIR"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="$LOG_DIR/install-$stamp.log"
  : >"$LOG_FILE"
  log_info "Logging to $LOG_FILE"
  [[ "$DRY_RUN" == "1" ]] && log_info "DRY-RUN: no changes will be made."
}

# _emit <console-colored-line> <plain-line> — print to console and append plain to log.
_emit() {
  printf '%s\n' "$1"
  [[ -n "$LOG_FILE" ]] && printf '%s\n' "$2" >>"$LOG_FILE"
  return 0
}

_ts() { date +%H:%M:%S; }

log_info()  { _emit "${_C_BLUE}[INFO]${_C_RESET}  $*" "[$(_ts)] [INFO]  $*"; }
log_warn()  { _emit "${_C_YELLOW}[WARN]${_C_RESET}  $*" "[$(_ts)] [WARN]  $*" >&2; }
log_error() { _emit "${_C_RED}[ERROR]${_C_RESET} $*" "[$(_ts)] [ERROR] $*" >&2; }
log_ok()    { _emit "${_C_GREEN}[ OK ]${_C_RESET}  $*" "[$(_ts)] [ OK ]  $*"; }
log_step()  { _emit "${_C_DIM}>>${_C_RESET} $*" "[$(_ts)] >> $*"; }

# log_debug — only shown when --verbose.
log_debug() {
  [[ "$VERBOSE" == "1" ]] || { [[ -n "$LOG_FILE" ]] && printf '[%s] [DEBUG] %s\n' "$(_ts)" "$*" >>"$LOG_FILE"; return 0; }
  _emit "${_C_DIM}[DEBUG] $*${_C_RESET}" "[$(_ts)] [DEBUG] $*"
}

# run <cmd...> — the only sanctioned way to mutate state.
#   --dry-run: prints "[DRY] cmd" and returns 0.
#   otherwise: logs the command, executes it, tees output to the log, returns its
#   exit code. Never calls 'exit' itself, so callers/fallback engine stay in control.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    _emit "${_C_DIM}[DRY]${_C_RESET}  $*" "[$(_ts)] [DRY]  $*"
    return 0
  fi
  log_debug "exec: $*"
  if [[ -n "$LOG_FILE" ]]; then
    # Tee combined output to the log while preserving the command's exit status.
    "$@" > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE" >&2)
  else
    "$@"
  fi
}

# run_quiet <cmd...> — like run() but only the log captures output (console stays clean).
# Useful for chatty downloads. Honors --dry-run.
run_quiet() {
  if [[ "$DRY_RUN" == "1" ]]; then
    _emit "${_C_DIM}[DRY]${_C_RESET}  $*" "[$(_ts)] [DRY]  $*"
    return 0
  fi
  log_debug "exec(quiet): $*"
  if [[ -n "$LOG_FILE" ]]; then
    "$@" >>"$LOG_FILE" 2>&1
  else
    "$@" >/dev/null 2>&1
  fi
}
