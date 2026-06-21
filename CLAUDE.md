# CLAUDE.md

Guidance for AI assistants and contributors working in this repo.

## Postoffice (canal con el agente de estrategia)
Al inicio de cada run, lee `.postoffice/thread.md` entero. Si hay una entrada
`status:open` dirigida `strategy→executor`, ejecútala. Al final, añade tu reporte
como entrada `executor→strategy`. Reglas en `.postoffice/PROTOCOL.md`. Append-only:
nunca edites ni borres entradas previas.

## Author
Manuel Hernández Giuliani (GitHub: mahernandezg)

Use this exact name in any author/copyright/credit field. Never substitute a guessed or
placeholder name. If any personal detail (email, location, etc.) is needed and not
provided, leave a clear `TODO(ask)` marker and ask — do not invent one.

## Project
`lnx-cli-tui-ide` bootstraps a terminal-centric dev environment on Debian with one
command, adapting to each machine's hardware via a primary/fallback install engine.

## Hard constraints
- **No secrets, ever.** SSH keys (e.g. `~/.ssh/id_ed25519`) stay local and are only
  referenced, never written or committed. Connection details (host/user/key path) live in
  a gitignored `config.env`, never in the repo.
- **uv for all Python.** Never use `venv` / `python -m venv`. Use `uv venv`, `uv pip`,
  `uv tool install`, `uv run`, `uv sync`.
- **Idempotent**, **non-fatal** steps, **`--dry-run`**, timestamped **logging**.
- Bash with `set -euo pipefail` at the right scope; keep it **shellcheck-clean** and
  modular (one module per tool).
- Every state-changing command goes through `run()` / `run_quiet()` in `lib/log.sh` so
  `--dry-run` stays honest.

## Layout
- `lib/` — log, detect, fallback engine, symlink, apt helpers (build/understand first).
- `modules/NN-*.sh` — one tool/area each, run in numeric order, each in its own subshell.
- `dotfiles/` — symlinked into `~/.config` with timestamped backups.
- `tests/validate.sh` — the four motivating end-checks.
