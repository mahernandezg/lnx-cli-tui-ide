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
# SSH_USER / SSH_IDENTITY. Sourcing it (rather than parsing) lets values like
# "$HOME/.ssh/id_ed25519" expand naturally.
# shellcheck source=/dev/null
. "$CONFIG_ENV"

: "${SSH_ALIAS:=}"; : "${SSH_HOSTNAME:=}"; : "${SSH_USER:=}"; : "${SSH_IDENTITY:=}"
if [[ -z "$SSH_ALIAS" || -z "$SSH_HOSTNAME" || -z "$SSH_USER" || -z "$SSH_IDENTITY" ]]; then
  log_warn "ssh: config.env present but incomplete (need SSH_ALIAS, SSH_HOSTNAME, SSH_USER, SSH_IDENTITY) — skipping"
  return 0
fi

# Expand a leading "~/" to $HOME in case the user wrote a tilde instead of $HOME.
# (Literal first-two-character comparison; no tilde expansion is intended here.)
# shellcheck disable=SC2088  # comparing to the literal string "~/", not expanding it
if [[ "${SSH_IDENTITY:0:2}" == "~/" ]]; then
  SSH_IDENTITY="$HOME/${SSH_IDENTITY:2}"
fi

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"

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
