#!/usr/bin/env bash
# lib/detect.sh — environment detection. Runs once, up front, and records facts
# that modules branch on. Detection itself never mutates state, so it is safe to
# run even in --dry-run.
#
# Exported facts:
#   DETECT_DEBIAN_VERSION   e.g. "12" (major) or "" if unknown
#   DETECT_OS_PRETTY        pretty name string
#   DETECT_OPENGL_MAJOR     integer, 0 if undetectable
#   DETECT_OPENGL_MINOR     integer, 0 if undetectable
#   DETECT_OPENGL_STRING    raw "OpenGL version" line, or ""
#   DETECT_NETWORK          "1" if we can reach the internet, else "0"
#   DETECT_RAM_MB           total RAM in MB
#   DETECT_ARCH             uname -m
#   DETECT_HEADLESS         "1" if no DISPLAY/WAYLAND_DISPLAY, else "0"
#
# Helpers: have(), version_ge(), opengl_ge_33()
[[ -n "${_LIB_DETECT_SOURCED:-}" ]] && return 0
_LIB_DETECT_SOURCED=1

# have <cmd> — is a command on PATH? (handles bat/batcat naming in callers)
have() { command -v "$1" >/dev/null 2>&1; }

# version_ge <a> <b> — true if version a >= version b (dotted numeric compare).
version_ge() {
  [[ "$1" == "$2" ]] && return 0
  local lower
  lower="$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)"
  [[ "$lower" == "$2" ]]
}

_detect_debian() {
  DETECT_OS_PRETTY=""
  DETECT_DEBIAN_VERSION=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DETECT_OS_PRETTY="${PRETTY_NAME:-${NAME:-unknown}}"
    DETECT_DEBIAN_VERSION="${VERSION_ID:-}"
  elif [[ -r /etc/debian_version ]]; then
    DETECT_OS_PRETTY="Debian $(cat /etc/debian_version)"
    DETECT_DEBIAN_VERSION="$(cut -d. -f1 </etc/debian_version)"
  else
    DETECT_OS_PRETTY="unknown"
  fi
}

_detect_opengl() {
  DETECT_OPENGL_STRING=""
  DETECT_OPENGL_MAJOR=0
  DETECT_OPENGL_MINOR=0
  if have glxinfo; then
    # Example: "OpenGL version string: 4.6 (Compatibility Profile) Mesa 23.x"
    DETECT_OPENGL_STRING="$(glxinfo 2>/dev/null | grep -m1 -i 'OpenGL version' || true)"
    if [[ -n "$DETECT_OPENGL_STRING" ]]; then
      local ver
      ver="$(printf '%s' "$DETECT_OPENGL_STRING" | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
      if [[ -n "$ver" ]]; then
        DETECT_OPENGL_MAJOR="${ver%%.*}"
        DETECT_OPENGL_MINOR="${ver##*.}"
      fi
    fi
  fi
}

_detect_network() {
  DETECT_NETWORK=0
  # Cheap reachability check; prefer not to depend on ping (often blocked).
  if have curl; then
    curl -fsS --max-time 4 -o /dev/null https://github.com 2>/dev/null && DETECT_NETWORK=1
  elif have wget; then
    wget -q --timeout=4 -O /dev/null https://github.com 2>/dev/null && DETECT_NETWORK=1
  fi
  # Never let a failed reachability check (offline) bubble a non-zero return out
  # of this helper — under `set -e` that would abort the installer.
  return 0
}

_detect_ram() {
  DETECT_RAM_MB=0
  if [[ -r /proc/meminfo ]]; then
    local kb
    kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
    [[ -n "$kb" ]] && DETECT_RAM_MB=$(( kb / 1024 ))
  fi
  return 0  # keep set -e safe even if the meminfo parse yields nothing
}

# opengl_ge_33 — true if detected OpenGL >= 3.3 (a common GPU-acceleration
# threshold; informational now that the stack uses the system GNOME Terminal).
opengl_ge_33() {
  (( DETECT_OPENGL_MAJOR > 3 )) && return 0
  (( DETECT_OPENGL_MAJOR == 3 && DETECT_OPENGL_MINOR >= 3 )) && return 0
  return 1
}

# scrollback_lines_for_ram — a RAM-sized scrollback budget (informational; the
# system terminal and tmux keep their own history). Conservative tiers so old,
# RAM-constrained laptops don't hoard memory.
scrollback_lines_for_ram() {
  if   (( DETECT_RAM_MB >= 16000 )); then echo 100000
  elif (( DETECT_RAM_MB >= 8000  )); then echo 50000
  elif (( DETECT_RAM_MB >= 4000  )); then echo 20000
  else echo 8000
  fi
}

run_detection() {
  log_step "Detecting environment"
  _detect_debian
  _detect_opengl
  _detect_network
  _detect_ram
  DETECT_ARCH="$(uname -m)"
  DETECT_HEADLESS=0
  [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && DETECT_HEADLESS=1

  export DETECT_OS_PRETTY DETECT_DEBIAN_VERSION DETECT_OPENGL_STRING \
         DETECT_OPENGL_MAJOR DETECT_OPENGL_MINOR DETECT_NETWORK DETECT_RAM_MB \
         DETECT_ARCH DETECT_HEADLESS

  log_info "OS:        ${DETECT_OS_PRETTY:-unknown} (version_id=${DETECT_DEBIAN_VERSION:-?})"
  log_info "Arch:      ${DETECT_ARCH}"
  log_info "RAM:       ${DETECT_RAM_MB} MB  (scrollback budget -> $(scrollback_lines_for_ram) lines)"
  if [[ -n "$DETECT_OPENGL_STRING" ]]; then
    log_info "OpenGL:    ${DETECT_OPENGL_MAJOR}.${DETECT_OPENGL_MINOR}  ($(opengl_ge_33 && echo '>=3.3 -> GPU acceleration available' || echo '<3.3 -> software rendering'))"
  else
    log_info "OpenGL:    undetectable (no glxinfo / headless) -> terminal will assume software fallback"
  fi
  log_info "Network:   $([[ "$DETECT_NETWORK" == "1" ]] && echo 'online' || echo 'OFFLINE -> downloads will fall back to apt cache')"
  log_info "Headless:  $([[ "$DETECT_HEADLESS" == "1" ]] && echo 'yes (no DISPLAY)' || echo 'no')"
}
