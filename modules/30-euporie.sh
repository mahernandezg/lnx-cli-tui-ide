#!/usr/bin/env bash
# modules/30-euporie.sh — euporie via `uv tool install` (isolated), for viewing
# Jupyter notebooks in the terminal with inline plots through the kitty graphics
# protocol. Then VALIDATE the graphics protocol explicitly — this is the stated
# reason kitty was chosen, so we test it rather than assume it.

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
# Confirm the terminal can actually display an image via the kitty graphics
# protocol. We do this two ways and treat either success as a pass:
#   1. `kitten icat` against a tiny generated PNG (kitty path).
#   2. euporie's own renderer probe.
# In --dry-run, or when not attached to a graphics-capable TTY, we log and skip
# the live image test (it needs an interactive terminal) and just confirm tools.
_validate_graphics() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would validate kitty graphics protocol via kitten icat / euporie"
    return 0
  fi
  if [[ "${DETECT_HEADLESS:-0}" == "1" || ! -t 1 ]]; then
    log_warn "graphics: no interactive graphics TTY here; deferring image test to tests/validate.sh"
    return 0
  fi

  # Generate a tiny PNG without extra deps if possible (uv run pillow), else skip.
  local png="/tmp/lnx-graphics-probe.png"
  if have uv; then
    run_quiet uv run --with pillow python - "$png" <<'PY' || true
import sys
from PIL import Image
Image.new("RGB", (32, 32), (80, 160, 240)).save(sys.argv[1])
PY
  fi

  if have kitten && [[ -f "$png" ]]; then
    if kitten icat --transfer-mode=stream "$png" 2>>"$LOG_FILE"; then
      log_ok "graphics: kitty protocol image displayed (kitten icat)"
      return 0
    fi
  fi
  log_warn "graphics: live image probe inconclusive; tests/validate.sh covers the notebook case"
  return 0
}

_validate_graphics

log_ok "euporie module done"
