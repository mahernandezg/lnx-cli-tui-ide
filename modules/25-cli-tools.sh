#!/usr/bin/env bash
# modules/25-cli-tools.sh — apt-native CLI/TUI set observed on the P53.
#
# This is intentionally curated from `apt-mark showmanual`, not every package on
# the workstation. It reproduces interactive monitors and development/diagnostic
# commands. GUI applications (notably gsmartcontrol) and host services stay in
# lnx-gui-ide or machine provisioning. Each package is verified by its command.

_CLI_PACKAGES=(
  adb btop fastfetch gh git git-lfs htop hwinfo iftop inxi iotop jq lsof ncdu
  nvme-cli nvtop powertop procps shellcheck smartmontools strace thefuck
  traceroute tree yq
)
_CLI_COMMANDS=(
  adb btop fastfetch gh git git-lfs htop hwinfo iftop inxi iotop jq lsof ncdu
  nvme nvtop powertop top shellcheck smartctl strace thefuck traceroute tree yq
)

_cli_tool_present() {
  local index="$1"
  have "${_CLI_COMMANDS[$index]}"
}

_install_cli_tools() {
  local i pkg
  local -a missing=() missing_indexes=()

  for i in "${!_CLI_PACKAGES[@]}"; do
    pkg="${_CLI_PACKAGES[$i]}"
    if _cli_tool_present "$i"; then
      record_outcome PRESENT "$pkg" "P53 CLI/TUI command ${_CLI_COMMANDS[$i]} verified"
    else
      missing+=("$pkg")
      missing_indexes+=("$i")
    fi
  done

  [[ ${#missing[@]} -gt 0 ]] || return 0

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] would apt-get install P53 CLI/TUI packages: ${missing[*]}"
    for pkg in "${missing[@]}"; do
      record_outcome NOTE "$pkg" "dry-run; missing P53 CLI/TUI package would be installed via apt"
    done
    return 0
  fi

  if ! apt_can_use; then
    for pkg in "${missing[@]}"; do
      record_outcome FAILED "$pkg" "apt-get unavailable; P53 CLI/TUI command missing"
    done
    return 0
  fi

  if ! apt_install "${missing[@]}"; then
    for pkg in "${missing[@]}"; do
      record_outcome DEFERRED "$pkg" "apt install failed; rerun with apt/network access"
    done
    return 0
  fi

  for i in "${missing_indexes[@]}"; do
    pkg="${_CLI_PACKAGES[$i]}"
    if _cli_tool_present "$i"; then
      record_outcome INSTALLED "$pkg" "apt; command ${_CLI_COMMANDS[$i]} verified"
    else
      record_outcome FAILED "$pkg" "apt returned success but command ${_CLI_COMMANDS[$i]} is unavailable"
    fi
  done
}

_install_cli_tools
log_ok "cli-tools module done (${#_CLI_PACKAGES[@]} P53 apt-native tools)"
