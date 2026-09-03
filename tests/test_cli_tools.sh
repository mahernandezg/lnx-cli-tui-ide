#!/usr/bin/env bash
# Hermetic, mutation-sensitive test for the P53 apt-native CLI/TUI inventory.
set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" 2>/dev/null || true' EXIT
PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
chk() { if [[ "$2" == "$3" ]]; then _pass "$1"; else _fail "$1 (got '$2' want '$3')"; fi; }
status_of() { awk -F '\t' -v p="$2" '$2==p {print $1; exit}' "$1"; }

PACKAGES=(
  adb btop fastfetch gh git git-lfs htop hwinfo iftop inxi iotop jq lsof ncdu
  nvme-cli nvtop powertop procps shellcheck smartmontools strace thefuck
  traceroute tree yq
)
COMMANDS=(
  adb btop fastfetch gh git git-lfs htop hwinfo iftop inxi iotop jq lsof ncdu
  nvme nvtop powertop top shellcheck smartctl strace thefuck traceroute tree yq
)

seed_commands() {
  local dir="$1" cmd
  mkdir -p "$dir"
  for cmd in "${COMMANDS[@]}"; do printf '#!/bin/sh\nexit 0\n' >"$dir/$cmd"; chmod +x "$dir/$cmd"; done
}

run_module() { # <dir> <dry> <seed:0|1> [skip-created-package]
  local dir="$1" dry="$2" seed="$3" skip_pkg="${4:-}"
  mkdir -p "$dir/bin" "$dir/home"; : >"$dir/ledger"
  [[ "$seed" == '1' ]] && seed_commands "$dir/bin"
  TEST_BIN="$dir/bin" TEST_APT_LOG="$dir/apt.log" TEST_SKIP_PKG="$skip_pkg" \
  HOME="$dir/home" DRY_RUN="$dry" VERBOSE=0 REPO_ROOT="$ROOT" LOG_DIR="$dir/logs" \
  OUTCOME_FILE="$dir/ledger" bash -c '
    set -uo pipefail
    . "$REPO_ROOT/lib/log.sh"; . "$REPO_ROOT/lib/outcome.sh"
    have() { [[ -x "$TEST_BIN/$1" ]]; }
    apt_can_use() { return 0; }
    apt_install() {
      printf "%s\n" "$*" >"$TEST_APT_LOG"
      local pkg cmd
      for pkg in "$@"; do
        [[ "$pkg" == "$TEST_SKIP_PKG" ]] && continue
        case "$pkg" in
          nvme-cli) cmd=nvme ;; procps) cmd=top ;; smartmontools) cmd=smartctl ;;
          *) cmd="$pkg" ;;
        esac
        printf "#!/bin/sh\\nexit 0\\n" >"$TEST_BIN/$cmd"; chmod +x "$TEST_BIN/$cmd"
      done
    }
    . "$REPO_ROOT/modules/25-cli-tools.sh"
  ' >"$dir/out" 2>&1
}

# A: present set is verified and apt is untouched.
run_module "$TMP/a" 0 1
for pkg in "${PACKAGES[@]}"; do chk "A: $pkg PRESENT" "$(status_of "$TMP/a/ledger" "$pkg")" 'PRESENT'; done
if [[ ! -e "$TMP/a/apt.log" ]]; then _pass 'A: apt skipped for complete P53 set'; else _fail 'A: apt called for complete set'; fi

# B: dry-run reports every missing package and performs no install.
run_module "$TMP/b" 1 0
chk 'B: dry-run prints exact package order' "$(grep -o 'P53 CLI/TUI packages: .*' "$TMP/b/out" | head -1)" "P53 CLI/TUI packages: ${PACKAGES[*]}"
for pkg in "${PACKAGES[@]}"; do chk "B: $pkg NOTE in dry-run" "$(status_of "$TMP/b/ledger" "$pkg")" 'NOTE'; done
if [[ ! -e "$TMP/b/apt.log" ]]; then _pass 'B: dry-run did not call apt'; else _fail 'B: dry-run called apt'; fi

# C: apt success is followed by command verification; one omitted command fails.
run_module "$TMP/c" 0 0 nvtop
chk 'C: apt receives exact missing set' "$(<"$TMP/c/apt.log")" "${PACKAGES[*]}"
chk 'C: verified tool becomes INSTALLED' "$(status_of "$TMP/c/ledger" btop)" 'INSTALLED'
chk 'C: false apt success cannot mask absent command' "$(status_of "$TMP/c/ledger" nvtop)" 'FAILED'

printf '\ntest_cli_tools: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
