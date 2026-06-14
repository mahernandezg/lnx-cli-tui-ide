#!/usr/bin/env bash
# modules/90-vscodium.sh — VSCodium, gated behind --with-vscodium.
#
# Heavy Electron; for emergencies only. install.sh never selects this module
# unless --with-vscodium (or an explicit --only vscodium). This script also
# self-guards so sourcing it directly does nothing without the flag.
if [[ "${WITH_VSCODIUM:-0}" != "1" ]]; then
  log_info "vscodium: skipped (enable with --with-vscodium)"
  return 0
fi

_codium_present() { have codium; }

method_codium_present() { _codium_present || return 1; log_info "vscodium already present"; }

method_codium_repo() {
  dry_skip "add the VSCodium apt repo and install 'codium'" && return 0
  require_network "vscodium" || return 1
  apt_can_use || return 1
  have curl || { log_warn "vscodium: curl missing"; return 1; }
  # Add the VSCodium apt repository (key + source), then install.
  local key="/usr/share/keyrings/vscodium-archive-keyring.gpg"
  local list="/etc/apt/sources.list.d/vscodium.list"
  if [[ ! -f "$key" ]]; then
    run bash -c "curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
      | gpg --dearmor | $SUDO dd of='$key'" || return 1
  fi
  if [[ ! -f "$list" ]]; then
    run bash -c "echo 'deb [signed-by=$key] https://download.vscodium.com/debs vscodium main' \
      | $SUDO tee '$list' >/dev/null" || return 1
  fi
  _APT_UPDATED=0   # force a refresh now that we added a source
  apt_install codium || return 1
  verify _codium_present
}

method_codium_release_deb() {
  dry_skip "install VSCodium from its latest GitHub .deb release" && return 0
  require_network "vscodium" || return 1
  have curl || return 1
  local arch tmp
  case "$DETECT_ARCH" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) log_warn "vscodium: unsupported arch $DETECT_ARCH"; return 1 ;;
  esac
  tmp="$(mktemp -d)"
  # Resolve the latest .deb asset from the GitHub releases API.
  local url
  url="$(curl -fsSL https://api.github.com/repos/VSCodium/vscodium/releases/latest 2>/dev/null \
        | grep -oE "https://[^\"]*_${arch}\.deb" | grep -iv 'insider' | head -n1)"
  [[ -z "$url" ]] && { log_warn "vscodium: could not resolve .deb asset"; rm -rf "$tmp"; return 1; }
  run_quiet curl -L -o "$tmp/codium.deb" "$url" || { rm -rf "$tmp"; return 1; }
  run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmp/codium.deb" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  verify _codium_present
}

try_methods "vscodium" method_codium_present method_codium_repo method_codium_release_deb

log_ok "vscodium module done"
