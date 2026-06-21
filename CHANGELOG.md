# Changelog

All notable changes to `lnx-cli-tui-ide` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
While on `0.x`, a **minor** bump means substantial new functionality and a **patch**
bump means fixes only.

## [Unreleased]

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

[0.4.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mahernandezg/lnx-cli-tui-ide/releases/tag/v0.1.0
