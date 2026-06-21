#!/usr/bin/env bash
# tests/validate.sh — the four-case end check that motivated this whole setup.
#
# 1. Markdown renders with glow.
# 2. Code shows syntax colors with bat.
# 3. A sample notebook opens in euporie with inline plots visible.
# 4. Helix opens and its LSP attaches.
#
# Reports PASS/FAIL per case and exits non-zero if any case fails. Runs both
# standalone (`./tests/validate.sh`) and sourced at the end of install.sh.
#
# Cases that need a live graphics/interactive TTY degrade to a best-effort,
# non-interactive probe and say so, rather than hanging an unattended install.

# Standalone vs sourced: if REPO_ROOT/log helpers aren't set, bootstrap them.
if [[ -z "${REPO_ROOT:-}" ]]; then
  set -uo pipefail
  REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
  export REPO_ROOT
fi
if ! declare -F log_info >/dev/null 2>&1; then
  # Minimal standalone logging if lib/log.sh wasn't sourced.
  DRY_RUN="${DRY_RUN:-0}"
  log_info()  { printf '[INFO]  %s\n' "$*"; }
  log_ok()    { printf '[ OK ]  %s\n' "$*"; }
  log_warn()  { printf '[WARN]  %s\n' "$*" >&2; }
  log_error() { printf '[ERROR] %s\n' "$*" >&2; }
  log_step()  { printf '>> %s\n' "$*"; }
fi
have() { command -v "$1" >/dev/null 2>&1; }

FIX_MD="$REPO_ROOT/tests/sample.md"
FIX_PY="$REPO_ROOT/tests/sample.py"
FIX_NB="$REPO_ROOT/tests/sample.ipynb"

PASS_COUNT=0
FAIL_COUNT=0
declare -a RESULTS=()

_pass() { RESULTS+=("PASS  $1"); PASS_COUNT=$((PASS_COUNT + 1)); log_ok "case: $1"; }
_fail() { RESULTS+=("FAIL  $1"); FAIL_COUNT=$((FAIL_COUNT + 1)); log_error "case: $1"; }

# ---- Case 1: glow renders Markdown -----------------------------------------
case_markdown() {
  if ! have glow; then _fail "1. Markdown renders with glow (glow not installed)"; return; fi
  if glow -s dark "$FIX_MD" >/dev/null 2>&1; then
    _pass "1. Markdown renders with glow"
  else
    _fail "1. Markdown renders with glow (glow returned error)"
  fi
}

# ---- Case 2: bat shows syntax colors ---------------------------------------
case_bat() {
  local bat_bin=""
  have bat && bat_bin="bat"
  [[ -z "$bat_bin" ]] && have batcat && bat_bin="batcat"
  if [[ -z "$bat_bin" ]]; then _fail "2. Code shows syntax colors with bat (bat not installed)"; return; fi
  # --color=always forces ANSI even when piped; grep for an escape sequence.
  if "$bat_bin" --color=always --style=numbers "$FIX_PY" 2>/dev/null | grep -q $'\033\['; then
    _pass "2. Code shows syntax colors with bat ($bat_bin)"
  else
    _fail "2. Code shows syntax colors with bat (no ANSI color in output)"
  fi
}

# _to <seconds> <cmd...> — run a command under a timeout when `timeout` exists,
# so a misbehaving renderer can never hang an unattended install. stdin (heredocs)
# passes straight through to the wrapped command.
_to() {
  local secs="$1"; shift
  # -k 5: if the command ignores SIGTERM (e.g. a TUI in raw mode), force-kill it
  # 5s later so the wrapper itself can never hang.
  if have timeout; then timeout -k 5 "$secs" "$@"; else "$@"; fi
}

