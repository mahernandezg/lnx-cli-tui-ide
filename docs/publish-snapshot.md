# Publishing: private workshop → clean public snapshot

This repo (`lnx-cli-tui-ide`) is the **private workshop**: full git history, the internal
`.postoffice/` coordination log, and a personal email in commit metadata. It is **not** published
directly. Instead, a **separate public repo** is fed by **snapshot** — only the final clean tree,
with internal files excluded and a neutral commit identity. The public repo is therefore **clean
by construction**, with no history rewrite required.

- **Private:** `mahernandezg/lnx-cli-tui-ide` (this repo) — the workshop. Stays private.
- **Public:** `mahernandezg/lnx-cli-tui-ide-public` — receives clean snapshots only.

## What is excluded from the public snapshot

`scripts/publish-snapshot.sh` builds the public tree from `git archive HEAD` (tracked files only —
so gitignored `logs/`, `*.bak.*`, `state/`, `config.env` are **never** present) and then removes
these **tracked** internal paths:

| Excluded | Why |
|----------|-----|
| `.postoffice/` | internal strategy⇄executor coordination log (verbose internal context) |
| `docs/security-audit-*` | internal security-audit reports |
| `web-ext-artifacts/` | build artifacts (defensive; not in this repo) |

Everything else — `install.sh`, `lib/`, `modules/`, `dotfiles/`, `profiles/`, `bin/`, `docs/`
(minus the audit), `tests/`, `scripts/`, `README.md`, `CHANGELOG.md`, `LICENSE` — is published.

## Commit identity (neutral)

The public snapshot is committed with the project author name and a **GitHub noreply email**
(`<id>+<user>@users.noreply.github.com`), **never** the personal `@gmail`. The private repo keeps
its normal identity. Override with `--author-name` / `--author-email` or the
`SNAPSHOT_AUTHOR_NAME` / `SNAPSHOT_AUTHOR_EMAIL` env vars.

## The gitleaks gate (pre-publish, mandatory)

Before anything is pushed, `publish-snapshot.sh` runs **gitleaks over the clean tree**. If it
reports **any** finding, the script **ABORTS** and pushes nothing. gitleaks is taken from `PATH`,
`~/.local/bin`, a cache, or fetched from its official release if missing; a real `--publish` with
no available gitleaks **aborts** (it will not publish without the gate).

## How to run

```bash
# 1) Preview — builds the clean tree, runs the gitleaks gate, prints exactly what would publish:
scripts/publish-snapshot.sh --dry-run

# 2) Publish a snapshot (requires a clean tree on main; aborts if gitleaks flags anything):
scripts/publish-snapshot.sh --publish --message "Snapshot v0.5.0"
```

Preconditions for `--publish`: clean working tree, on `main`. The public history is **minimal** —
one snapshot commit per run (`rsync --delete` replaces the public tree), independent of the
private repo's history. Re-running with no changes is a no-op.

> **First-time setup (already done):** the public repo is created once with
> `gh repo create mahernandezg/lnx-cli-tui-ide-public --public`. After that, only
> `publish-snapshot.sh` is needed for each release.

A hermetic, mutation-verified test (`tests/test_publish_snapshot.sh`) asserts the exclusions hold
(`.postoffice/` and the audit report never appear in a snapshot).
