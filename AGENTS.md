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
- `notes/` — design notes (`ROADMAP.md`, `ERD.md`, `PARKING-LOT.md`, `amp-cost-analysis.md`, `notes-chrome-extension.md`); read before changing related behavior.

## Parking lot

`notes/PARKING-LOT.md` holds unstructured ideas that are **not commitments**
and **not TODOs**. Never treat a parking-lot entry as work to implement.

When the user asks to add an idea to the parking lot, use the `parking-lot`
skill. Do not push parking-lot commits unless the user explicitly asks.

## Branches and commits

- Work happens on topic branches; `main` is always releasable.
- Branch prefix matches commit type:
  - `feat/<slug>` — new functionality
  - `fix/<slug>` — bug fix
  - `chore/<slug>` — tooling, deps, docs-only refactors
  - `docs/<slug>` — substantive documentation work
  - `explore/<slug>` — spike / throwaway investigation
- Use `feat/`, never `feature/`. Use `fix/`, never `bugfix/` or `hotfix/`.
- Commit messages follow Conventional Commits: `type(scope): summary`
  (e.g. `feat(scripts): add send-to-slack`, `chore(parking-lot): …`).
- One logical change per commit. Don't bundle unrelated edits — split them
  into separate commits even on the same branch.
- Never push without explicit user instruction.

## Conventions for new `send-to-*.sh` scripts

When the user asks to add a new Raycast target app, use the
`adding-send-to-target` skill. It encodes the strategy choice
(cliclick-paste vs AppleScript), the Sticky-Keys-safe ritual, and the
required Raycast headers, and routes through `scripts/new-shortcut.sh`.

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
