# AGENTS.md

Guidance for AI agents working in this repo. Keep changes small, reversible, and aligned with the conventions below.

## What this project is

A macOS-only toolkit that bridges the Voiceitt Chrome extension (voice dictation) to arbitrary local apps via Raycast Script Commands. The flow is:

`Chrome (Voiceitt) → localhost scratchpad → clipboard → AppleScript / cliclick → target app`

There is no build system, no package manager, no test suite. The "code" is bash scripts, one HTML file, and Markdown docs.

## Layout

- `scripts/` — Raycast Script Commands (`send-to-*.sh`, `open-voiceitt.sh`, `back-to-voiceitt.sh`) plus helpers (`new-shortcut.sh`, `voiceitt-transform`).
- `bridge/dictate.html` — the scratchpad page served on `http://localhost:7531`.
- `prompts/` — reusable prompt text for the user's dictation workflow.
- `install.sh` — symlinks scripts into `~/.config/raycast/scripts/` and the HTML into `~/.config/voiceitt-bridge/`. Idempotent; re-run after adding a script.
- `README.md` — user-facing setup and usage.
- `notes/` — design notes (`ROADMAP.md`, `ERD.md`, `amp-cost-analysis.md`, `notes-chrome-extension.md`); read before changing related behavior.

## Conventions for new `send-to-*.sh` scripts

When adding a new target app, copy the closest existing script and edit only what's necessary. Two strategies:

- **AppleScript** (e.g. `send-to-iterm.sh`) — when the target app has a useful scripting dictionary for inserting text into the active session.
- **cliclick paste** (e.g. `send-to-vscode.sh`) — the default for everything else. Activates the app by bundle id, then issues a synthetic `Cmd+V` via cliclick.

Every script must keep these Sticky-Keys-safe steps intact:

1. Stamp clipboard with a `SENTINEL`.
2. Release stuck modifiers via `cliclick ku:cmd,alt,ctrl,shift,fn`.
3. Issue Cmd+A / Cmd+C through `cliclick` (not AppleScript `keystroke ... using command down`).
4. Poll `pbpaste` for up to ~1s to confirm the copy actually fired.
5. On timeout, `osascript display notification ...` and `exit 1` instead of pasting stale text.
6. Then perform the destination-specific paste.

Required Raycast header lines (script will not appear in Raycast otherwise — `install.sh` filters on `@raycast.schemaVersion`):

```bash
# @raycast.schemaVersion 1
# @raycast.title <Send to App>
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon <emoji>
# @raycast.description <one line>
```

After adding or renaming a script: `chmod +x scripts/<file>.sh && ./install.sh`.

Helpers without a `@raycast.schemaVersion` header (e.g. `new-shortcut.sh`, `voiceitt-transform`) are intentionally excluded from the Raycast symlink loop — don't add the header to them.

## Things to avoid

- Don't replace `cliclick` with AppleScript `keystroke ... using command down` — it breaks under Sticky Keys, which is the entire point of this repo.
- Don't open Chrome with `--app=` for the scratchpad — it disables extensions, including Voiceitt.
- Don't switch the scratchpad to a `file://` URL — Voiceitt refuses to run there. Keep `http://localhost:7531`.
- Don't introduce a build step, package manager, or framework. The toolkit must stay a pile of bash + one HTML file.
- Don't commit anything matched by `.gitignore` (notably `.env`, `amp-cost-analysis.md`, `notes-chrome-extension.md`, `server.log`, `.DS_Store`).

## Verification

There are no automated tests. Before declaring a script change done, the user (or you, if running interactively on macOS) must:

1. Re-run `./install.sh`.
2. Trigger the affected Raycast command **with macOS Sticky Keys ON**.
3. Confirm text lands in the destination intact and no modifiers stay latched after.

If you cannot run the verification yourself, say so explicitly rather than implying it passed.

## Style

- Bash: `set -e` at top, comment each numbered step the way existing scripts do, prefer `osascript <<'EOF' ... EOF` heredocs for multi-line AppleScript.
- Markdown: match the existing tone in `README.md` — terse, concrete, code-block-heavy, no marketing voice.
- Diagrams: rounded box-drawing characters (`╭ ╮ ╰ ╯`) as in the README's architecture diagram.
