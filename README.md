# lnx-cli-tui-ide

One command sets up a complete, terminal-centric development environment on a clean
Debian machine — editor, AI CLIs, viewers, file manager, and Git/Docker TUIs — and
**adapts to each laptop's hardware** instead of assuming one profile. It detects the
GPU's OpenGL level, available RAM, and network, then installs the best terminal and
tool for that machine, falling back automatically when something isn't available.

## Quickstart

```bash
git clone https://github.com/mahernandezg/lnx-cli-tui-ide
cd lnx-cli-tui-ide
./install.sh
```

Convenience one-liner (documented, not the main path — review scripts before piping):

```bash
curl -fsSL https://raw.githubusercontent.com/mahernandezg/lnx-cli-tui-ide/main/install.sh | bash
```

> The clone-and-run form is preferred: it gives you the dotfiles, fixtures, and a repo to
> re-run idempotently.

## Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print exactly what would happen; change nothing. |
| `--only <module>` | Run only matching module(s). Repeatable. Match by number or name, e.g. `--only terminal`, `--only 40-helix`. |
| `--skip <module>` | Skip matching module(s). Repeatable. |
| `--with-vscodium` | Also install VSCodium (off by default; heavy Electron, emergencies only). |
| `--verbose` | Verbose/debug logging. |
| `-h`, `--help` | Usage. |

Every run writes a timestamped log to `logs/install-<timestamp>.log`.

## How the fallback engine works

Every tool declares a **primary install method and ordered fallbacks**. The engine
(`lib/fallback.sh`) tries each in turn, in an isolated subshell, and logs which path won.
A failing step **logs and continues** — it never aborts the rest of the install. Examples:

- **Terminal — hardware-adaptive.** If `glxinfo` reports **OpenGL ≥ 3.3**, install
  **kitty** (it uses the GPU; its graphics protocol is what lets euporie show inline
  plots). If the GPU can't do 3.3, fall back to **WezTerm in software-rendering mode**
  (`front_end = "Software"`), which still speaks the kitty graphics protocol.
- **kitty itself:** official installer (newer than Debian stable) → `apt` (offline / if the
  installer fails).
- **Tools Debian ships old or not at all** (helix, yazi, glow, lazygit, lazydocker):
  `apt` when recent enough → official release binary → `cargo`.
- **Nerd Font:** installed if missing, skipped if present.

Detection facts (Debian version, OpenGL, RAM, network, headless) are gathered once up
front; modules branch on them. Scrollback is sized to available RAM so old, constrained
laptops don't hoard memory.

## What gets installed (and why)

| Tool | Purpose |
|------|---------|
| **uv** | The *only* Python toolchain manager used here — no `venv` ever. Installs the Python TUIs in isolation. |
| **kitty** / **WezTerm** | Terminal. kitty when the GPU allows; WezTerm (software) as fallback. Both support the kitty graphics protocol for inline images. |
| **bat** | View code with syntax colors and a git gutter (a `bat`→`batcat` shim is added on Debian). |
| **glow** | Render Markdown in the terminal. |
| **yazi** | TUI file manager (uses the Nerd Font icons). |
| **ripgrep** | Fast recursive search. |
| **fzf** | Fuzzy finder. |
| **euporie** | View Jupyter notebooks in the terminal, **inline plots** via the kitty graphics protocol. Installed with `uv tool install`. |
| **Helix** | Modal editor. LSP: **vtsls** (TypeScript, the ARAYA monorepo), **ruff** (Python). **basedpyright** is configured but **disabled by default** to save RAM. |
| **lazygit** | Git TUI. |
| **lazydocker** | Docker TUI. |
| **Starship** | Two-line cross-shell prompt (info on line 1, input caret on line 2; git + node/python/rust + docker context). Activation (`eval "$(starship init bash)"`) is written to `~/.bashrc` **idempotently** via a managed marker, so re-runs never duplicate it. |
| **VSCodium** | Heavy Electron fallback editor — only with `--with-vscodium`. |

Daily multiplexing uses **kitty tabs, windows, and layouts**. **tmux is not installed by
default** — it's an optional add-on (`sudo apt install tmux`).

## SSH alias — keys and host details stay local

The installer can configure an SSH alias and the kitty ssh kitten, but **no connection
details and no key material live in this repo**. Host, user, and key path come from a
local, gitignored `config.env` that you create from the committed `config.env.example`:

```bash
cp config.env.example config.env
# then edit config.env with your real values:
#   SSH_ALIAS="myhost"
#   SSH_HOSTNAME="host.example.com"
#   SSH_USER="myuser"
#   SSH_IDENTITY="$HOME/.ssh/id_ed25519"
```

On the next run, `modules/60-ssh-alias.sh` reads `config.env` and writes a managed block to
`~/.ssh/config`:

```
# >>> lnx-cli-tui-ide managed block >>>
Host myhost
    HostName host.example.com
    User myuser
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
# <<< lnx-cli-tui-ide managed block <<<
```

**If `config.env` does not exist, the SSH module is skipped entirely** (no prompt, no
writes). The private key **must already exist locally** at the `SSH_IDENTITY` path (chmod
600); if it's missing, the installer warns and still writes the alias. The kitty ssh kitten
(`kitten ssh <your-alias>`) carries terminfo to the remote so Helix, lazygit, and yazi
render correctly. **No SSH keys and no host details are ever committed to this repo.**

## Idempotency, dotfiles, and backups

- Re-running detects what's already done and **skips it**.
- Dotfiles are **symlinked** from `dotfiles/` into `~/.config` (bash-only, no GNU Stow).
- Any pre-existing real config at a target is **backed up** to `<file>.bak.<timestamp>`
  before linking — nothing is silently overwritten.
- Per-machine values (e.g. RAM-sized scrollback) are written to `local.conf` / `local.lua`,
  which are git-ignored and never committed.

## Validation

`tests/validate.sh` (also run at the end of `install.sh`) checks the four cases that
motivated the setup, on the machine it runs on, and reports PASS/FAIL per case:

1. Markdown renders with **glow**.
2. Code shows syntax colors with **bat**.
3. A sample notebook opens in **euporie** with the inline-plot stack verified.
4. **Helix** opens and its LSP attaches (vtsls + ruff).

Run it any time:

```bash
./tests/validate.sh
```

## Repository layout

```
install.sh            entrypoint: flags, detection, module dispatch, validation
lib/                  log.sh detect.sh fallback.sh symlink.sh apt.sh
modules/              00-uv 10-terminal 20-viewers 30-euporie 40-helix
                      50-git-docker-tui 60-ssh-alias 70-starship 90-vscodium (gated)
dotfiles/             kitty/ helix/ wezterm/ starship/
tests/                validate.sh + sample.md / sample.py / sample.ipynb
```

## Author

[Manuel Hernández Giuliani](https://github.com/mahernandezg) (GitHub:
[`mahernandezg`](https://github.com/mahernandezg)).

## License

[MIT](LICENSE).
