#!/usr/bin/env bash
# tests/run.sh — local test runner.
#
#   HARD gates (failure => non-zero exit):
#     - shellcheck (only if installed; clean is required when present)
#     - tests/test_sete.sh  (the set -e regression suite)
#   SOFT (informational, never gates the result):
#     - tests/validate.sh   (the 4 tool checks; will report skips on a bare box
#       that doesn't have glow/bat/euporie/helix installed)
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
ROOT="$(cd -- "$HERE/.." >/dev/null 2>&1 && pwd -P)"
rc=0

echo "== shellcheck (hard gate when installed) =="
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -x -S style "$ROOT"/install.sh "$ROOT"/lib/*.sh "$ROOT"/modules/*.sh "$ROOT"/tests/*.sh "$ROOT"/dotfiles/claude-code/statusline.sh "$ROOT"/bin/mahg-help "$ROOT"/bin/mahg-wt-apply; then
    echo "  shellcheck: clean"
  else
    echo "  shellcheck: FAILED"; rc=1
  fi
else
  echo "  shellcheck not installed — skipped (install: sudo apt install shellcheck)"
fi

echo "== tests/test_sete.sh (HARD gate: set -e regression) =="
if bash "$HERE/test_sete.sh"; then
  echo "  test_sete: PASS"
else
  echo "  test_sete: FAIL"; rc=1
fi

echo "== tests/test_ai_agents.sh (HARD gate: AI-agents verify/restore) =="
if bash "$HERE/test_ai_agents.sh"; then
  echo "  test_ai_agents: PASS"
else
  echo "  test_ai_agents: FAIL"; rc=1
fi

echo "== tests/test_pypi.sh (HARD gate: PyPI-unreachable resilience) =="
if bash "$HERE/test_pypi.sh"; then
  echo "  test_pypi: PASS"
else
  echo "  test_pypi: FAIL"; rc=1
fi

echo "== tests/test_tab_title.sh (HARD gate: tab-title managed block) =="
if bash "$HERE/test_tab_title.sh"; then
  echo "  test_tab_title: PASS"
else
  echo "  test_tab_title: FAIL"; rc=1
fi

echo "== tests/test_gnome_profile.sh (HARD gate: GNOME Terminal profile; self-skips w/o dconf) =="
if bash "$HERE/test_gnome_profile.sh"; then
  echo "  test_gnome_profile: PASS"
else
  echo "  test_gnome_profile: FAIL"; rc=1
fi

echo "== tests/test_statusline.sh (HARD gate: Claude Code statusline) =="
if bash "$HERE/test_statusline.sh"; then
  echo "  test_statusline: PASS"
else
  echo "  test_statusline: FAIL"; rc=1
fi

echo "== tests/test_tmux.sh (HARD gate: tmux mahg config; self-skips w/o tmux) =="
if bash "$HERE/test_tmux.sh"; then
  echo "  test_tmux: PASS"
else
  echo "  test_tmux: FAIL"; rc=1
fi

echo "== tests/test_mahg_help.sh (HARD gate: mahg-help cheatsheet) =="
if bash "$HERE/test_mahg_help.sh"; then
  echo "  test_mahg_help: PASS"
else
  echo "  test_mahg_help: FAIL"; rc=1
fi

echo "== tests/test_mahg_wt.sh (HARD gate: Windows Terminal scheme helper; self-skips w/o jq) =="
if bash "$HERE/test_mahg_wt.sh"; then
  echo "  test_mahg_wt: PASS"
else
  echo "  test_mahg_wt: FAIL"; rc=1
fi

echo "== tests/validate.sh (SOFT: tool checks, may skip on a bare box) =="
if bash "$HERE/validate.sh"; then
  echo "  validate: all cases passed"
else
  echo "  validate: some cases failed/skipped (soft — not a gate)"
fi

echo
if [[ "$rc" -eq 0 ]]; then
  echo "RESULT: PASS (hard gates green)"
else
  echo "RESULT: FAIL (a hard gate failed)"
fi
exit "$rc"
