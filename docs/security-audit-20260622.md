# Security audit — Level 1 (detection only) — 2026-06-22

**Repo:** `lnx-cli-tui-ide` · **Purpose:** pre‑flip review before making the repo **public**.
**Scope:** this repo only — current working tree **and the full git history** (72 commits).
**Nature:** detection + report **only**. Nothing was deleted, history was **not** rewritten, the
repo was **not** made public. Remediation (Level 2) is a separate task, to be decided by the
Professor with these findings in hand. Sensitive values are **redacted** in this report.

## Tools used

- **gitleaks 8.30.1** (official release binary; the only thing installed — it does not change the
  repo): `gitleaks detect --source . --redact` (scans **all 72 commits** of history) **and**
  `gitleaks dir . --redact` (scans the filesystem, including untracked files).
- **Manual complement:** `git grep` over tracked files and `git log -p --all` over full history,
  with regexes for private keys, tokens (GitHub/npm/AWS/Google/Slack), AMO/Mozilla JWT
  (`jwtIssuer`/`jwtSecret`), `secret`/`token`/`api_key`/`password` assignments, infra host names
  (Hetzner, `*.mahg.es`), IPs, emails/phones, the MacBook serial, and absolute personal paths.
- `.gitignore` review; inspection of `config.env.example`, the vendored `profiles/` (dconf + WT
  JSON), and all ignored/untracked files.

## Headline

**No CRITICAL findings. No live secret exists in the working tree or in any of the 72 commits of
history.** There is **no blocker** to making the repo public on security grounds. The remaining
items are *exposure-of-internal-context* decisions (below) that are the Professor's call, not
credential leaks.

## Findings

| # | Severity | What | Location | Where | Recommendation (Level 2 — not executed) |
|---|----------|------|----------|-------|------------------------------------------|
| 1 | **MEDIUM** | `.postoffice/thread.md` is a verbose **internal agent-coordination log**: internal repo names (`lnx-gui-ide`, `araya`), workflow/operational detail, machine paths (`~/github/mahernandezg/…`, `~/.local/…`), and — inside the text of this very audit task — mentions of an internal host (`*.mahg.es`, redacted), the provider "Hetzner", and "the MacBook serial" **as search terms** (no IP, no value, no serial number present). No secrets, but a lot of internal context. | `.postoffice/thread.md` (whole file) | working tree **+ history** (tracked since the postoffice was added) | Decide whether `.postoffice/` should be public at all (it is coordination scaffolding, not product). Options: exclude the dir from the public repo and `.gitignore` it, or keep it after a conscious review. If excluded, removing it from *history* needs `git filter-repo` (Level 2). |
| 2 | **LOW–MEDIUM** | Author identity in **git commit metadata**: `The Data Professor <mahernandezg@gmail.com>` on every commit. Inherent to git; becomes visible publicly. The GitHub handle `mahernandezg` is already public; the gmail is mildly personal. | all commits (metadata, not file contents) | history (inherent) | Usually accepted for public repos. If undesired, it requires a history rewrite of author email (Level 2) — typically not worth it; or set a noreply email going forward. |
| 3 | **LOW (false positive)** | gitleaks `generic-api-key` matched a log line `keys for mahg-dark=…` — this is GNOME Terminal **profile keys** (appearance settings), **not** a credential. | `logs/install-20260621-111847.log:29`, `logs/install-20260621-125247.log:25` | working tree only; **untracked & gitignored** (`logs/`, `*.log`) — never committed, will not publish | None. Confirm `logs/` stays gitignored (it is). |
| 4 | **LOW (false positive)** | Synthetic test fixtures flagged by IP/UUID/date regexes: fake IP `1.2.3.4` (mocked curl rate-limit message) and all-zeros test UUIDs (`f0000000-…`, `d0000000-…`). | `tests/test_sete.sh:96`, `tests/test_gnome_profile.sh` (multiple) | tracked | None — synthetic test data, safe to publish. |
| 5 | **LOW (informational)** | `lib/github.sh` reads `${GITHUB_TOKEN:-}` from the environment to raise the GitHub API rate limit — correct usage, **no token value is stored**. | `lib/github.sh:33` | tracked | None. |

## What is NOT present (verified clean)

- **No private keys** (`BEGIN … PRIVATE KEY`, OpenSSH/RSA/EC/PGP) — tree or history.
- **No tokens / API keys** (GitHub `ghp_`/`github_pat_`, npm, AWS `AKIA`, Google `AIza`, Slack
  `xox…`) — tree or history.
- **No Mozilla AMO signing keys** (`jwtIssuer`/`jwtSecret`) — the signed `.xpi` work was done in
  the GUI repo; **no AMO key landed here**. Confirmed across all 72 commits.
- **No `config.env`** with real values (gitignored; only `config.env.example` with placeholders
  `myhost` / `host.example.com` / `myuser` is committed).
- **No tracked** `*.pem` / `*.key` / `*.bak` / `.env` / deploy keys / web-ext artifacts.
- **No real infra** values: no IPs, no Hetzner host/alias, no `*.mahg.es` **configuration**
  (only the audit-text mentions in finding #1). No MacBook serial value anywhere.
- **No hardcoded personal home paths** (`/home/<user>`) in tracked files (count: 0).
- Vendored `profiles/` (gnome-terminal `*.dconf`, windows-terminal `mahg-dark.json`) contain
  **only colours/appearance** — no UUIDs (written per-machine at install), no secrets.

## `.gitignore` assessment

Solid for this repo — covers `config.env`, `logs/` + `*.log`, `state/`, `*.bak.*`, key shapes
(`id_*`, `*_deploy`, `*.pem`, `*.key`, `known_hosts`), and editor/OS noise. **No gaps found.**
(`web-ext-artifacts` is not relevant here — that belongs to the GUI repo.)

## Answer for the Professor

**Are there blockers to publishing? → No CRITICAL blockers.** No credential is exposed in the
working tree or history. Before flipping public, make two *non-security* decisions:

1. **`.postoffice/thread.md`** (finding #1) — do you want the internal coordination log public? If
   not, it should be excluded (and, to be thorough, removed from history) in Level 2.
2. **Commit-metadata email** (finding #2) — accept the gmail in public commit history, or not.

Everything else is clean or false-positive noise. **No secret needs rotating.** The Professor
decides the Level 2 scope; nothing here was changed.
