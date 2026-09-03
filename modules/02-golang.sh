#!/usr/bin/env bash
# modules/02-golang.sh — Go toolchain: official install in /usr/local/go + a
# persistent PATH supplied centrally by modules/03-shell-env.sh.
#
# WHY: the repo's other modules don't ship Go, and apt's Go is stale. This installs
# the OFFICIAL stable Go (go.dev tarball, sha256-verified) into /usr/local/go and
# GUARANTEES that /usr/local/go/bin (the toolchain) and ~/go/bin (GOPATH bin, where
# `go install` lands) are on PATH for every new shell — native Debian and WSL alike.
#
# VERIFY is non-destructive: an existing Go >= the minimum target is kept (PRESENT);
# only the PATH guard is ALWAYS (re)applied — that is the common real failure (Go
# installed but /usr/local/go/bin not on PATH). Honors --dry-run. Sourced by
# install.sh (inherits run/run_quiet, log_*, record_outcome, DRY_RUN, SUDO, HOME, have,
# require_network).

GO_MIN_MINOR="${GOLANG_MIN_MINOR:-26}"     # require Go >= 1.<MIN> (the Professor needs 1.26)
GO_VERSION_OVERRIDE="${GOLANG_VERSION:-}"  # e.g. "go1.26.4" to pin; default = latest stable
GO_ROOT="${GOLANG_ROOT:-/usr/local/go}"    # overridable for hermetic tests

# ---- detection --------------------------------------------------------------
_go_bin() {  # echo a usable go binary (PATH first, then $GO_ROOT); empty if none
  if command -v go >/dev/null 2>&1; then command -v go; return 0; fi
  [[ -x "$GO_ROOT/bin/go" ]] && { printf '%s' "$GO_ROOT/bin/go"; return 0; }
  return 1
}
_go_minor() {  # echo the installed Go minor (e.g. 26); empty if no Go
  local gb ver; gb="$(_go_bin)" || return 1
  ver="$("$gb" version 2>/dev/null | grep -oE 'go[0-9]+\.[0-9]+' | head -1 | sed 's/go[0-9]*\.//')"
  printf '%s' "$ver"
}
_go_arch() { case "$(uname -m)" in x86_64) echo amd64;; aarch64|arm64) echo arm64;; *) echo "";; esac; }

# ---- resolve latest stable {version, sha256} for linux/<arch> via go.dev JSON --
GO_DL_VERSION=""; GO_DL_SHA=""
_go_resolve() {
  local arch="$1" json
  json="$(curl -fsSL "https://go.dev/dl/?mode=json" 2>/dev/null)" || return 1
  if [[ -n "$GO_VERSION_OVERRIDE" ]]; then
    GO_DL_VERSION="$GO_VERSION_OVERRIDE"
  else
    GO_DL_VERSION="$(printf '%s' "$json" | jq -r '[.[] | select(.stable==true)][0].version' 2>/dev/null)"
  fi
  [[ -z "$GO_DL_VERSION" || "$GO_DL_VERSION" == "null" ]] && return 1
  GO_DL_SHA="$(printf '%s' "$json" | jq -r --arg v "$GO_DL_VERSION" --arg f "${GO_DL_VERSION}.linux-${arch}.tar.gz" \
    '.[] | select(.version==$v) | .files[]? | select(.filename==$f) | .sha256' 2>/dev/null | head -1)"
  [[ -z "$GO_DL_SHA" || "$GO_DL_SHA" == "null" ]] && return 1
  return 0
}

# ---- VERIFY + INSTALL/RESTORE ----------------------------------------------
_install_go() {
  local minor; minor="$(_go_minor)"
  if [[ -n "$minor" && "$minor" =~ ^[0-9]+$ && "$minor" -ge "$GO_MIN_MINOR" ]]; then
    record_outcome PRESENT go "$("$(_go_bin)" version 2>/dev/null || echo present) (>= 1.$GO_MIN_MINOR) at $GO_ROOT"
    return 0
  fi
  local arch; arch="$(_go_arch)"
  [[ -z "$arch" ]] && { record_outcome NOTE go "unsupported arch $(uname -m); install Go by hand from go.dev"; return 0; }
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log_info "[DRY] would download the latest stable Go (go.dev, linux-$arch), verify sha256, and install to $GO_ROOT"
    record_outcome NOTE go "dry-run; would install the latest stable Go to $GO_ROOT"
    return 0
  fi
  have curl || { record_outcome DEFERRED go "curl missing; install Go from go.dev then re-run"; return 0; }
  have jq   || { record_outcome DEFERRED go "jq missing (needed to resolve the Go version+checksum); install jq then re-run"; return 0; }
  require_network go || { record_outcome DEFERRED go "offline; rerun on a network to fetch the official Go tarball"; return 0; }
  _go_resolve "$arch" || { record_outcome DEFERRED go "could not resolve the latest Go from go.dev; rerun later"; return 0; }
  local tgz="/tmp/${GO_DL_VERSION}.linux-${arch}.tar.gz"
  run_quiet curl -fsSL -o "$tgz" "https://go.dev/dl/${GO_DL_VERSION}.linux-${arch}.tar.gz" \
    || { record_outcome DEFERRED go "download of $GO_DL_VERSION failed; rerun later"; return 0; }
  if ! printf '%s  %s\n' "$GO_DL_SHA" "$tgz" | sha256sum -c - >/dev/null 2>&1; then
    rm -f "$tgz"
    record_outcome FAILED go "checksum MISMATCH for $GO_DL_VERSION — NOT installing (corrupt or tampered download)"
    return 0
  fi
  if [[ -z "${SUDO:-}" && "$(id -u)" -ne 0 ]]; then
    rm -f "$tgz"
    record_outcome DEFERRED go "no sudo; install by hand: sudo rm -rf $GO_ROOT && sudo tar -C /usr/local -xzf the go.dev tarball"
    return 0
  fi
  run $SUDO rm -rf "$GO_ROOT"
  if run $SUDO tar -C /usr/local -xzf "$tgz"; then
    rm -f "$tgz"
    record_outcome INSTALLED go "$GO_DL_VERSION -> $GO_ROOT (official go.dev tarball, sha256-verified)"
  else
    rm -f "$tgz"
    record_outcome DEFERRED go "extract failed; rerun later"
  fi
}

# ---- Run --------------------------------------------------------------------
_install_go

log_ok "golang module done (toolchain $GO_ROOT; PATH managed by 03-shell-env)"
