#!/usr/bin/env bash
# install.sh — entrypoint for lnx-cli-tui-ide.
#
# Bootstraps a terminal-centric dev environment on Debian with one command,
# adapting to each machine's hardware. Parses flags, sources lib/, runs
# detection, dispatches modules in order, and finishes with tests/validate.sh.
#
# Design contract:
#   - Idempotent: re-running skips what is already done.
#   - Non-fatal: a failing module/step logs and continues (handled by the
#     fallback engine and the dispatch loop below).
#   - --dry-run: prints what would happen, changes nothing.
#   - Everything mutating goes through run() in lib/log.sh.
set -euo pipefail

# ---- Locate the repo regardless of CWD --------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
REPO_ROOT="$SCRIPT_DIR"
export REPO_ROOT

# ---- Defaults / flags -------------------------------------------------------
DRY_RUN=0
VERBOSE=0
WITH_VSCODIUM=0
ONLY_MODULES=()
SKIP_MODULES=()
export DRY_RUN VERBOSE

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run            Print exactly what would happen; change nothing.
  --only <module>      Run only the given module (repeatable). Match by number
                       or name fragment, e.g. --only terminal --only 40-helix
  --skip <module>      Skip the given module (repeatable).
  --with-vscodium      Also install VSCodium (off by default; heavy Electron).
  --verbose            Verbose/debug logging.
  -h, --help           Show this help.

Modules (run in this order):
  00-uv  10-terminal  20-viewers  30-euporie  40-helix
  50-git-docker-tui  60-ssh-alias  70-starship  90-vscodium (gated)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)       DRY_RUN=1 ;;
    --verbose)       VERBOSE=1 ;;
    --with-vscodium) WITH_VSCODIUM=1 ;;
    --only)          shift; [[ $# -gt 0 ]] || { echo "--only needs an argument" >&2; exit 2; }; ONLY_MODULES+=("$1") ;;
    --skip)          shift; [[ $# -gt 0 ]] || { echo "--skip needs an argument" >&2; exit 2; }; SKIP_MODULES+=("$1") ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
export DRY_RUN VERBOSE WITH_VSCODIUM

# ---- Source libraries (order matters: log -> detect -> fallback -> ...) ------
# shellcheck source=lib/log.sh
. "$REPO_ROOT/lib/log.sh"
# shellcheck source=lib/detect.sh
. "$REPO_ROOT/lib/detect.sh"
# shellcheck source=lib/fallback.sh
. "$REPO_ROOT/lib/fallback.sh"
# shellcheck source=lib/symlink.sh
. "$REPO_ROOT/lib/symlink.sh"
# shellcheck source=lib/apt.sh
. "$REPO_ROOT/lib/apt.sh"
# shellcheck source=lib/github.sh
. "$REPO_ROOT/lib/github.sh"

log_init

# ---- Run detection ----------------------------------------------------------
run_detection

# ---- Module selection -------------------------------------------------------
# Discover modules by filename order.
mapfile -t ALL_MODULES < <(find "$REPO_ROOT/modules" -maxdepth 1 -name '[0-9]*.sh' -printf '%f\n' | sort)

# matches_any <name> <pattern...> — true if name contains any pattern fragment.
matches_any() {
  local name="$1"; shift
  local p
  for p in "$@"; do
    [[ "$name" == *"$p"* ]] && return 0
  done
  return 1
}

module_selected() {
  local name="$1"
  if [[ ${#ONLY_MODULES[@]} -gt 0 ]]; then
    matches_any "$name" "${ONLY_MODULES[@]}" || return 1
  fi
  if [[ ${#SKIP_MODULES[@]} -gt 0 ]]; then
    matches_any "$name" "${SKIP_MODULES[@]}" && return 1
  fi
  # 90-vscodium is gated unless --with-vscodium (or explicitly --only'd).
  if [[ "$name" == *"vscodium"* && "$WITH_VSCODIUM" != "1" ]]; then
    if [[ ${#ONLY_MODULES[@]} -eq 0 ]] || ! matches_any "$name" "${ONLY_MODULES[@]}"; then
      return 1
    fi
  fi
  return 0
}

# ---- Dispatch ---------------------------------------------------------------
FAILED_MODULES=()
RAN_MODULES=()

for mod in "${ALL_MODULES[@]}"; do
  if ! module_selected "$mod"; then
    log_debug "skip module: $mod"
    continue
  fi
  printf '\n'
  log_step "===== Module: $mod ====="
  RAN_MODULES+=("$mod")
  # Each module runs in a subshell so its failures (or set -e) never abort the
  # installer. Modules source nothing themselves; they inherit our environment.
  # shellcheck disable=SC1090  # module path is data-driven by design
  if ( set -euo pipefail; . "$REPO_ROOT/modules/$mod" ); then
    log_ok "module $mod complete"
  else
    log_error "module $mod reported failure (continuing)"
    FAILED_MODULES+=("$mod")
  fi
done

# ---- Final validation -------------------------------------------------------
printf '\n'
log_step "===== Final validation ====="
VALIDATE_RC=0
if [[ "$DRY_RUN" == "1" ]]; then
  log_info "DRY-RUN: skipping live validation (tests/validate.sh)"
else
  # shellcheck source=tests/validate.sh
  if ( set -uo pipefail; . "$REPO_ROOT/tests/validate.sh" ); then
    log_ok "validation passed"
  else
    VALIDATE_RC=$?
    log_warn "validation reported one or more failing cases (rc=$VALIDATE_RC)"
  fi
fi

# ---- Summary ----------------------------------------------------------------
printf '\n'
log_step "===== Summary ====="
log_info "Modules run: ${RAN_MODULES[*]:-none}"
if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
  log_warn "Modules with failures: ${FAILED_MODULES[*]}"
else
  log_ok "All selected modules completed without fatal errors."
fi
[[ -n "${LOG_FILE:-}" ]] && log_info "Full log: $LOG_FILE"

# Exit non-zero only if a module hard-failed or validation failed, so CI can see
# it — but the run itself always reaches this point (non-fatal step contract).
if [[ ${#FAILED_MODULES[@]} -gt 0 || "$VALIDATE_RC" -ne 0 ]]; then
  exit 1
fi
exit 0
