# Changelog

All notable changes to `lnx-cli-tui-ide` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While on `0.x`, a **minor** bump means substantial new functionality and a **patch**
bump means fixes only.

## [Unreleased]

### Changed
- **Default editor is now micro.** `EDITOR`/`VISUAL=micro` (managed `~/.bashrc` block),
  and yazi opens text/code files with micro. vim handles the heavy lifting.

### Removed
- **Helix.** The Helix editor, its config/themes (`dotfiles/helix/`), and the
  `basedpyright`/`vtsls` language servers are no longer installed. **ruff** survives as a
  standalone Python linter/formatter in its own module (`modules/40-ruff.sh`). The
  `validate.sh` Helix check is dropped (3 motivating cases now).

### Added
- **micro editor** (`modules/45-micro.sh` + `dotfiles/micro/settings.json`): a simple,
  modeless terminal editor (Ctrl+S/Q/C/V) for quick edits, complementing Helix. Installs
  the official latest-stable binary into `~/.local/bin` (apt fallback), idempotent VERIFY,
  honest `--dry-run`/DEFER, plus a tiny QoL config. Added to the `mahg-help` cheatsheet.
  Hermetic, mutation-verified test (`tests/test_micro.sh`).
- **Go toolchain module** (`modules/02-golang.sh`): installs the official stable Go
  (go.dev tarball, sha256-verified) into `/usr/local/go`, and a **persistent, idempotent
  PATH guard** in `~/.bashrc` putting `/usr/local/go/bin` and `~/go/bin` (GOPATH bin) on
  PATH for every shell — native Debian and WSL. VERIFY keeps an existing Go ≥ 1.26
  (PRESENT) and only (re)applies the PATH guard; honest `--dry-run`/DEFER (no sudo, curl,
  jq, or network). Hermetic, mutation-verified test (`tests/test_golang.sh`).

## [0.5.0] — 2026-06-22

Post‑v0.4.0 batch: the bundled terminal emulator is dropped in favour of the system **GNOME
Terminal**, **tmux** (with numeric layouts) becomes the multiplexer, plus the **mahg‑help**
environment cheatsheet, an **AI‑agents protection module** (six agents), **Windows Terminal**
brand parity for WSL, and a gitleaks‑gated **snapshot‑publishing** mechanism for a clean public
repo.

### Added
- **Snapshot publishing** (`scripts/publish-snapshot.sh` + `docs/publish-snapshot.md`): publishes
  a clean tree to a separate public repo with NO private history — excludes `.postoffice/`,
  `docs/security-audit-*`, and `web-ext-artifacts/`; commits with a neutral GitHub-noreply
  identity; and runs **gitleaks as a pre-publish gate that ABORTS on any finding**. `--dry-run`
  by default. Hermetic, mutation-verified test (`tests/test_publish_snapshot.sh`).
- **Windows Terminal mahg scheme (WSL parity)** — `profiles/windows-terminal/mahg-dark.json`
  (the brand navy scheme, same hex as GNOME Terminal `mahg-dark`), documented manual install
  (`docs/windows-terminal.md`), and an optional, safe helper `bin/mahg-wt-apply` (run from WSL):
  `jq`-based, backs up `settings.json` before writing, idempotent, and DEFERS to the manual
  steps on any doubt. `modules/96-mahg-wt.sh` installs the helper on PATH only under WSL.
  Hermetic, mutation-verified test (`tests/test_mahg_wt.sh`).
- **`mahg-help`** (`bin/mahg-help` + `modules/95-mahg-help.sh`): a branded, dynamic
  cheatsheet of the environment — AI agents (present/absent + version), installed
  CLI/TUI tools, tmux shortcuts, `~/Templates`, and a config/paths map. Brand colours
  degrade to plain text when piped or under `NO_COLOR`. Sections selectable
  (`mahg-help agents|tools|shortcuts|templates|paths`). Hermetic, mutation-verified
  test (`tests/test_mahg_help.sh`).
