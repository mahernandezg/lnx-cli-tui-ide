# lnx-cli-tui-ide

One command sets up a complete, **terminal-centric** development environment on a clean
Debian machine — terminal, editor, file manager, viewers, Git/Docker TUIs, and a fast
prompt — and **adapts to each laptop's hardware** instead of assuming one profile. It
detects the GPU's OpenGL level, available RAM, and network, then installs the best tool
for that machine and falls back automatically when something isn't available.

The philosophy: **live in the terminal.** Edit with Helix, manage files with yazi, read
code with bat, render Markdown with glow, drive Git/Docker with lazygit/lazydocker, view
notebooks with euporie, and multiplex with kitty's own tabs/splits (no tmux). The desktop
is only a fallback.

---

## Table of contents

1. [Step-by-step: first install](#1-step-by-step-first-install)
2. [Command-line flags](#2-command-line-flags)
3. [Daily use — every tool explained](#3-daily-use--every-tool-explained)
4. [The Starship prompt](#4-the-starship-prompt)
5. [kitty: tabs, splits & layouts (your multiplexer)](#5-kitty-tabs-splits--layouts-your-multiplexer)
6. [SSH alias — keys & host details stay local](#6-ssh-alias--keys--host-details-stay-local)
7. [How the fallback engine works](#7-how-the-fallback-engine-works)
8. [Idempotency, dotfiles & backups](#8-idempotency-dotfiles--backups)
9. [Validation](#9-validation)
10. [Troubleshooting](#10-troubleshooting)
11. [Development / tests](#11-development--tests)
12. [Repository layout](#12-repository-layout)

---

## 1. Step-by-step: first install

> Run this from a **permanent** directory — the dotfiles are *symlinked from the repo*, so
> if you delete the folder later the symlinks break. `~/.local/share/…` is a good home.

**Step 1 — Clone into a permanent location**
```bash
mkdir -p ~/.local/share
git clone https://github.com/mahernandezg/lnx-cli-tui-ide ~/.local/share/lnx-cli-tui-ide
cd ~/.local/share/lnx-cli-tui-ide
```

**Step 2 — (Optional) Configure your SSH alias**
Only if you want the installer to set up an `ssh`/`kitten ssh` alias. Nothing here is
committed — `config.env` is git-ignored.
```bash
cp config.env.example config.env
$EDITOR config.env          # or: nano config.env
```
Fill in your real values (the key path is optional — it's auto-detected from `~/.ssh` if
omitted):
```bash
SSH_ALIAS="myhost"
SSH_HOSTNAME="host.example.com"
SSH_USER="myuser"
#SSH_IDENTITY="$HOME/.ssh/id_ed25519"   # optional; auto-detected if left commented
```
If you skip this step, the SSH module is simply skipped — no prompt, no writes.

**Step 3 — Preview what will happen (recommended, changes nothing)**
```bash
./install.sh --dry-run --verbose
```
Read the output: it shows the hardware it detected, which install method each tool will
use, the dotfiles it will symlink, and the exact `~/.bashrc` line it would add.

**Step 4 — Run the real install**
```bash
./install.sh
```
It will ask for your `sudo` password (needed for the `apt`-based steps). Each tool installs
via its best available method; a failing step **logs and continues** instead of aborting.
Cautious? Install in stages: `./install.sh --only viewers`, then `--only terminal`, etc.

> **Trust note:** as *fallbacks*, a few tools may install via their official one-line
> installers — uv (`astral.sh`), kitty (`sw.kovidgoyal.net`), starship (`starship.rs`) —
> which pipe a script from the tool's own HTTPS source into a shell. That runs remote code
> from those upstreams; if you'd rather not, install those tools yourself first (they'll be
> detected and skipped) or use `apt` where available. All other downloads are release
> binaries fetched over HTTPS from each project's official GitHub org.

**Step 5 — Open a new terminal**
Reload your shell so the new prompt and `PATH` take effect:
```bash
exec bash        # or just open a new kitty window/tab
```
You should now see the two-line **Starship** prompt.

**Step 6 — Confirm everything works**
```bash
./tests/validate.sh
```
This reports PASS/FAIL for the four things that motivate the whole setup (glow, bat,
euporie, Helix+LSP). Re-running `./install.sh` any time is safe — it's idempotent.

**Step 7 — Start using your tools.** Each app is launched by typing its command. See
[§3](#3-daily-use--every-tool-explained) for the exact command, what you'll see, and how to
quit each one — for example, open the editor with **`hx`** (not `helix`).

---

## 2. Command-line flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print exactly what would happen; change nothing. **Always safe to run first.** |
| `--only <module>` | Run only matching module(s). Repeatable. Match by number or name, e.g. `--only terminal`, `--only 40-helix`. |
| `--skip <module>` | Skip matching module(s). Repeatable. |
| `--with-vscodium` | Also install VSCodium (off by default; heavy Electron, emergencies only). |
| `--verbose` | Verbose/debug logging. |
| `-h`, `--help` | Usage. |

Module names: `00-uv 10-terminal 20-viewers 30-euporie 40-helix 50-git-docker-tui
60-ssh-alias 70-starship 90-vscodium`. Every run writes a timestamped log to
`logs/install-<timestamp>.log`.

---

## 3. Daily use — every tool explained

After the install finishes, you use each tool by **typing its command into the terminal and
pressing Enter.** The command name is not always the tool's name — for example **Helix is
launched with `hx`, not `helix`** (typing `helix` gives `command not found`).

### Quick cheat sheet — what to type, and how to quit

| Tool | Type this and press Enter | What happens | How to quit it |
|------|---------------------------|--------------|----------------|
| **Helix** (editor) | `hx` *(not `helix`)* — or `hx file.py`, or `hx .` | opens the editor | press `Esc`, type `:q`, Enter |
| **yazi** (files) | `yazi` | opens the file manager | press `q` |
| **euporie** (notebooks) | `euporie notebook file.ipynb` | opens the notebook | press `Ctrl+q` |
| **lazygit** (git) | `lazygit` *(inside a git repo)* | opens the Git UI | press `q` |
| **lazydocker** (docker) | `lazydocker` | opens the Docker UI | press `q` |
| **bat** (read code) | `bat file.py` | prints the file in color | `q` if it scrolls; else nothing |
| **glow** (read Markdown) | `glow README.md` | prints rendered Markdown | `q` if you used `glow -p` |
| **ripgrep** (search) | `rg "text"` | prints matches | (returns on its own) |
| **fzf** (fuzzy pick) | `rg --files \| fzf` | interactive picker | `Esc` to cancel |
| **uv** (Python) | `uv --version`, `uv tool list` | runs a command | (returns on its own) |
| **starship** (prompt) | *(nothing — it's your prompt)* | shows the two-line prompt | — |

> **Golden rule for any full-screen tool (TUI):** if you get stuck, try `q`, then `Esc`,
> then `Ctrl+q`, and as a last resort `Ctrl+c`. One of those exits.

Below, each tool in detail: **what it is**, **why it's here (the advantage)**, and **how to
use it** — including the exact command to start it.

### uv — the Python toolchain · [📖 Docs](https://docs.astral.sh/uv/)
- **What:** an extremely fast Python package/tool manager (replaces `pip` + `venv` +
  `pipx`).
- **Advantage:** isolated, reproducible, and fast. This repo uses **uv for all Python** —
  never `venv`. Tools like euporie install in their own sandbox and never pollute a global
  environment.
- **How:**
  ```bash
  uv tool install ruff           # install a CLI tool in isolation
  uv tool list                   # see installed tools
  uv run --with rich python      # ephemeral env with a package, no install
  uv venv && source .venv/bin/activate   # a project venv, the uv way
  uv self update                 # keep uv current
  ```

### kitty / WezTerm — the terminal · [📖 kitty](https://sw.kovidgoyal.net/kitty/) · [📖 WezTerm](https://wezterm.org/)
- **What:** a GPU-accelerated terminal (kitty), or WezTerm in software-rendering mode on
  GPUs that can't do OpenGL 3.3.
- **Advantage:** the **kitty graphics protocol** lets images and notebook plots render
  *inline* in the terminal — that's why euporie and yazi can show pictures. Plus built-in
  tabs/splits so you don't need tmux.
- **How:** see [§5](#5-kitty-tabs-splits--layouts-your-multiplexer) for the keybindings.
  Quick wins:
  ```bash
  kitten icat image.png          # display an image inline
  kitten ssh myhost              # SSH carrying terminfo so remote TUIs render right
  ```

### bat — a better `cat` · [📖 Docs](https://github.com/sharkdp/bat)
- **What:** `cat` with syntax highlighting, line numbers, and a Git change gutter.
- **Advantage:** read code in color without opening an editor; integrates with a pager.
- **How:** (on Debian the binary is `batcat`; the installer adds a `bat` shim)
  ```bash
  bat src/app.ts                 # syntax + line numbers + git gutter
  bat -p file.py                 # plain (no decorations), good for piping
  rg -l TODO | xargs bat         # view every file that matched
  ```

### glow — rendered Markdown · [📖 Docs](https://github.com/charmbracelet/glow)
- **What:** a Markdown renderer for the terminal (headings, lists, code blocks, tables).
- **Advantage:** read READMEs and docs *formatted*, without a browser.
- **How:**
  ```bash
  glow README.md                 # render a file
  glow -p README.md              # render in a scrollable pager
  glow .                         # browse all Markdown in this directory
  ```

### yazi — the file manager · [📖 Docs](https://yazi-rs.github.io/docs/quick-start)
- **What:** a fast (Rust) TUI file manager with image/preview support.
- **Advantage:** navigate, preview (including images via the kitty protocol), and do bulk
  file ops far faster than `cd`/`ls`/`mv`.
- **How:** launch with `yazi`. Core keys:
  | Key | Action | Key | Action |
  |-----|--------|-----|--------|
  | `h` `j` `k` `l` | move (parent/down/up/enter) | `y` / `x` / `p` | copy / cut / paste |
  | `Enter` | open | `d` | delete (to trash) |
  | `Space` | toggle selection | `a` / `r` | create / rename |
  | `/` | filter, `s` search | `.` | toggle hidden files |
  | `q` | quit | `~` | help |

### ripgrep (`rg`) — search · [📖 Docs](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md)
- **What:** a recursive code search tool.
- **Advantage:** extremely fast and respects `.gitignore` by default (no noise from
  `node_modules`).
- **How:**
  ```bash
  rg "useEffect"                 # search recursively
  rg -i todo                     # case-insensitive
  rg -tpy "def main"             # only Python files
  rg -l "ApiError"               # list matching files only
  rg -A3 -B1 "throw new"         # show context lines
  ```

### fzf — fuzzy finder · [📖 Docs](https://github.com/junegunn/fzf#usage)
- **What:** an interactive fuzzy filter for any list.
- **Advantage:** pick a file/branch/line interactively instead of typing exact names.
- **How:**
  ```bash
  hx "$(rg --files | fzf)"       # fuzzy-pick a file and open it in Helix
  git switch "$(git branch --format='%(refname:short)' | fzf)"
  ```
  To get the shell keybindings (`Ctrl-R` history, `Ctrl-T` files, `Alt-C` cd), add this to
  `~/.bashrc`: `eval "$(fzf --bash)"`.

### euporie — Jupyter notebooks in the terminal · [📖 Docs](https://euporie.readthedocs.io/)
- **What:** a TUI for viewing and running `.ipynb` notebooks, with **inline plots** via the
  kitty graphics protocol.
- **Advantage:** open notebooks (and see matplotlib figures) without a browser or Jupyter
  server. Installed in isolation via `uv tool`.
- **How:**
  ```bash
  euporie notebook analysis.ipynb   # interactive TUI (run cells, see plots)
  euporie preview analysis.ipynb    # non-interactive dump to the terminal
  euporie console                   # a notebook-style REPL
  ```
  Inside the notebook: `Shift+Enter` runs the selected cell; **quit with `Ctrl+q`.**

### Helix (`hx`) — the editor · [📖 Docs](https://docs.helix-editor.com/) · [keymap](https://docs.helix-editor.com/keymap.html)
- **What:** a modal text editor with **built-in LSP** (no plugin setup). Pre-wired here with
  **[vtsls](https://github.com/yioneko/vtsls)** (TypeScript) and
  **[ruff](https://docs.astral.sh/ruff/)** (Python).
  [`basedpyright`](https://docs.basedpyright.com/) is installed but **off by default** to
  save RAM — enable it per project when you need types.
- **Advantage:** selection-first editing, multiple cursors, tree-sitter highlighting, and
  language servers that "just work" out of the box.
- **Start it:** the command is **`hx`** (not `helix`):
  ```bash
  hx              # open an empty editor
  hx app.ts       # open a file
  hx .            # open a file picker for the current folder
  ```
- **First time — it's *modal*, so this trips everyone up:** when Helix opens you're in
  **NORMAL** mode and typing letters runs commands, it does **not** insert text. To actually
  type, press **`i`** (insert mode); press **`Esc`** to go back to NORMAL mode.
  - **Save:** `Esc`, then `:w`, Enter.
  - **Quit:** `Esc`, then `:q`, Enter. (`:q!` quits without saving; `:wq` saves and quits.)
  - **Open another file:** `Space` then `f` (file picker).
- **Essential keys** (press `Esc` first to be in NORMAL mode):
  | Key | Action | Key | Action |
  |-----|--------|-----|--------|
  | `Space` `f` | file picker | `gd` | go to definition |
  | `Space` `b` | buffer picker | `gr` | find references |
  | `Space` `/` | search in workspace | `Space` `k` | hover docs |
  | `Space` `a` | code action | `Space` `r` | rename symbol |
  | `:w` `:q` | save / quit | `:lsp-restart` | restart the LSP |
  | `g` `g` / `G` | top / bottom | `Space` `s` | symbol picker |

  **Long commands → Helix:** with `EDITOR=hx` set (the installer adds it), press
  **`Ctrl-X Ctrl-E`** at the bash prompt to edit a long command in Helix, then save+quit to
  run it.
  **Enable types per project:** drop a `.helix/languages.toml` in the repo adding
  `"basedpyright"` to the Python `language-servers` list.

### lazygit — Git TUI · [📖 Docs](https://github.com/jesseduffield/lazygit)
- **What:** a full-screen UI for Git.
- **Advantage:** stage hunks, craft commits, manage branches, rebase, and resolve conflicts
  visually — far faster than raw `git` for everyday work.
- **How:** run `lazygit` inside a repo. Common keys: `Space` stage/unstage · `c` commit ·
  `P` push · `p` pull · `b` branch menu · `Enter` to drill into files/hunks · `?` help ·
  **`q` to quit.**

### lazydocker — Docker TUI · [📖 Docs](https://github.com/jesseduffield/lazydocker)
- **What:** a dashboard for Docker containers, images, volumes, and logs.
- **Advantage:** watch logs, restart containers, prune, and inspect resources without
  memorizing `docker` flags.
- **How:** run `lazydocker` (needs the Docker engine running to be useful). Navigate panels
  with the arrow keys; **`q` to quit.**

### Starship — the prompt · [📖 Docs](https://starship.rs/config/)
- **What:** a fast, informative two-line shell prompt. See [§4](#4-the-starship-prompt).
- **Advantage:** shows directory, Git state, and language versions at a glance, while
  staying fast even in huge repos (tuned timeouts).

### VSCodium — emergency GUI editor (opt-in) · [📖 Docs](https://vscodium.com/)
- **What:** a telemetry-free build of VS Code. **Not installed by default.**
- **Advantage:** a fallback for the rare task that genuinely needs a GUI editor.
- **How:** install with `./install.sh --with-vscodium`, then launch with `codium .`.

### All official documentation, in one place

| Tool | Command | Official documentation |
|------|---------|------------------------|
| uv | `uv` | https://docs.astral.sh/uv/ |
| kitty | `kitty` / `kitten` | https://sw.kovidgoyal.net/kitty/ |
| WezTerm | `wezterm` | https://wezterm.org/ |
| bat | `bat` | https://github.com/sharkdp/bat |
| glow | `glow` | https://github.com/charmbracelet/glow |
| yazi | `yazi` | https://yazi-rs.github.io/docs/quick-start |
| ripgrep | `rg` | https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md |
| fzf | `fzf` | https://github.com/junegunn/fzf#usage |
| euporie | `euporie` | https://euporie.readthedocs.io/ |
| Helix | `hx` | https://docs.helix-editor.com/ · [keymap](https://docs.helix-editor.com/keymap.html) |
| ↳ vtsls (TS LSP) | — | https://github.com/yioneko/vtsls |
| ↳ ruff (Py LSP) | `ruff` | https://docs.astral.sh/ruff/ |
| ↳ basedpyright | `basedpyright` | https://docs.basedpyright.com/ |
| lazygit | `lazygit` | https://github.com/jesseduffield/lazygit |
| lazydocker | `lazydocker` | https://github.com/jesseduffield/lazydocker |
| Starship | *(your prompt)* | https://starship.rs/config/ |
| VSCodium | `codium` | https://vscodium.com/ |

---

## 4. The Starship prompt

A **two-line** prompt: information on line 1, a clean caret on line 2 so your commands
always start at the same place.

```
~/code/web-app  main !2 ?1   v20.11.0   3.12.2
❯ 
```

Line 1 segments (each appears only when relevant):
- **directory** — current path (truncated to the repo root).
- **git branch** + **git status** — branch name and a compact change summary
  (`!` modified, `+` staged, `?` untracked, `⇡`/`⇣` ahead/behind…).
- **language versions** — Node/TypeScript, Python, Rust, and the Docker context, shown only
  in projects that use them.

Line 2 is just the caret `❯` (green on success, red after a failed command). It's tuned for
speed (`command_timeout`, an explicit module list) so it stays responsive in large repos
like a big TypeScript monorepo. Activation is added to `~/.bashrc` **once**, guarded so it never
errors if `starship` isn't installed and never duplicates on re-runs.

---

## 5. kitty: tabs, splits & layouts (your multiplexer)

kitty's own windows/tabs/layouts replace tmux for daily use (tmux is **not** installed; add
it yourself with `sudo apt install tmux` if you want it).

| Keys | Action |
|------|--------|
| `Ctrl+Shift+Enter` | new split (window) in the current tab |
| `Ctrl+Shift+T` | new tab |
| `Ctrl+Shift+]` / `Ctrl+Shift+[` | focus next / previous split |
| `Ctrl+Shift+L` | cycle layout (splits → stack → tall → fat → grid) |
| `Ctrl+Shift+W` | close the current split |
| `Ctrl+Shift+H` | open scrollback in the pager |
| `Ctrl+Shift+=` / `Ctrl+Shift+-` | font size up / down |

Scrollback is sized to your RAM automatically (more RAM → longer history), so long AI-CLI
output stays reachable.

---

## 6. SSH alias — keys & host details stay local

The installer can configure an SSH alias and the kitty ssh kitten, but **no connection
details and no key material live in this repo**. Host, user, and key path come from a
local, git-ignored `config.env` (created in [Step 2](#1-step-by-step-first-install)).

On install, `modules/60-ssh-alias.sh` reads `config.env`, **auto-detects your key** from
`~/.ssh` if `SSH_IDENTITY` is unset, and writes a managed block to `~/.ssh/config`:

```
# >>> lnx-cli-tui-ide managed block >>>
Host myhost
    HostName host.example.com
    User myuser
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
# <<< lnx-cli-tui-ide managed block <<<
```

Then connect with terminfo carried to the remote (so Helix/lazygit/yazi render correctly):
```bash
kitten ssh myhost      # preferred, from kitty
ssh myhost             # plain ssh also works via ~/.ssh/config
```

The private key **must already exist locally** at the `SSH_IDENTITY` path (`chmod 600`); if
it's missing the installer warns and still writes the alias. **No SSH keys and no host
details are ever committed to this repo.** If `config.env` doesn't exist, the SSH module is
skipped entirely.

---

## 7. How the fallback engine works

Every tool declares a **primary install method and ordered fallbacks**. The engine
(`lib/fallback.sh`) tries each in turn, in an isolated subshell, logs which path won, and
**continues on failure** instead of aborting. Examples:

- **Terminal — hardware-adaptive.** OpenGL ≥ 3.3 → **kitty** (GPU); otherwise → **WezTerm**
  in software-rendering mode — both speak the kitty graphics protocol.
- **kitty:** official installer (newer than Debian stable) → `apt` (offline / if it fails).
- **Release tools** (yazi, Helix, lazygit, lazydocker, Starship): the **latest stable**
  release is resolved at runtime from GitHub — **no pinned versions** — with `apt`/`cargo`
  as fallbacks.
- **Nerd Font:** installed if missing, skipped if present.

Detection facts (Debian version, OpenGL, RAM, network, headless) are gathered once up front;
modules branch on them.

---

## 8. Idempotency, dotfiles & backups

- Re-running detects what's already done and **skips it** — safe to run repeatedly.
- Dotfiles are **symlinked** from `dotfiles/` into `~/.config` (bash-only, no GNU Stow).
- Any pre-existing real config at a target is **backed up** to `<file>.bak.<timestamp>`
  before linking — nothing is silently overwritten.
- Edits to `~/.bashrc` (Starship activation, `EDITOR`/`VISUAL=hx`) live in clearly marked
  `# >>> lnx-cli-tui-ide: … >>>` blocks and are written **once**.
- Per-machine values (RAM-sized scrollback) go to `local.conf` / `local.lua`, which are
  git-ignored.

---

## 9. Validation

`tests/validate.sh` (also the last step of `install.sh`) checks the four motivating cases
on the current machine and reports PASS/FAIL per case. It is fully non-interactive and
timeout-guarded, so it can never hang an unattended run.

1. Markdown renders with **glow**.
2. Code shows syntax colors with **bat**.
3. A sample notebook loads in **euporie** and the inline-plot stack works.
4. **Helix** opens and its LSPs are available (vtsls + ruff).

```bash
./tests/validate.sh
```

---

## 10. Troubleshooting

- **`command not found` for a tool you just installed.** Two usual causes: (1) the command
  name differs from the tool name — most notably **Helix is `hx`, not `helix`** (see the
  cheat sheet in [§3](#3-daily-use--every-tool-explained)); (2) the new install dir isn't on
  your `PATH` yet in this shell — **open a new terminal** (or run `exec bash`) and try again.
- **The prompt looks wrong / broken after install.** Your previous `~/.bashrc` is backed up.
  Restore it with `cp ~/.bashrc.bak.<timestamp> ~/.bashrc` and open a new shell.
- **A tool didn't install.** It's non-fatal — check the log at `logs/install-<timestamp>.log`
  for the method that failed, fix the cause (often network), and re-run `./install.sh` (it
  skips what's already done).
- **Offline machine.** Network-based methods are skipped automatically and fall back to
  `apt`/cached paths; the run still completes.
- **`starship: command not found` in a shell.** Harmless — the activation line is guarded;
  it just means starship isn't on `PATH` yet. Re-run the installer or open a new shell after
  `~/.local/bin` is on `PATH`.
- **Re-running is always safe.** The installer is idempotent and backs up before changing
  anything.

---

## 11. Development / tests

Run the test suite locally:

```bash
./tests/run.sh
```

It runs:
- **shellcheck** (hard gate when installed) — static analysis of every script.
- **`tests/test_sete.sh`** (hard gate) — a hermetic regression suite for the `set -e`
  abort bug class. It sources `lib/*.sh` with `DRY_RUN=0` under `set -euo pipefail` and
  asserts `log_init`, `run_detection`, and the detection helpers return 0 / degrade safely
  (offline, empty parses) instead of aborting — the failure mode `--dry-run` cannot catch.
  It uses PATH shims (offline `curl`/`wget`, empty `glxinfo`, inert `apt`/`uv`/`npm`), so it
  **downloads and installs nothing** and is fast.
- **`tests/test_pypi.sh`** (hard gate) — a hermetic resilience suite for a **blocked PyPI**
  (the `files.pythonhosted.org` incident). Under a curated PATH and a `curl` shim that blocks
  the PyPI file host while answering the GitHub API, it asserts the closed path is detected
  **fast, before `uv` is ever invoked** (no multi-minute hang), **ruff falls back** to its
  GitHub release binary, **euporie/basedpyright are DEFERRED** (not failed), and the final
  summary is **honest** (exit 2, no false success line). Like `test_sete.sh`, it downloads
  and installs nothing.
- **`tests/validate.sh`** (soft) — the four motivating tool checks (glow, bat, euporie,
  Helix+LSP); it reports skips on a bare machine that doesn't have the tools installed, so
  it never gates the result.

The same shellcheck + `test_sete.sh` + `test_pypi.sh` run on every push via GitHub Actions
(`.github/workflows/ci.yml`).

## 12. Repository layout

```
install.sh            entrypoint: flags, detection, module dispatch, validation
lib/                  log.sh detect.sh fallback.sh symlink.sh apt.sh github.sh
                      release.sh (shared release-binary installer) outcome.sh (per-tool ledger)
modules/              00-uv 10-terminal 20-viewers 30-euporie 40-helix
                      50-git-docker-tui 60-ssh-alias 70-starship 90-vscodium (gated)
dotfiles/             kitty/ helix/ wezterm/ starship/ yazi/
tests/                run.sh · test_sete.sh · test_pypi.sh · validate.sh + sample.md/py/ipynb
.github/workflows/    ci.yml (shellcheck + test_sete + test_pypi on push)
config.env.example    template for your (git-ignored) local config.env
```

## Author

[Manuel Hernández Giuliani](https://github.com/mahernandezg) (GitHub:
[`mahernandezg`](https://github.com/mahernandezg)).

## License

[MIT](LICENSE).
