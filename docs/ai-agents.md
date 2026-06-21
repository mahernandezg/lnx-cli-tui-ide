# AI coding agents — verify, restore & protect

The Professor runs several AI coding agents that were installed **by hand, outside this
repo**. One (pi.dev) once vanished with no way to detect or restore it. To stop that from
ever happening silently again, `modules/05-ai-agents.sh` runs **early on every install** and:

1. **Verifies** each agent is present (by its **real binary name**) and reports its version.
2. **Restores** a missing agent from its official installer (idempotent, `--dry-run` aware,
   skips anything already present).
3. Points here for **where each agent's data/login lives**, so you always know how to
   recover one by hand.

Run a verify any time:

```bash
./install.sh --only 05            # lists each agent + status (PRESENT / restored / DEFERRED)
```

## The agents

Use the **real binary name** — not an old alias. Google's **Gemini CLI was discontinued
(2026‑06‑18)** and replaced by **Antigravity (`agy`)**; `gemini`/`antigravity` are not used.

| Agent | Binary | Typical location | Official installer | Data / login |
|-------|--------|------------------|--------------------|--------------|
| pi.dev | `pi` | `/usr/local/bin/pi` | `curl -fsSL https://pi.dev/install.sh \| sh` (alt: `npm i -g @mariozechner/pi-coding-agent`) | `~/.pi/` |
| OpenAI Codex | `codex` | `/usr/local/bin/codex` | `npm install -g @openai/codex` | `~/.codex/` |
| Claude Code | `claude` | `~/.local/bin/claude` | `curl -fsSL https://claude.ai/install.sh \| bash` | `~/.local/share/claude`, `~/.claude/` |
| Antigravity | `agy` | `~/.local/bin/agy` | `curl -fsSL https://antigravity.google/cli/install.sh \| bash` | system keyring + `~/.gemini/antigravity-cli/` |
| xAI Grok | `grok` | `~/.local/bin/grok` → `~/.grok/bin/grok` | *(not wired — install from the official xAI source, then re-run)* | `~/.grok/` |
| GitHub Copilot CLI | `copilot` | `~/.local/bin/copilot` | *(not wired — install from the official GitHub source, then re-run)* | `~/.config/` |

> **pi**, **codex**, **claude** and **agy** have a wired auto‑restore (pi & agy were verified
> live; claude & codex use their documented official installers). **grok** and **copilot** are
> verified but have **no auto‑installer wired yet** — the module DEFERs with a note rather than
> guess an installer. Wire them here once their official installer is confirmed.

## PATH

The agents live in **`/usr/local/bin`** and **`~/.local/bin`**. Both must be on your `PATH`
(the repo's `~/.bashrc` block already exports `~/.local/bin`). The module **warns** if either
is missing; it never rewrites your `PATH` silently.

## Protected zone (debloat)

The six agent binaries above, plus **`/usr/local/bin`** and **`~/.local/bin`**, are a
**protected zone**: the desktop debloat (which lives in **`lnx-gui-ide`**, not this repo) must
**never** remove them. Adding this allowlist to the GUI‑side debloat is tracked as a separate
task — this CLI module only verifies, restores, and documents.
