# Windows Terminal — mahg scheme (WSL parity)

The Professor runs two ecosystems: **native GNOME Debian** and **WSL Debian inside Windows**.
In WSL the terminal host is **Windows Terminal**, not GNOME Terminal — and it paints its own
colours (the blue wasn't the brand navy). This gives both ecosystems the **same mahg-dark navy**.

The shell layer (Starship, tmux, Helix, the agents) is already identical in both — this is
**only** the colour scheme of the Windows Terminal host.

## Source of truth

The scheme is vendored in the repo (Linux side), independent of Windows:

```
profiles/windows-terminal/mahg-dark.json
```

It is a valid Windows Terminal *scheme* object (`name: "mahg-dark"`) with the exact same hex
values as the GNOME Terminal `mahg-dark` profile, so the two terminals match.

## Manual install (the robust route)

Windows Terminal's `settings.json` lives on **Windows**, not Linux
(`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json`), so the
reliable way is by hand:

1. Open **Windows Terminal ▸ Settings** (`Ctrl+,`) ▸ bottom-left **Open JSON file**.
2. Find the top-level **`"schemes": [ ... ]`** array and paste the contents of
   `profiles/windows-terminal/mahg-dark.json` as a new element (mind the commas).
3. Find your **WSL/Debian profile** under `"profiles" ▸ "list"` and add:
   ```json
   "colorScheme": "mahg-dark",
   "cursorShape": "filledBox"
   ```
   (`filledBox` gives the white block cursor, matching GNOME Terminal.)
4. Save. Windows Terminal reloads instantly — the Debian profile is now brand navy.

> Tip: to apply it to **every** profile, set `"colorScheme": "mahg-dark"` in
> `"profiles" ▸ "defaults"` instead of per-profile.

## Optional helper (from WSL): `mahg-wt-apply`

If you'd rather not edit JSON by hand, run the vendored helper **from inside WSL**:

```bash
mahg-wt-apply --dry-run     # show what it would change; writes nothing
mahg-wt-apply               # apply it
```

It is **safe by design**: it uses `jq` (never `sed`), **backs up** `settings.json` to
`settings.json.mahg.bak.<timestamp>` before writing, is **idempotent**, and **DEFERS to the
manual steps above** whenever anything is uncertain — not WSL, no `jq`, the file is missing,
the JSON is invalid, or the structure is unexpected. It never risks corrupting your Windows
`settings.json`.

What it does when it can run: injects the `mahg-dark` scheme into `schemes[]` (idempotent), and
on every WSL profile (`source == "Windows.Terminal.Wsl"`) sets `colorScheme: "mahg-dark"` and
`cursorShape: "filledBox"`. Other profiles and keys are left untouched.

- If Windows Terminal lives at a non-standard path, point the helper at it:
  `mahg-wt-apply --settings "/mnt/c/Users/<you>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json"`
- **Revert:** restore the printed backup — `cp settings.json.mahg.bak.<timestamp> settings.json`.

On a native (non-WSL) machine the helper simply DEFERS; `modules/96-mahg-wt.sh` only puts it on
`PATH` when it detects WSL.
