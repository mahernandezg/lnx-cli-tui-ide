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
| xAI Grok | `grok` | `~/.local/bin/grok` → `~/.grok/bin/grok` | `curl -fsSL https://x.ai/cli/install.sh \| bash` | `~/.grok/config.toml`; login: run `grok` → OAuth (needs SuperGrok / X Premium+) |
| GitHub Copilot CLI | `copilot` | `~/.local/bin/copilot` | `npm install -g @github/copilot` (needs Node ≥ 22; alt: `curl -fsSL https://gh.io/copilot-install \| bash`) | `~/.copilot/`; login: `/login` inside copilot → GitHub OAuth |

> **All six agents now have a wired auto‑restore** (the documented official installers). `curl`‑based
> ones (pi, claude, agy, grok) install the binary directly; `npm`‑based ones (codex, copilot) need
> **Node.js ≥ 22** — if Node is missing or too old the module **DEFERs honestly** with a note to
> install Node first (it never forces). Installing a binary doesn't log you in: **grok** needs a
> SuperGrok / X Premium+ subscription to use, and **copilot** needs a GitHub OAuth `/login`.

## PATH

The agents live in **`/usr/local/bin`** and **`~/.local/bin`**. Both must be on your `PATH`
(the repo's `~/.bashrc` block already exports `~/.local/bin`). The module **warns** if either
is missing; it never rewrites your `PATH` silently.

## Protected zone (debloat)

The six agent binaries above, plus **`/usr/local/bin`** and **`~/.local/bin`**, are a
**protected zone**: the desktop debloat (which lives in **`lnx-gui-ide`**, not this repo) must
**never** remove them. Adding this allowlist to the GUI‑side debloat is tracked as a separate
task — this CLI module only verifies, restores, and documents.
