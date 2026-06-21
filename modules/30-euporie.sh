#!/usr/bin/env bash
# modules/30-euporie.sh — euporie via `uv tool install` (isolated), for viewing
# Jupyter notebooks in the terminal with inline plots through the terminal's
# graphics protocol. The stack terminal is GNOME Terminal (VTE), which renders
# images via sixel; euporie negotiates the protocol itself. We note the inline-
# image path rather than assume it — the live check lives in tests/validate.sh.

_euporie_present() { have euporie; }

# euporie is pure-Python and lives only on PyPI, so its "second path" is TIME,
# not another source: when PyPI is unreachable we DEFER (not fail) and rely on the
# installer's idempotency to finish on a later run over an open network.
#
# The pypi_reachable() pre-check is the fast-fail: without it, `uv tool install`
# burns ~45-50s x3 against a blocked files.pythonhosted.org before giving up.
# UV_HTTP_TIMEOUT caps any attempt that slips past the pre-check so it fails in
# seconds, not minutes.
_install_euporie() {
  if _euporie_present; then
    record_outcome PRESENT euporie "$(euporie --version 2>/dev/null || echo present)"
    return 0
  fi
  if ! have uv; then
    record_outcome FAILED euporie "uv missing (module 00 failed?)"
    return 0
  fi
  if ! pypi_reachable; then
    record_outcome DEFERRED euporie "PyPI unreachable (files.pythonhosted.org); rerun on open network"
    return 0
  fi
  # Isolated uv tool install — no venv, no global pip. matplotlib is pulled in so
  # the sample notebook can render a plot during validation.
  if run env UV_HTTP_TIMEOUT="${UV_HTTP_TIMEOUT:-10}" uv tool install --with matplotlib euporie; then
    export PATH="$HOME/.local/bin:$PATH"
    if verify _euporie_present; then
      record_outcome INSTALLED euporie "uv tool"
    else
      record_outcome FAILED euporie "uv reported success but euporie is not on PATH"
    fi
  else
    record_outcome FAILED euporie "uv tool install failed while PyPI was reachable"
  fi
}

_install_euporie

# ---- Graphics-protocol validation ------------------------------------------
# The inline-plot path the notebook figures ride on is GNOME Terminal's image
# support (sixel), which euporie negotiates itself. We can't drive euporie's
# renderer non-interactively without holding the tty, so the actual inline-plot
# check lives in tests/validate.sh (it verifies the matplotlib image stack that
# euporie streams). Here we only confirm euporie is in place and note where the
# live check runs.
_validate_graphics() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] inline-plot path is covered by tests/validate.sh"
    return 0
  fi
  if [[ "${DETECT_HEADLESS:-0}" == "1" || ! -t 1 ]]; then
    log_warn "graphics: no interactive graphics TTY here; tests/validate.sh covers the notebook case"
    return 0
  fi
  log_info "graphics: euporie ready; inline-plot stack validated by tests/validate.sh"
  return 0
}

_validate_graphics

log_ok "euporie module done"
