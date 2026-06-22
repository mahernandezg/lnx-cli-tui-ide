#!/usr/bin/env bash
# scripts/publish-snapshot.sh — publish a CLEAN snapshot of this PRIVATE repo to a
# SEPARATE PUBLIC repo, carrying NONE of the private history.
#
# WHY (publication strategy A): this repo is the private workshop — full git history,
# the internal .postoffice/ coordination log, and a personal email in commit metadata.
# The PUBLIC repo is built by SNAPSHOT: only the final clean tree, with internal files
# EXCLUDED, a NEUTRAL commit identity (GitHub noreply), and a minimal snapshot-only
# history. So the public repo is clean BY CONSTRUCTION — no history rewrite needed.
#
# SAFE: re-runs gitleaks over the CLEAN tree as a pre-publish GATE and ABORTS on any
# finding. Defaults to --dry-run (prints what would be published + the exclusions and
# changes nothing); you must pass --publish to actually create the snapshot and push.
set -uo pipefail

# ---- Exclusion list — what NEVER goes to the public snapshot (documented) ----
# logs/, *.bak.*, state/, config.env are gitignored, so they are never tracked and never
# appear in `git archive HEAD` — they cannot leak here. These EXCLUDES remove TRACKED
# paths (and prefixes) that must stay private.
EXCLUDES=(
  ".postoffice"           # internal strategy<->executor coordination log
  "docs/security-audit-"  # internal security-audit reports (prefix match)
  "web-ext-artifacts"     # build artifacts (defensive; not in this repo)
)

PUBLIC_REMOTE="${SNAPSHOT_REMOTE:-https://github.com/mahernandezg/lnx-cli-tui-ide-public.git}"
AUTHOR_NAME="${SNAPSHOT_AUTHOR_NAME:-Manuel Hernández Giuliani}"
AUTHOR_EMAIL="${SNAPSHOT_AUTHOR_EMAIL:-5350981+mahernandezg@users.noreply.github.com}"
DO_PUBLISH=0
MESSAGE=""

usage() {
  cat <<'EOF'
Usage: scripts/publish-snapshot.sh [--publish] [--remote URL] [--message MSG]
                                   [--author-name NAME] [--author-email EMAIL]
  (default)        DRY-RUN: build the clean tree, run the gitleaks gate, print the plan; no push.
  --publish        actually create the snapshot commit and push to the public remote.
  --remote URL     public git remote (default: the lnx-cli-tui-ide-public repo).
  --message MSG    snapshot commit subject (default: "Snapshot of <repo> @ <shorthash>").
  --author-name    commit author/committer name  (default: the project author).
  --author-email   commit author/committer email (default: GitHub noreply — NOT a personal email).
The public commit identity is NEUTRAL (GitHub noreply) by default; the private repo keeps its own.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)       DO_PUBLISH=1 ;;
    --dry-run)       DO_PUBLISH=0 ;;
    --remote)        PUBLIC_REMOTE="${2:?}"; shift ;;
    --message)       MESSAGE="${2:?}"; shift ;;
    --author-name)   AUTHOR_NAME="${2:?}"; shift ;;
    --author-email)  AUTHOR_EMAIL="${2:?}"; shift ;;
    -h|--help)       usage; exit 0 ;;
    *) printf 'publish-snapshot: unknown argument: %s (try -h)\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

_die()  { printf 'publish-snapshot: ERROR: %s\n' "$*" >&2; exit 1; }
_info() { printf '%s\n' "$*"; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || _die "not inside a git repository"
cd "$REPO_ROOT" || _die "cannot cd to repo root"

# ---- Preconditions ----------------------------------------------------------
_preconditions() {
  [[ -z "$(git status --porcelain)" ]] || _die "working tree is not clean — commit or stash first"
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" != "main" ]]; then
    if [[ "$DO_PUBLISH" -eq 1 ]]; then _die "not on 'main' (on '$branch') — refusing to publish"; fi
    _info "WARN: not on 'main' (on '$branch') — dry-run only"
  fi
}

# ---- Build the clean tree (tracked HEAD content minus the exclusions) --------
_build_clean_tree() {
  local dest="$1" ex
  git archive --format=tar HEAD | tar -x -C "$dest" || _die "git archive failed"
  for ex in "${EXCLUDES[@]}"; do
    # rm the path and any prefix match (e.g. docs/security-audit-*)
    rm -rf -- "${dest:?}/${ex}" 2>/dev/null || true
    local d b; d="$(dirname "$ex")"; b="$(basename "$ex")"
    if [[ -d "$dest/$d" ]]; then
      find "$dest/$d" -maxdepth 1 -name "${b}*" -exec rm -rf -- {} + 2>/dev/null || true
    fi
  done
}

# ---- gitleaks: locate or fetch, then GATE the clean tree --------------------
GL=""
_ensure_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then GL="gitleaks"; return 0; fi
  [[ -x "$HOME/.local/bin/gitleaks" ]] && { GL="$HOME/.local/bin/gitleaks"; return 0; }
  local cache="$HOME/.cache/lnx-cli-tui-ide"
  [[ -x "$cache/gitleaks" ]] && { GL="$cache/gitleaks"; return 0; }
  command -v curl >/dev/null 2>&1 || return 1
  local tag url; tag="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest 2>/dev/null \
    | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
  [[ -z "$tag" ]] && return 1
  url="https://github.com/gitleaks/gitleaks/releases/download/v${tag}/gitleaks_${tag}_linux_x64.tar.gz"
  mkdir -p "$cache"
  curl -fsSL "$url" | tar -xz -C "$cache" gitleaks 2>/dev/null || return 1
  [[ -x "$cache/gitleaks" ]] && { GL="$cache/gitleaks"; return 0; }
  return 1
}

