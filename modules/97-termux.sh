#!/usr/bin/env bash
# modules/97-termux.sh — Termux (Android) bootstrap helpers. Termux-only.
#
# On Android the terminal IS Termux, so a few Termux-specific niceties have no
# Debian/WSL equivalent and live here. On any non-Termux host this module records
# a NOTE and does nothing. Everything is idempotent and non-fatal.
#
#   - shared storage: `termux-setup-storage` grants access to the device's shared
#     storage and creates ~/storage. It pops an Android permission dialog, so we
#     do NOT run it unprompted mid-install — we guide the user when ~/storage is
#     still absent, and report PRESENT once it exists.
#
# The terminal font itself is handled by modules/10-terminal.sh (the Termux branch
# of _install_termux_font), not here.

if [[ "${DETECT_PLATFORM:-debian}" != "termux" ]]; then
  record_outcome NOTE termux-setup "Android-only bootstrap; not on Termux — skipped"
else
  if [[ -d "$HOME/storage" ]]; then
    record_outcome PRESENT termux-storage "$HOME/storage present — shared storage already set up"
  else
    record_outcome NOTE termux-storage "run 'termux-setup-storage' once for shared-storage access (pops an Android dialog)"
  fi
fi

log_ok "termux module done"
