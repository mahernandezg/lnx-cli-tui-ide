#!/usr/bin/env bash
# lib/apt.sh — shared apt helpers used by several modules. Keeps sudo/apt logic
# in one place and runs `apt-get update` at most once per install.
[[ -n "${_LIB_APT_SOURCED:-}" ]] && return 0
_LIB_APT_SOURCED=1

_APT_UPDATED=0

# SUDO is empty when already root, else "sudo". Set once.
# Termux runs unprivileged with no sudo and a writable $PREFIX, so apt-get there
# needs NO elevation: the `have sudo` check leaves SUDO empty and the apt_*
# helpers below run `apt-get` directly, which is exactly right on Android.
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  if have sudo; then SUDO="sudo"; else SUDO=""; fi
fi

# apt_can_use — true if apt-get exists. Debian/Ubuntu and Termux all ship it
# (Termux's `pkg` is a thin apt wrapper), so this guard passes on every platform.
apt_can_use() { have apt-get; }

# apt_update_once — run apt-get update a single time per install run.
apt_update_once() {
  apt_can_use || { log_warn "apt: apt-get not available"; return 1; }
  if [[ "$_APT_UPDATED" == "1" ]]; then
    log_debug "apt: update already done this run"
    return 0
  fi
  require_network "apt-update" || return 1
  run $SUDO apt-get update -y || return 1
  _APT_UPDATED=1
}

# apt_install <pkg...> — install packages noninteractively.
apt_install() {
  apt_can_use || return 1
  apt_update_once || true
  run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# apt_pkg_candidate_version <pkg> — print apt's candidate version, or "" if none.
apt_pkg_candidate_version() {
  apt_can_use || { echo ""; return 1; }
  # || true: best-effort lookup; a non-zero pipe (odd apt state) must not abort
  # under set -e + pipefail. The caller treats empty output as "no candidate".
  apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}' | head -n1 || true
}

# apt_version_ge <pkg> <min> — true if apt candidate version >= min.
# Used to decide "apt is recent enough" vs "fall back to release binary".
apt_version_ge() {
  local pkg="$1" min="$2" cand
  cand="$(apt_pkg_candidate_version "$pkg")"
  [[ -z "$cand" || "$cand" == "(none)" ]] && return 1
  # Strip Debian epoch/revision noise to a leading dotted-numeric core.
  local core
  core="$(printf '%s' "$cand" | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)"
  [[ -z "$core" ]] && return 1
  version_ge "$core" "$min"
}
