#!/usr/bin/env bash
# lib/fallback.sh — the primary/fallback engine. This is the spine of the repo.
#
# A "method" is just a shell function name. try_methods() walks an ordered list of
# methods for one logical tool, running each in a SUBSHELL so a failing method
# (even one that hits 'set -e') cannot abort the installer. It stops at the first
# success and logs which path won. If all methods fail it logs an error and
# returns non-zero — but never exits, satisfying the non-fatal-failures rule.
#
# Usage:
#   try_methods "kitty" \
#       method_kitty_official \
#       method_kitty_apt \
#       method_kitty_wezterm_fallback
#
# Each method function should:
#   - return 0 on success (tool installed / already present),
#   - return non-zero on failure (engine moves to the next method),
#   - use run()/run_quiet() for all state changes (so --dry-run is honored).
[[ -n "${_LIB_FALLBACK_SOURCED:-}" ]] && return 0
_LIB_FALLBACK_SOURCED=1

# LAST_METHOD records the winning method name for callers that source this file.
LAST_METHOD=""

# try_methods <label> <method1> [<method2> ...]
try_methods() {
  local label="$1"; shift
  local method rc total idx=0
  total="$#"
  LAST_METHOD=""

  for method in "$@"; do
    idx=$((idx + 1))
    log_step "[$label] trying method $idx/$total: $method"

    # Subshell isolation: a method's 'set -e' / failure cannot kill us.
    (
      set -euo pipefail
      "$method"
    )
    rc=$?

    if [[ $rc -eq 0 ]]; then
      # shellcheck disable=SC2034  # consumed by modules that source this file
      LAST_METHOD="$method"
      log_ok "[$label] installed via '$method'"
      return 0
    fi
    log_warn "[$label] method '$method' failed (rc=$rc); trying next"
  done

  log_error "[$label] all $total method(s) failed — leaving system unchanged for this tool"
  return 1
}

# verify <cmd...> — final "did the install succeed?" check for an install method.
# In --dry-run nothing was actually installed, so we can't check presence; assume
# success so the engine reports the method that WOULD have run as the winner.
# (Note: the "already present / skip" methods must NOT use this — they need to
# report the real current state so the engine moves on to show what it'd install.)
verify() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  "$@"
}

# dry_skip <human description> — early-out for methods whose real logic (extracting
# a downloaded archive, locating a binary) can't run meaningfully in --dry-run.
# Usage:  dry_skip "install glow from GitHub release" && return 0
dry_skip() {
  [[ "${DRY_RUN:-0}" == "1" ]] || return 1
  log_info "[DRY] would $1"
  return 0
}

# require_network <label> — guard for download-based methods. Returns non-zero
# (so the engine falls through to an offline method) when there is no network.
require_network() {
  local label="$1"
  if [[ "${DETECT_NETWORK:-0}" != "1" ]]; then
    log_warn "[$label] no network — skipping download-based method"
    return 1
  fi
  return 0
}

# pypi_reachable — FAST closed-path probe before any PyPI install. Returns 0 if
# the package *file* host answers within a few seconds, else non-zero so callers
# can skip a slow `uv` retry loop (which otherwise burns ~45-50s x3 before giving
# up) and defer instead. This is the design point: detect the closed path in
# seconds, not minutes.
#
#   - We probe files.pythonhosted.org because that is the host that actually
#     serves wheels/sdists and the one a corporate proxy was observed to block;
#     the index (pypi.org) can resolve while downloads still hang.
#   - No `-f`: any HTTP response (even 404) means the host is reachable; only a
#     connect/timeout failure (the block symptom) yields a non-zero curl exit.
#   - Host overridable via PYPI_PROBE_URL for tests.
PYPI_PROBE_URL="${PYPI_PROBE_URL:-https://files.pythonhosted.org/}"
pypi_reachable() {
  # No network at all -> definitely closed.
  [[ "${DETECT_NETWORK:-0}" == "1" ]] || return 1
  # Can't probe without curl: don't block the (rare) curl-less path; let uv try.
  have curl || return 0
  curl -sS -I --connect-timeout 3 --max-time 5 -o /dev/null "$PYPI_PROBE_URL" 2>/dev/null
}
