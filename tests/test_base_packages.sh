#!/usr/bin/env bash
# Hermetic regression test for modules/00-base-packages.sh.
# Mutation bite: removing a package from _BASE_PACKAGES, skipping apt_install, or
# trusting apt without verification makes the package/status assertions fail.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
chk() { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }

status_of() { awk -F '\t' -v p="$2" '$2==p {print $1; exit}' "$1"; }

_run() { # <case-dir> <dry> <seed-present:0|1> <apt-succeeds:0|1> [skip-created-pkg]
  local dir="$1" dry="$2" seed="$3" apt_ok="$4" skip_pkg="${5:-}"
  mkdir -p "$dir/bin" "$dir/state" "$dir/home"
  : >"$dir/ledger"
  if [[ "$seed" == "1" ]]; then
    touch "$dir/state/ca-certificates"
    for cmd in curl wget wl-copy wl-paste; do
      printf '#!/bin/sh\nexit 0\n' >"$dir/bin/$cmd"; chmod +x "$dir/bin/$cmd"
    done
  fi
  cat >"$dir/bin/dpkg-query" <<'SH'
#!/bin/sh
for pkg do :; done
[ -f "$TEST_STATE/$pkg" ] && { printf 'install ok installed'; exit 0; }
exit 1
SH
  chmod +x "$dir/bin/dpkg-query"

  PATH="$dir/bin:$PATH" TEST_BIN="$dir/bin" TEST_STATE="$dir/state" TEST_APT_LOG="$dir/apt.log" \
  TEST_APT_OK="$apt_ok" TEST_SKIP_PKG="$skip_pkg" HOME="$dir/home" DRY_RUN="$dry" VERBOSE=0 \
  REPO_ROOT="$ROOT" LOG_DIR="$dir/logs" OUTCOME_FILE="$dir/ledger" bash -c '
    set -uo pipefail
    . "$REPO_ROOT/lib/log.sh"
    . "$REPO_ROOT/lib/outcome.sh"
    have() { [[ -x "$TEST_BIN/$1" ]]; }
    apt_can_use() { return 0; }
    apt_install() {
      printf "%s\n" "$*" >"$TEST_APT_LOG"
      [[ "$TEST_APT_OK" == "1" ]] || return 1
      local pkg cmd
      for pkg in "$@"; do
        [[ "$pkg" == "$TEST_SKIP_PKG" ]] && continue
        touch "$TEST_STATE/$pkg"
        case "$pkg" in
          curl|wget) cmd="$pkg"; printf "#!/bin/sh\\nexit 0\\n" >"$TEST_BIN/$cmd"; chmod +x "$TEST_BIN/$cmd" ;;
          wl-clipboard)
            for cmd in wl-copy wl-paste; do printf "#!/bin/sh\\nexit 0\\n" >"$TEST_BIN/$cmd"; chmod +x "$TEST_BIN/$cmd"; done ;;
        esac
      done
    }
    . "$REPO_ROOT/modules/00-base-packages.sh"
  ' >"$dir/out" 2>&1
}

PACKAGES=(curl wget ca-certificates wl-clipboard)

# A: all present => verified PRESENT, apt untouched.
_run "$TMP/a" 0 1 1
for pkg in "${PACKAGES[@]}"; do
  chk "A: $pkg verified PRESENT" "$(status_of "$TMP/a/ledger" "$pkg")" "PRESENT"
done
if [[ ! -e "$TMP/a/apt.log" ]]; then _pass "A: apt not called when all dependencies exist"; else _fail "A: apt called unnecessarily"; fi

# B: dry-run => exact missing set reported, no apt call or filesystem install.
_run "$TMP/b" 1 0 1
for pkg in "${PACKAGES[@]}"; do
  chk "B: $pkg reported NOTE in dry-run" "$(status_of "$TMP/b/ledger" "$pkg")" "NOTE"
done
if [[ ! -e "$TMP/b/apt.log" ]]; then _pass "B: dry-run did not invoke apt"; else _fail "B: dry-run invoked apt"; fi

# C: successful apt path => exact package set and post-install verification.
_run "$TMP/c" 0 0 1
chk "C: apt receives exact base package set" "$(<"$TMP/c/apt.log")" "curl wget ca-certificates wl-clipboard"
for pkg in "${PACKAGES[@]}"; do
  chk "C: $pkg INSTALLED only after verification" "$(status_of "$TMP/c/ledger" "$pkg")" "INSTALLED"
done

# D: apt says success but wget remains absent => FAILED, proving verification bites.
_run "$TMP/d" 0 0 1 wget
chk "D: false apt success cannot mask missing wget" "$(status_of "$TMP/d/ledger" wget)" "FAILED"

printf '\ntest_base_packages: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
