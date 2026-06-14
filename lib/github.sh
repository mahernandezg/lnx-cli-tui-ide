#!/usr/bin/env bash
# lib/github.sh — resolve the latest STABLE release tag for a GitHub repo at
# runtime, so the repo never pins a version and never goes stale.
#
# Used by the release-binary install methods (yazi, helix, lazygit, lazydocker).
# Read-only (a single GET against the releases API), so it is safe to call even in
# --dry-run to show the version that WOULD be installed.
[[ -n "${_LIB_GITHUB_SOURCED:-}" ]] && return 0
_LIB_GITHUB_SOURCED=1

# github_latest_tag <owner/repo>
#   Prints the latest stable release tag (e.g. "v0.62.2" or "25.07.1") to STDOUT
#   and returns 0 on success. Returns non-zero on ANY failure (curl missing,
#   network down, rate-limited, malformed/empty response, unparseable tag) so the
#   caller can fall through to its next install method.
#
#   IMPORTANT: only stderr-bound logging (log_warn) is used here — never log_info
#   or verbose log_debug — because the caller captures STDOUT as the tag value.
#
#   Honors $GITHUB_TOKEN if present (optional; raises the 60 req/hr unauthenticated
#   rate limit to 5000). The token is never hardcoded and never committed.
github_latest_tag() {
  local repo="$1"
  local url="https://api.github.com/repos/${repo}/releases/latest"

  if ! have curl; then
    log_warn "github: curl missing — cannot resolve latest release for $repo"
    return 1
  fi

  # Optional auth header, only when a token is exported in the environment.
  local -a auth=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  local body
  if ! body="$(curl -fsSL --max-time 8 --retry 2 --retry-delay 1 \
                 -H 'Accept: application/vnd.github+json' \
                 -H 'X-GitHub-Api-Version: 2022-11-28' \
                 "${auth[@]}" "$url" 2>/dev/null)"; then
    log_warn "github: API unreachable or rate-limited for $repo — latest release unresolved"
    return 1
  fi
  if [[ -z "$body" ]]; then
    log_warn "github: empty response for $repo — latest release unresolved"
    return 1
  fi

  # Prefer jq when available; otherwise a dependency-free grep/sed extraction.
  local tag=""
  if have jq; then
    tag="$(printf '%s' "$body" | jq -r '.tag_name // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$tag" ]]; then
    tag="$(printf '%s' "$body" \
            | grep -m1 '"tag_name"' \
            | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  fi

  if [[ -z "$tag" || "$tag" == "null" ]]; then
    # A 403 rate-limit body has no tag_name; surface that clearly.
    if printf '%s' "$body" | grep -qi 'rate limit'; then
      log_warn "github: rate-limited for $repo (set GITHUB_TOKEN to raise the limit)"
    else
      log_warn "github: could not parse tag_name for $repo"
    fi
    return 1
  fi

  printf '%s\n' "$tag"
}
