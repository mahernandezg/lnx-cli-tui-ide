#!/usr/bin/env bash
# modules/40-ruff.sh — ruff: the fast Python linter & formatter.
#
# Standalone Python tooling (formerly bundled with the Helix editor module, which
# was retired). Two install paths so a blocked PyPI never leaves Python without
# ruff:
#   1. PyPI via uv — fast-fails when PyPI is unreachable so we don't burn a long uv
#      retry loop; UV_HTTP_TIMEOUT caps any attempt that slips past the probe.
#   2. prebuilt GitHub release binary — no PyPI, no Python install needed.
# Feeds the per-tool outcome ledger (lib/outcome.sh) so the final summary is honest.

method_ruff_uv() {
  have uv || { log_warn "ruff: uv missing"; return 1; }
  pypi_reachable || { log_warn "ruff: PyPI unreachable — skipping uv path (fast-fail)"; return 1; }
  run env UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-10}" uv tool install ruff || return 1
  export PATH="$HOME/.local/bin:$PATH"
  verify have ruff
}

# Prebuilt GitHub release binary (no PyPI). Same latest-tag resolver + helper as the
# other binaries.
method_ruff_github() {
  local target tag url
  case "$DETECT_ARCH" in
    x86_64)  target="x86_64-unknown-linux-gnu" ;;
    aarch64) target="aarch64-unknown-linux-gnu" ;;
    *) log_warn "ruff: unsupported arch $DETECT_ARCH for github release"; return 1 ;;
  esac
  tag="$(github_latest_tag astral-sh/ruff)" || return 1   # fall through on failure
  # ruff assets embed the tag dir but a bare target filename, e.g.
  # ruff-x86_64-unknown-linux-gnu.tar.gz (tag has no leading 'v').
  url="https://github.com/astral-sh/ruff/releases/download/${tag}/ruff-${target}.tar.gz"
  log_info "ruff: latest release ${tag} -> ${url}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would download and install ruff ${tag} (no fetch performed)"
    return 0
  fi
  release_install_bin ruff "$url" "ruff"
}

# ruff: uv (PyPI) -> GitHub release binary -> defer/fail.
if have ruff; then
  record_outcome PRESENT ruff
elif try_methods "ruff" method_ruff_uv method_ruff_github; then
  record_outcome INSTALLED ruff "$LAST_METHOD"
elif ! pypi_reachable; then
  # PyPI was the closed path AND the github fallback also failed -> a rerun on an
  # open network can still fix it, so this is a defer, not a hard failure.
  record_outcome DEFERRED ruff "PyPI unreachable and GitHub release fallback failed; rerun on open network"
else
  record_outcome FAILED ruff "uv and GitHub release paths both failed with PyPI reachable"
fi

log_ok "ruff module done"