_gitleaks_gate() {
  local dest="$1"
  if ! _ensure_gitleaks; then
    if [[ "$DO_PUBLISH" -eq 1 ]]; then _die "gitleaks unavailable and could not be fetched — refusing to publish without the gate"; fi
    _info "WARN: gitleaks not available — gate SKIPPED (dry-run only; a real --publish would abort here)"
    return 0
  fi
  _info "gitleaks gate: scanning the clean tree with $("$GL" version 2>/dev/null || echo gitleaks)…"
  if "$GL" dir "$dest" --no-banner --redact --exit-code 1 >/tmp/lnx-snapshot-gitleaks.log 2>&1; then
    _info "gitleaks gate: PASS (no findings on the clean tree)"
  else
    _info "----- gitleaks findings (redacted) -----"; tail -20 /tmp/lnx-snapshot-gitleaks.log >&2 || true
    _die "gitleaks GATE FAILED — ABORTING publish. Investigate the finding above; nothing was pushed."
  fi
}

# ---- Publish: snapshot commit to the public remote (minimal history) --------
_publish() {
  local src="$1" work; work="$(mktemp -d)"
  if ! git clone --quiet --depth 1 "$PUBLIC_REMOTE" "$work" 2>/dev/null; then
    rm -rf "$work"; mkdir -p "$work"; git -C "$work" init --quiet
  fi
  # Replace the public worktree contents with the clean tree (keep its .git).
  rsync -a --delete --exclude '.git' "$src"/ "$work"/
  git -C "$work" add -A
  if git -C "$work" diff --cached --quiet; then
    _info "Public repo already matches this snapshot — nothing to publish."
    rm -rf "$work"; return 0
  fi
  GIT_AUTHOR_NAME="$AUTHOR_NAME" GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
  GIT_COMMITTER_NAME="$AUTHOR_NAME" GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
    git -C "$work" commit --quiet -m "$MESSAGE"
  git -C "$work" branch -M main
  git -C "$work" push --quiet -u "$PUBLIC_REMOTE" main || _die "push to public failed"
  _info "Published snapshot to: $PUBLIC_REMOTE"
  _info "Snapshot commit:"; git -C "$work" --no-pager log -1 --format='  %h  %an <%ae>  %s'
  rm -rf "$work"
}

# ---- Orchestrate ------------------------------------------------------------
_preconditions
SHORT="$(git rev-parse --short HEAD)"
[[ -z "$MESSAGE" ]] && MESSAGE="Snapshot of lnx-cli-tui-ide @ $SHORT"

DEST="$(mktemp -d)"
trap 'rm -rf "$DEST" 2>/dev/null || true' EXIT
_build_clean_tree "$DEST"

_info "=== publish-snapshot plan ==="
_info "Public remote : $PUBLIC_REMOTE"
_info "Identity      : $AUTHOR_NAME <$AUTHOR_EMAIL>"
_info "Message       : $MESSAGE"
_info "Excluded      : ${EXCLUDES[*]}  (+ gitignored logs/, *.bak.*, state/, config.env)"
_info "--- WOULD PUBLISH (clean tree) ---"
( cd "$DEST" && find . -type f | sed 's|^\./||' | sort )

_gitleaks_gate "$DEST"

# Hard guarantee: the internal coordination dir must not be in the clean tree.
[[ ! -e "$DEST/.postoffice" ]] || _die "internal .postoffice/ leaked into the clean tree — aborting"

if [[ "$DO_PUBLISH" -eq 1 ]]; then
  _info "=== PUBLISHING ==="
  _publish "$DEST"
else
  _info "=== DRY-RUN: nothing published (pass --publish to push). ==="
fi
