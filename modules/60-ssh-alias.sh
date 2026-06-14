#!/usr/bin/env bash
# modules/60-ssh-alias.sh — optional SSH alias + kitty ssh kitten config.
#
# Connection details are NOT stored in this repo. They live in a local, gitignored
# config.env (copy of config.env.example) that the user fills in per machine. If
# config.env is absent, this module SKIPS entirely — no prompt, no writes.
#
# HARD CONSTRAINT: no key material is ever written or committed. This only writes
# an ~/.ssh/config alias that *references* a local key path, and links the kitty
# ssh kitten config so terminfo travels to the remote automatically.

CONFIG_ENV="$REPO_ROOT/config.env"

if [[ ! -f "$CONFIG_ENV" ]]; then
  log_info "ssh: no config.env found — skipping SSH alias setup (copy config.env.example to config.env to enable)"
  return 0
fi

# config.env is a gitignored shell fragment defining SSH_ALIAS / SSH_HOSTNAME /
# SSH_USER and (optionally) SSH_IDENTITY / SSH_IDENTITY_CANDIDATES. Sourcing it
# (rather than parsing) lets values like "$HOME/.ssh/id_ed25519" expand naturally.
# shellcheck source=/dev/null
. "$CONFIG_ENV"

: "${SSH_ALIAS:=}"; : "${SSH_HOSTNAME:=}"; : "${SSH_USER:=}"
: "${SSH_IDENTITY:=}"; : "${SSH_IDENTITY_CANDIDATES:=}"

# SSH_IDENTITY is OPTIONAL: only the remote facts (alias/host/user) are required,
# because the key can be auto-detected from ~/.ssh below.
if [[ -z "$SSH_ALIAS" || -z "$SSH_HOSTNAME" || -z "$SSH_USER" ]]; then
  log_warn "ssh: config.env present but incomplete (need SSH_ALIAS, SSH_HOSTNAME, SSH_USER) — skipping"
  return 0
fi

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"

# _list_ssh_private_keys — print every private-key file in ~/.ssh (one per line),
# identified by its PEM/OpenSSH "BEGIN ... PRIVATE KEY" header so non-standard
# names (e.g. deploy keys without a .pub) are found too. Skips *.pub, config,
# known_hosts, authorized_keys, and our timestamped backups.
_list_ssh_private_keys() {
  local f
  [[ -d "$SSH_DIR" ]] || return 0
  for f in "$SSH_DIR"/*; do
    [[ -f "$f" ]] || continue
    case "${f##*/}" in
      *.pub|config|known_hosts|known_hosts.*|authorized_keys|*.bak.*) continue ;;
    esac
    if head -n1 "$f" 2>/dev/null | grep -q 'BEGIN .*PRIVATE KEY'; then
      printf '%s\n' "$f"
    fi
  done
}