- **AI-agents protection module** (`modules/05-ai-agents.sh` + `docs/ai-agents.md`):
  verifies the Professor's AI coding agents by their real binary names (`pi`, `codex`,
  `claude`, `agy`, `grok`, `copilot`) on every run, restores a missing one from its
  official installer (idempotent, `--dry-run` aware), guards that `/usr/local/bin` and
  `~/.local/bin` are on `PATH`, and documents each agent's data/login location and the
  debloat protected-zone. Hermetic, mutation-verified test (`tests/test_ai_agents.sh`).
- **tmux** (`modules/15-tmux.sh` + `dotfiles/tmux/tmux.conf`) for splits and persistent
  sessions on top of GNOME Terminal's tabs. Branded navy (dark only); prefix `C-a`;
  intuitive `|` / `-` splits that inherit the pane's path; **numeric layouts `C-a 1`–`4`**
  (two/three columns, big-left + stacked, 2×2 grid — replacing the default go-to-window);
  mouse on; vim pane navigation/resize; `base-index 1`. Manual launch — no auto-start.
  Hermetic, mutation-verified, self-skipping test (`tests/test_tmux.sh`), wired into CI.

### Removed
- **kitty and WezTerm.** The installer no longer installs or replaces a terminal
  emulator; the stack uses the system's GNOME Terminal. `modules/10-terminal.sh` now
  only installs the terminal fonts (Nerd Font + DejaVu fallback). `dotfiles/kitty/` and
  `dotfiles/wezterm/` are deleted, and the kitty ssh-kitten linking is dropped from the
  SSH module. euporie inline plots ride GNOME Terminal's sixel support.

## [0.4.0] — 2026-06-21

Branding & theming batch: a vendored mahg terminal look (GNOME Terminal + Helix +
Starship), a redesigned prompt, a white block cursor, a Claude Code statusline so
sessions can be told apart, and a glyph-fallback font. Every change was visually
validated by the Professor before tagging.

### Added
- **GNOME Terminal `mahg-dark` profile** (vendored): brand colors, plus a white
  block cursor that matches the terminal text color (`#edf2ff`).
- **`mahg-light` dark/light pair**: GNOME Terminal `mahg-light` profile and Helix
  `mahg-light` theme, vendored for reference — kept, never auto-switched.
- **Helix `mahg-dark` theme**.
- **`--force-profile-keys` flag** (`install.sh --only 80 --force-profile-keys`):
  reloads the vendored keys into an existing profile's current UUID without deleting
  the profile or minting a new UUID. Idempotent, honors `--dry-run`, per-profile
  backup before applying.
- **`fonts-dejavu-core`** installed by `modules/10-terminal.sh` to guarantee glyph
  fallback coverage for the Starship prompt glyphs that JetBrains Mono Nerd Font does
  not provide.
- **Claude Code `mahg` statusline** (`dotfiles/claude-code/statusline.sh`): shows the
  repo, current directory and session name in brand colors so each Claude Code session
  is identifiable inside its own UI. Activation documented in README §13.

### Changed
- **Starship prompt redesigned**: full path from `~` (no truncation), `[ branch ]` in
  brand amber (`#ffbf47`), and a `╰─❯` connector in brand blue (`#4c86ff`) joining the
  info line to the input line (red on error, green in vi command mode).
- **Terminal and Helix pinned to `mahg-dark`** in every desktop mode (dark or light);
  `mahg-light` stays vendored but is never activated by color-scheme switching.

### Notes
- The terminal tab title is owned by Claude Code (set to `Claude Code`) and is not
  configurable today, so session identity lives in the statusline, not the title.
  Tracked upstream: anthropics/claude-code #21677, #18326, #55197.
- VS Code → VSCodium migration inventory closed: settings/extensions migrated and the
  VS Code flatpak is already absent (only residual data remains).

## [0.3.0] — 2026-06-20

### Added
- `modules/75-tab-title.sh`: GNOME Terminal tab title shows the current directory.

## [0.2.0] — 2026-06-15

### Changed
- Resilience release: fast-fail PyPI checks, ruff GitHub fallback, and an honest
  deferred-install summary.

## [0.1.0] — 2026-06-14

### Added
- First release.

[0.5.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/releases/tag/v0.1.0
