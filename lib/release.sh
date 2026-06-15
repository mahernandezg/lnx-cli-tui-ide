#!/usr/bin/env bash
# lib/release.sh — install a single static binary from a GitHub release archive
# into ~/.local/bin. Shared by the release-binary install/fallback methods
# (glow, yazi, ruff, ...). Pairs with lib/github.sh's latest-tag resolver:
# resolve a tag, build the asset URL, then call release_install_bin to fetch,
# extract, and install it.
[[ -n "${_LIB_RELEASE_SOURCED:-}" ]] && return 0
_LIB_RELEASE_SOURCED=1

# release_install_bin <name> <url> <inner-binary-name>
#   Downloads <url> (.tar.gz/.tgz/.zip), finds <inner-binary-name> anywhere in the
#   extracted tree, installs it 0755 into ~/.local/bin, and returns whether it is
#   then callable. Returns non-zero on ANY failure so the fallback engine moves to
#   the next method. Honors --dry-run (the dry_skip guard returns before any real
#   download, since there is no archive to extract in a dry run).
release_install_bin() {
  local name="$1" url="$2" inner="$3" tmp found
  dry_skip "download and install '$name' from a release archive" && return 0
  require_network "$name" || return 1
  have curl || return 1
  tmp="$(mktemp -d)"
  run_quiet curl -L -o "$tmp/archive" "$url" || { rm -rf "$tmp"; return 1; }
  if [[ "$url" == *.tar.gz || "$url" == *.tgz ]]; then
    run_quiet tar -xzf "$tmp/archive" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  elif [[ "$url" == *.zip ]]; then
    have unzip || apt_install unzip || true
    run_quiet unzip -o "$tmp/archive" -d "$tmp" || { rm -rf "$tmp"; return 1; }
  else
    log_warn "$name: unsupported archive type for $url"; rm -rf "$tmp"; return 1
  fi
  found="$(find "$tmp" -type f -name "$inner" | head -n1)"
  [[ -z "$found" ]] && { log_warn "$name: binary '$inner' not found in archive"; rm -rf "$tmp"; return 1; }
  run mkdir -p "$HOME/.local/bin"
  run install -m 0755 "$found" "$HOME/.local/bin/$inner"
  rm -rf "$tmp"
  export PATH="$HOME/.local/bin:$PATH"
  have "$inner"
}