# _discover_ssh_key — choose the best private key, in order:
#   1. names from SSH_IDENTITY_CANDIDATES (config.env), e.g. a deploy key name
#   2. standard names: id_ed25519 > id_ecdsa > id_rsa
#   3. any detected private key (first alphabetically)
_discover_ssh_key() {
  local name cand
  # shellcheck disable=SC2086  # candidate names are space-separated by design
  for name in $SSH_IDENTITY_CANDIDATES; do
    [[ -f "$SSH_DIR/$name" ]] && { printf '%s\n' "$SSH_DIR/$name"; return 0; }
  done
  for name in id_ed25519 id_ecdsa id_rsa; do
    [[ -f "$SSH_DIR/$name" ]] && { printf '%s\n' "$SSH_DIR/$name"; return 0; }
  done
  cand="$(_list_ssh_private_keys | head -n1)"
  [[ -n "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
  return 1
}

# Report which private keys exist so you can see what was detected.
_ssh_keys_found="$(_list_ssh_private_keys)"
if [[ -n "$_ssh_keys_found" ]]; then
  log_info "ssh: private keys detected in ~/.ssh:"
  while IFS= read -r _ssh_k; do log_info "ssh:   - $_ssh_k"; done <<<"$_ssh_keys_found"
else
  log_info "ssh: no private keys detected in ~/.ssh yet"
fi

# Resolve SSH_IDENTITY: an explicit config value wins; otherwise auto-detect.
if [[ -n "$SSH_IDENTITY" ]]; then
  # Expand a leading "~/" to $HOME in case a tilde was used instead of $HOME.
  # shellcheck disable=SC2088  # literal "~/" comparison, not tilde expansion
  if [[ "${SSH_IDENTITY:0:2}" == "~/" ]]; then
    SSH_IDENTITY="$HOME/${SSH_IDENTITY:2}"
  fi
  log_info "ssh: using SSH_IDENTITY from config.env: $SSH_IDENTITY"
elif SSH_IDENTITY="$(_discover_ssh_key)"; then
  log_ok "ssh: auto-detected key $SSH_IDENTITY (set SSH_IDENTITY in config.env to override)"
else
  SSH_IDENTITY="$HOME/.ssh/id_ed25519"
  log_warn "ssh: no key set or found in ~/.ssh — alias will reference $SSH_IDENTITY (create it before connecting)"
fi

# Generic marker comments — they name neither a provider nor a host, so the
# managed region is identifiable for idempotent rewrites without leaking anything.
BEGIN_MARK="# >>> lnx-cli-tui-ide managed block >>>"
END_MARK="# <<< lnx-cli-tui-ide managed block <<<"

_ssh_block() {
  cat <<EOF
$BEGIN_MARK
# Managed by lnx-cli-tui-ide. Values come from local config.env; the private key
# stays local and is never committed.
Host $SSH_ALIAS
    HostName $SSH_HOSTNAME
    User $SSH_USER
    IdentityFile $SSH_IDENTITY
    IdentitiesOnly yes
    ForwardAgent no
    ServerAliveInterval 60
$END_MARK
EOF
}

_ensure_ssh_config() {
  run mkdir -p "$SSH_DIR"
  run chmod 700 "$SSH_DIR"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "[DRY] would write the managed SSH alias block to $SSH_CONFIG:"
    _ssh_block | sed 's/^/[DRY]   /'
    return 0
  fi

  [[ -f "$SSH_CONFIG" ]] || { : >"$SSH_CONFIG"; chmod 600 "$SSH_CONFIG"; }

  # Remove any prior managed block, then append the fresh one (idempotent).
  if grep -qF "$BEGIN_MARK" "$SSH_CONFIG" 2>/dev/null; then
    log_info "ssh: refreshing existing managed block in $SSH_CONFIG"
    sed -i "/$(printf '%s' "$BEGIN_MARK" | sed 's/[\/&]/\\&/g')/,/$(printf '%s' "$END_MARK" | sed 's/[\/&]/\\&/g')/d" "$SSH_CONFIG"
  fi
  printf '\n%s\n' "$(_ssh_block)" >>"$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
  log_ok "ssh: alias '$SSH_ALIAS' -> $SSH_USER@$SSH_HOSTNAME (IdentityFile $SSH_IDENTITY)"
}

_check_key_present() {
  if [[ -f "$SSH_IDENTITY" ]]; then
    log_ok "ssh: identity present at $SSH_IDENTITY (not touched, never committed)"
  else
    log_warn "ssh: identity $SSH_IDENTITY NOT found on this machine."
    log_warn "ssh: the '$SSH_ALIAS' alias is configured but will fail until you place the key there."
    log_warn "ssh: copy your private key to $SSH_IDENTITY (chmod 600). It is never stored in this repo."
  fi
}

_link_kitten_conf() {
  # The kitty ssh kitten config makes terminfo travel to the remote so Helix,
  # lazygit, yazi, etc. render correctly over SSH. kitty.conf already includes it.
  link_dotfile "$REPO_ROOT/dotfiles/kitty/ssh.conf" "$HOME/.config/kitty/ssh.conf"
  if have kitten || have kitty; then
    log_info "ssh: kitty ssh kitten configured — use 'kitten ssh $SSH_ALIAS' to carry terminfo"
  else
    log_info "ssh: (kitty not active here; kitten ssh applies when running under kitty)"
  fi
}

_ensure_ssh_config
_check_key_present
_link_kitten_conf

log_ok "ssh-alias module done"
