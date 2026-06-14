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
  if shellcheck -x -S style "$ROOT"/install.sh "$ROOT"/lib/*.sh "$ROOT"/modules/*.sh "$ROOT"/tests/*.sh; then
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
