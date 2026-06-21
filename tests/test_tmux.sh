#!/usr/bin/env bash
# tests/test_tmux.sh — validate the vendored tmux config loads and applies the
# Professor's decisions (prefix C-a, mouse, base-index 1, brand navy, | / - split).
# Self-skips when tmux is not installed (like test_gnome_profile self-skips
# without dconf), so it never false-fails on a minimal box.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
ROOT="$(cd -- "$HERE/.." >/dev/null 2>&1 && pwd -P)"
CONF="$ROOT/dotfiles/tmux/tmux.conf"

if ! command -v tmux >/dev/null 2>&1; then
  echo "SKIP: tmux not installed"
  exit 0
fi
if [[ ! -f "$CONF" ]]; then
  echo "[FAIL] missing config: $CONF"
  exit 1
fi

# Private socket + isolated session so the real tmux server is never touched.
SOCK="lnx-tmux-test-$$"
ERR="$(mktemp)"
fail=0
pass() { echo "[PASS] $1"; }
die()  { echo "[FAIL] $1"; fail=1; }
stop() { tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true; rm -f "$ERR"; }

# 1. The config loads without error in a detached session.
if tmux -L "$SOCK" -f "$CONF" new-session -d -s t 2>"$ERR"; then
  pass "config loads without error"
else
  die "config failed to load: $(tr '\n' ' ' <"$ERR")"
  stop
  echo "test_tmux: FAILURES"
  exit 1
fi

# 2. The Professor's decisions are in effect.
prefix="$(tmux -L "$SOCK" show -g prefix 2>/dev/null)"
if [[ "$prefix" == *"C-a"* ]]; then pass "prefix = C-a"; else die "prefix not C-a ($prefix)"; fi

mouse="$(tmux -L "$SOCK" show -g mouse 2>/dev/null)"
if [[ "$mouse" == *"on"* ]]; then pass "mouse on"; else die "mouse not on ($mouse)"; fi

base="$(tmux -L "$SOCK" show -g base-index 2>/dev/null)"
if [[ "$base" == *"1" ]]; then pass "base-index 1"; else die "base-index not 1 ($base)"; fi

sstyle="$(tmux -L "$SOCK" show -g status-style 2>/dev/null)"
if [[ "$sstyle" == *"#070b16"* ]]; then pass "status bg = brand navy #070b16"; else die "status bg not navy ($sstyle)"; fi

# Restrict to the prefix table (our own bindings), matching the specific key.
binds="$(tmux -L "$SOCK" list-keys -T prefix 2>/dev/null)"
if echo "$binds" | grep -qE '[[:space:]]\|[[:space:]]+split-window -h'; then
  pass "vertical split bound (|)"
else
  die "no | -> split-window -h binding"
fi
if echo "$binds" | grep -qE '[[:space:]]-[[:space:]]+split-window -v'; then
  pass "horizontal split bound (-)"
else
  die "no - -> split-window -v binding"
fi

stop

if [[ "$fail" -eq 0 ]]; then
  echo "test_tmux: all checks passed"
  exit 0
else
  echo "test_tmux: FAILURES"
  exit 1
fi
