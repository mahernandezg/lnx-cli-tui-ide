#!/usr/bin/env bash
# tests/test_publish_snapshot.sh — hermetic, mutation-verified suite for
# scripts/publish-snapshot.sh. Builds a throwaway git repo containing internal files
# (.postoffice/, docs/security-audit-*) and normal product files, runs the script in
# --dry-run, and asserts the clean tree EXCLUDES the internal files and INCLUDES the
# rest. Never publishes. Mutation check: dropping an exclude makes the internal file
# appear and fails the suite.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
SCRIPT="$ROOT/scripts/publish-snapshot.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

[[ -x "$SCRIPT" ]] || { echo "[FAIL] $SCRIPT not executable"; exit 1; }

R="$TMP/repo"; mkdir -p "$R/.postoffice" "$R/docs" "$R/lib"
printf '#!/usr/bin/env bash\necho hi\n' >"$R/install.sh"
printf '# lnx-cli-tui-ide\n' >"$R/README.md"
printf 'internal coordination log\n' >"$R/.postoffice/thread.md"
printf '# internal audit\n' >"$R/docs/security-audit-20260622.md"
printf '# keep me\n' >"$R/docs/keep.md"
printf '# lib\n' >"$R/lib/log.sh"
git -C "$R" init -q
git -C "$R" config user.email t@t.t
git -C "$R" config user.name t
git -C "$R" add -A
git -C "$R" commit -q -m init
git -C "$R" branch -M main

# Run the script in dry-run from inside the throwaway repo (never publishes).
out="$(cd "$R" && bash "$SCRIPT" --dry-run 2>&1)"
# Extract just the "WOULD PUBLISH" file list (between the marker and the next section).
files="$(printf '%s\n' "$out" | awk '/WOULD PUBLISH/{f=1;next} /^===|gitleaks gate:|^publish-snapshot:/{f=0} f')"

inc() { # inc <path> <desc>
  if printf '%s\n' "$files" | grep -qFx "$1"; then _pass "includes $2"; else _fail "$1 missing from snapshot"; fi
}

inc "install.sh"   "install.sh"
inc "README.md"    "README.md"
inc "docs/keep.md" "docs/keep.md"
inc "lib/log.sh"   "lib/log.sh"

if printf '%s\n' "$files" | grep -q '\.postoffice'; then _fail ".postoffice/ leaked into the snapshot"; else _pass "excludes .postoffice/"; fi
if printf '%s\n' "$files" | grep -q 'security-audit'; then _fail "security-audit report leaked into the snapshot"; else _pass "excludes docs/security-audit-*"; fi

# Dry-run must not publish: it should say so and create no commits anywhere we own.
if printf '%s\n' "$out" | grep -q 'DRY-RUN: nothing published'; then _pass "dry-run publishes nothing"; else _fail "dry-run did not confirm no-publish"; fi

printf '\ntest_publish_snapshot: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