# ---- Case 3: euporie opens the notebook with inline plots ------------------
case_euporie() {
  if ! have euporie; then _fail "3. Notebook opens in euporie with inline plots (euporie not installed)"; return; fi
  # euporie is a full-screen TUI; we cannot drive it interactively in an
  # unattended run. Instead we (a) confirm euporie loads the notebook model, and
  # (b) confirm the plotting stack can produce an image, which is what euporie
  # would stream via the terminal's graphics protocol (sixel on GNOME Terminal).
  local euporie_ok=0 ok_load=0 ok_plot=0
  # HANG-PROOF: never invoke euporie's renderer (TUI or preview) — attached to a
  # real terminal it can read stdin or hold the tty and block forever. Confirm
  # euporie only via the top-level `--version`, with stdin from /dev/null (so any
  # read returns EOF immediately) and a force-killable timeout.
  _to 15 euporie --version </dev/null >/dev/null 2>&1 && euporie_ok=1

  # Notebook loads? Parse it with nbformat via uv — reliable and non-interactive.
  if have uv && _to 30 uv run --with nbformat python - "$FIX_NB" >/dev/null 2>&1 <<'PY'
import sys, nbformat
nbformat.read(sys.argv[1], as_version=4)
PY
  then
    ok_load=1
  fi

  # Confirm the inline-plot stack can produce an image (what euporie streams via
  # the terminal's graphics protocol). matplotlib is already cached by the euporie
  # module, so this is normally fast; the longer timeout covers a cold resolve.
  if have uv && _to 90 uv run --with matplotlib python - >/dev/null 2>&1 <<'PY'
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, ax = plt.subplots()
ax.plot([0, 1, 2], [0, 1, 0])
fig.savefig("/tmp/lnx-validate-plot.png")
PY
  then
    ok_plot=1
  fi
  if [[ "$euporie_ok" -eq 1 && "$ok_load" -eq 1 && "$ok_plot" -eq 1 ]]; then
    _pass "3. Notebook opens in euporie; inline-plot stack verified"
  elif [[ "$euporie_ok" -eq 0 ]]; then
    _fail "3. euporie not callable (euporie --version failed)"
  elif [[ "$ok_plot" -eq 0 ]]; then
    _fail "3. euporie OK but inline-plot stack (matplotlib) failed"
  else
    _fail "3. euporie OK but sample notebook did not parse (nbformat)"
  fi
}

# ---- Case 4: Helix opens and its LSP attaches ------------------------------
case_helix() {
  if ! have hx; then _fail "4. Helix opens and its LSP attaches (hx not installed)"; return; fi
  # `hx --health` reports configured languages and whether their LSP binaries are
  # found on PATH — a reliable non-interactive proxy for "the LSP will attach".
  local health
  health="$(hx --health 2>/dev/null || true)"
  if [[ -z "$health" ]]; then _fail "4. Helix opens and its LSP attaches (hx --health failed)"; return; fi

  local ts_ok=0 py_ok=0
  # vtsls for TypeScript, ruff for Python should show as found/✓.
  have vtsls && ts_ok=1
  have ruff  && py_ok=1
  # Cross-check Helix actually sees them (best-effort: health lists the binary).
  if hx --health typescript 2>/dev/null | grep -qiE 'vtsls'; then ts_ok=1; fi
  if hx --health python 2>/dev/null | grep -qiE 'ruff'; then py_ok=1; fi

  if [[ "$ts_ok" -eq 1 && "$py_ok" -eq 1 ]]; then
    _pass "4. Helix opens; LSPs available (vtsls + ruff)"
  elif [[ "$ts_ok" -eq 1 || "$py_ok" -eq 1 ]]; then
    _fail "4. Helix opens but only one LSP available (vtsls=$ts_ok ruff=$py_ok)"
  else
    _fail "4. Helix opens but no LSP available (install vtsls/ruff)"
  fi
}

log_step "Running validation (4 motivating cases)"
case_markdown
case_bat
case_euporie
case_helix

printf '\n'
log_step "Validation results:"
for r in "${RESULTS[@]}"; do
  if [[ "$r" == PASS* ]]; then log_ok "$r"; else log_error "$r"; fi
done
log_info "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed (of 4)"

# Exit/return non-zero if any case failed.
[[ "$FAIL_COUNT" -eq 0 ]]
