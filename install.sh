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
FORCE_PROFILE_KEYS=0
ONLY_MODULES=()
SKIP_MODULES=()
export DRY_RUN VERBOSE

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --dry-run            Print exactly what would happen; change nothing.
  --only <module>      Run only the given module (repeatable). Match by number
                       or name fragment, e.g. --only terminal --only 45-micro
  --skip <module>      Skip the given module (repeatable).
  --with-vscodium      Also install VSCodium (off by default; heavy Electron).
  --force-profile-keys Reload the vendored GNOME Terminal profile keys (e.g. the
                       underline cursor) into an ALREADY-EXISTING mahg-dark/-light
                       profile, keeping its UUID. Pairs well with --only 80.
  --verbose            Verbose/debug logging.
  -h, --help           Show this help.

Modules (run in this order):
  00-uv  02-golang  05-ai-agents  10-terminal  15-tmux  20-viewers  30-euporie
  40-ruff  45-micro  50-git-docker-tui  60-ssh-alias  70-starship  75-tab-title
  80-gnome-terminal-profile  90-vscodium (gated)  95-mahg-help  96-mahg-wt
  97-termux

Platform note: on Termux/Android the terminal IS Termux, so 80 (GNOME Terminal
profile), 90 (Electron VSCodium) and 96 (Windows Terminal helper) are skipped,
and 97-termux runs the Android-only bootstrap.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)       DRY_RUN=1 ;;
    --verbose)       VERBOSE=1 ;;
    --with-vscodium) WITH_VSCODIUM=1 ;;
    --force-profile-keys) FORCE_PROFILE_KEYS=1 ;;
    --only)          shift; [[ $# -gt 0 ]] || { echo "--only needs an argument" >&2; exit 2; }; ONLY_MODULES+=("$1") ;;
    --skip)          shift; [[ $# -gt 0 ]] || { echo "--skip needs an argument" >&2; exit 2; }; SKIP_MODULES+=("$1") ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
export DRY_RUN VERBOSE WITH_VSCODIUM FORCE_PROFILE_KEYS

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
# shellcheck source=lib/release.sh
. "$REPO_ROOT/lib/release.sh"
# shellcheck source=lib/outcome.sh
. "$REPO_ROOT/lib/outcome.sh"

log_init
outcome_init

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

# platform_skip <name> — true if a module simply does not apply on the current
# platform. Android/Termux has no GNOME Terminal (80), can't run an Electron
# VSCodium (90), and is not WSL/Windows Terminal (96), so those are skipped with a
# logged reason and a NOTE rather than run-then-no-op — keeping the run output
# honest about what applies on Android. An explicit --only is an escape hatch.
platform_skip() {
  local name="$1"
  [[ "${DETECT_PLATFORM:-debian}" == "termux" ]] || return 1
  if [[ ${#ONLY_MODULES[@]} -gt 0 ]] && matches_any "$name" "${ONLY_MODULES[@]}"; then
    return 1
  fi
  case "$name" in
    *gnome-terminal-profile*|*vscodium*|*mahg-wt*) return 0 ;;
  esac
  return 1
}

# ---- Dispatch ---------------------------------------------------------------
FAILED_MODULES=()
RAN_MODULES=()

for mod in "${ALL_MODULES[@]}"; do
  if ! module_selected "$mod"; then
    log_debug "skip module: $mod"
    continue
  fi
  if platform_skip "$mod"; then
    log_info "skip $mod — not applicable on $DETECT_PLATFORM (no GNOME Terminal / Electron / Windows Terminal on Android)"
    record_outcome NOTE "$mod" "skipped on $DETECT_PLATFORM — not applicable on Android"
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
# Honest accounting. Read the per-tool ledger (lib/outcome.sh) that modules wrote
# from their subshells, partition it, and tell the truth: never claim "without
# fatal errors" when pieces are missing.
printf '\n'
log_step "===== Summary ====="
log_info "Modules run: ${RAN_MODULES[*]:-none}"

DEFERRED_ITEMS=()
FAILED_ITEMS=()
NOTE_ITEMS=()
if [[ -n "${OUTCOME_FILE:-}" && -f "$OUTCOME_FILE" ]]; then
  while IFS=$'\t' read -r o_status o_tool o_detail; do
    [[ -z "$o_status" ]] && continue
    case "$o_status" in
      DEFERRED) DEFERRED_ITEMS+=("$o_tool — ${o_detail:-deferred}") ;;
      FAILED)   FAILED_ITEMS+=("$o_tool — ${o_detail:-failed}") ;;
      NOTE)     NOTE_ITEMS+=("$o_tool — ${o_detail:-note}") ;;
    esac
  done <"$OUTCOME_FILE"
fi

# A real failure is a hard-failed module, a tool with all paths exhausted (no
# network excuse), or a failed validation. DEFERRED is NOT a failure.
HARD_FAIL=0
if [[ ${#FAILED_MODULES[@]} -gt 0 ]]; then
  log_error "Modules with failures: ${FAILED_MODULES[*]}"
  HARD_FAIL=1
fi
if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
  log_error "Tools FAILED (all paths exhausted):"
  for it in "${FAILED_ITEMS[@]}"; do log_error "  - $it"; done
  HARD_FAIL=1
fi
[[ "$VALIDATE_RC" -ne 0 ]] && HARD_FAIL=1

PENDING=0
if [[ ${#DEFERRED_ITEMS[@]} -gt 0 ]]; then
  PENDING=1
  log_warn "Tools DEFERRED (path closed; not installed, not failed):"
  for it in "${DEFERRED_ITEMS[@]}"; do log_warn "  - $it"; done
  log_warn "Re-run ./install.sh on an open network to complete the deferred items (idempotent)."
fi

# NOTE items are informational prerequisites a rerun cannot fix; never gate on them.
if [[ ${#NOTE_ITEMS[@]} -gt 0 ]]; then
  log_info "Notes (prerequisites a rerun will not fix):"
  for it in "${NOTE_ITEMS[@]}"; do log_info "  - $it"; done
fi

if [[ "$HARD_FAIL" -eq 1 ]]; then
  log_error "Status: completed WITH FAILURES — see the FAILED items above."
elif [[ "$PENDING" -eq 1 ]]; then
  log_warn "Status: completed WITH PENDING items — nothing failed, but some tools were deferred (rerun on open network)."
else
  log_ok "All selected modules completed without fatal errors."
fi

# if-block (not a bare '[[…]] && …'): keeps this off the bug class even if a future
# edit moves it to a function's tail position. See tests/test_sete.sh.
if [[ -n "${LOG_FILE:-}" ]]; then
  log_info "Full log: $LOG_FILE"
fi

# Exit codes are CI-detectable and distinct:
#   1  hard failure (module/tool failed, or validation failed)
#   2  completed but some tools DEFERRED (a rerun on open network finishes them)
#   0  clean — everything installed/present
# The run itself always reaches this point (non-fatal step contract).
if [[ "$HARD_FAIL" -eq 1 ]]; then
  exit 1
elif [[ "$PENDING" -eq 1 ]]; then
  exit 2
fi
exit 0
