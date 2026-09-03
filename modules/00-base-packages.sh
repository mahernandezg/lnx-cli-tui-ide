#!/usr/bin/env bash
# modules/00-base-packages.sh — bootstrap dependencies needed by later modules.
#
# This file sorts before 00-uv.sh deliberately: curl/wget/CA trust must exist
# before any network installer is attempted. wl-clipboard is also part of the
# terminal environment contract because CLI/Nautilus helper scripts use wl-copy
# and wl-paste under Wayland. apt is the authoritative Debian install path.

_BASE_PACKAGES=(curl wget ca-certificates wl-clipboard)

_base_dep_present() {
  case "$1" in
    curl)            have curl ;;
    wget)            have wget ;;
    ca-certificates) dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null | grep -q 'install ok installed' ;;
    wl-clipboard)    have wl-copy && have wl-paste ;;
    *)               return 1 ;;
  esac
}

_install_base_packages() {
  local pkg
  local -a missing=()

  for pkg in "${_BASE_PACKAGES[@]}"; do
    if _base_dep_present "$pkg"; then
      record_outcome PRESENT "$pkg" "base dependency verified"
    else
      missing+=("$pkg")
    fi
  done

  [[ ${#missing[@]} -gt 0 ]] || return 0

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] would apt-get install base dependencies: ${missing[*]}"
    for pkg in "${missing[@]}"; do
      record_outcome NOTE "$pkg" "dry-run; missing base dependency would be installed via apt"
    done
    return 0
  fi

  if ! apt_can_use; then
    for pkg in "${missing[@]}"; do
      record_outcome FAILED "$pkg" "apt-get unavailable; required bootstrap dependency is missing"
    done
    return 0
  fi

  if ! apt_install "${missing[@]}"; then
    for pkg in "${missing[@]}"; do
      record_outcome DEFERRED "$pkg" "apt install failed; rerun with apt/network access"
    done
    return 0
  fi

  # apt returning zero is not enough: verify the command/package contract.
  for pkg in "${missing[@]}"; do
    if _base_dep_present "$pkg"; then
      record_outcome INSTALLED "$pkg" "apt; post-install verification passed"
    else
      record_outcome FAILED "$pkg" "apt returned success but post-install verification failed"
    fi
  done
}

_install_base_packages
log_ok "base-packages module done (curl, wget, ca-certificates, wl-clipboard)"
