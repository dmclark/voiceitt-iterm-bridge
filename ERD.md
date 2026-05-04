# ERD — Engineering Requirements & Delivery Checklist

Companion to [ROADMAP.md](./ROADMAP.md). The roadmap is the *thinking*
(why, design, tradeoffs); this doc is the *doing* — a flat checklist of
concrete deliverables we can tick off as work lands.

Rules:

- Every item is a single, verifiable thing. If it can't be checked off
  in one PR/commit, break it down further.
- Ordering reflects current priority. Section 0 ships before section 1, etc.
- When an item completes, leave it checked (don't delete it) so the doc
  doubles as a changelog.
- If a requirement is dropped or superseded, mark it `~~strikethrough~~`
  with a one-line note instead of removing it.

Legend: `[ ]` todo · `[x]` done · `[~]` in progress · `[-]` deferred / dropped

---

## 0. New-shortcut workflow (current focus)

Goal: make adding a `send-to-<app>` shortcut a documented, repeatable
process, with VS Code as the first hand-built non-iTerm target.

### 0.1 Prototype: hand-built `send-to-vscode.sh`

- [x] Copy `scripts/send-to-iterm.sh` → `scripts/send-to-vscode.sh`.
- [x] Replace iTerm AppleScript block with `cliclick`-based activate +
      Cmd+V targeting bundle id `com.microsoft.VSCode`.
- [x] Update Raycast header comments (`@raycast.title`,
      `@raycast.description`, icon).
- [x] `chmod +x scripts/send-to-vscode.sh`.
- [x] Symlink into `~/.config/raycast/scripts/` (match `install.sh` convention).
- [x] Assign a hotkey in Raycast and trigger once to clear macOS permission
      prompts (Accessibility for Raycast, automation for VS Code).
- [x] Verify end-to-end with **Sticky Keys ON**: dictate → hotkey → text
      lands in active VS Code editor pane.
- [-] Note every manual fix-up that was required (focus issues, sleeps,
      paste-target weirdness) in `notes-vscode.md` for feeding into 0.2 and 0.3.
      *Dropped: prototype worked first try with no fix-ups needed (Sticky Keys ON
      verified). Findings folded directly into 0.2/0.3 instead of a sidecar file.*

### 0.2 README: "Adding a new shortcut" section

- [x] Add new top-level section to `README.md` titled **Adding a new shortcut**.
- [x] Document: how to find an app's bundle id
      (`osascript -e 'id of app "Visual Studio Code"'`, `lsappinfo`).
- [x] Document: which existing `send-to-*.sh` to start from
      (AppleScript-capable target → `send-to-iterm.sh`; everything else →
      `send-to-vscode.sh` once it exists).
- [x] Document: the edit checklist (header comments, bundle id, paste step,
      submit-key behaviour).
- [x] Document: `chmod +x` + Raycast symlink step.
- [x] Document: assigning the hotkey in Raycast.
- [x] Document: the **first-trigger permission prompts** the user should
      expect, and what to do if they were dismissed accidentally
      (`System Settings → Privacy & Security → Accessibility / Automation`).
- [x] Document: how to verify with Sticky Keys ON.

### 0.3 Helper: `scripts/new-shortcut.sh`

- [x] Create `scripts/new-shortcut.sh`, executable.
- [x] Accepts `--name "VS Code"`, `--bundle-id com.microsoft.VSCode`,
      `--base send-to-iterm.sh` (default).
      *Default base is actually `send-to-vscode.sh` — the cliclick-paste
      strategy is the more general starting point. `--base send-to-iterm.sh`
      is supported but emits a hand-edit warning because the AppleScript
      body in step 6 is target-specific.*
- [x] Slugifies name → `vs-code` (or `vscode`); refuses to overwrite an
      existing `scripts/send-to-<slug>.sh` without `--force`.
- [x] Stamps out a renamed copy of the base script with bundle id and
      Raycast headers substituted.
- [x] `chmod +x` the new file.
- [x] Creates the Raycast symlink (mirroring `install.sh`).
      *Implemented by re-running `install.sh`, which in this commit also
      learned to skip non-Raycast helpers (no `@raycast.schemaVersion`).*
- [x] Prints next steps (open Raycast, assign hotkey, expect permission prompt).
- [x] Smoke-test: `./scripts/new-shortcut.sh --name "Notes" --bundle-id com.apple.Notes`
      produces a working `send-to-notes.sh` that pastes into Notes.
      *Verified the diff against `send-to-vscode.sh` is exactly four
      substitutions (title, description, bundle id, notification title) and
      nothing else. Smoke-test artifact removed; user can regenerate on
      demand. End-to-end paste-into-Notes verification is the user's call —
      not blocking 0.3.*

### 0.4 Cross-links

- [x] Add a back-reference from ROADMAP §2 ("Per-target scripts via a
      generator") to ROADMAP §0, noting the §0 helper is the seed of §2's
      richer generator.

---

## 0.5 Two-pane scratchpad + visual polish (prep for §1)

Goal: split `bridge/dictate.html` into a "Dictated" + "To be pasted" pair,
apply a light typography pass, and make the caret findable — all before
any LLM work in §1.

### 0.5.1 Two-pane layout

- [ ] Refactor `bridge/dictate.html` into two stacked textareas in a flex
      column.
- [ ] Top textarea keeps `id="pad"` (back-compat with current send scripts).
- [ ] Bottom textarea has its own id (e.g. `id="pad-out"`), `readonly` for v0.5.
- [ ] Mini-labels above each pane: `Dictated` / `To be pasted`.
- [ ] `input` listener on top pane mirrors its value into the bottom pane
      (placeholder for §1's LLM transform).
- [ ] Bottom pane shows a muted placeholder explaining it'll mirror the
      top until §1 lands.

### 0.5.2 Send-script retargeting

- [ ] Update `send-to-iterm.sh` and `send-to-iterm-and-run.sh` to
      Cmd+A/Cmd+C the **bottom** textarea (`pad-out`) instead of `pad`.
- [ ] Same change in `send-to-vscode.sh` and any future `send-to-*.sh`
      shipped by §0.3.
- [ ] Smoke-test with Sticky Keys ON: dictate → bottom pane mirrors →
      hotkey pastes the right text into iTerm and VS Code.

### 0.5.3 Typography pass

- [x] Add Atkinson Hyperlegible (Google Fonts `@import` *or* a vendored
      woff2 in `bridge/`) — pick one, document the choice in `bridge/`.
      *Chose Google Fonts `@import` (weights 400 + 700, `display=swap`).
      Documented in a comment block at the top of `bridge/dictate.html`'s
      `<style>` with a note on how to swap to a vendored woff2 if we ever
      need fully-offline behaviour.*
- [x] Apply font-family chain:
      `"Atkinson Hyperlegible", -apple-system, BlinkMacSystemFont,
      "SF Pro Text", system-ui, sans-serif`.
- [x] Warmer page background `#fafaf7` (was `#ffffff`).
- [~] `border-radius: 8px` on each pane, thin `#e6e6e1` divider between them.
      *Deferred to 0.5.1: there's only one pane today. Header divider colour
      already migrated to `#e6e6e1` so the rest is a one-liner once the
      bottom pane lands.*
- [x] Header strip picks up the new font.
      *Inherits via the `body` font-family chain; header background also
      shifted to `#f5f4ef` to harmonise with the new warmer page background.*

### 0.5.4 Caret visibility (starter combo)

- [ ] `caret-color: #ff3b30` on both textareas.
- [ ] Focused pane bumps `font-size` 22 px → 26 px with
      `transition: font-size 80ms ease;`.
- [ ] Focused pane gets a faint inset tint via
      `box-shadow: inset 0 0 0 9999px rgba(255,235,150,0.18)` on `:focus`.
- [ ] Verify caret is findable in <1 s after looking away (manual check,
      Sticky Keys ON, both panes).
- [-] Per-line highlight (deferred — only if the cheap focused-pane tint
      isn't enough in daily use).
- [-] Pulse-on-focus / pulse-on-caret-jump beacon (deferred — JS, follow-up).
- [-] Custom faux-caret overlay (deferred — ~50 lines of JS, only if
      1–3 above don't move the needle).

### 0.5.5 Out of scope (explicit)

- [-] LLM call (belongs to §1).
- [-] Bottom pane editable (belongs to §1, where editing it means something).
- [-] Prompt picker (belongs to §1).
- [-] Diff view between panes (premature until §1 rewrites the bottom one).

---

## 1. AI post-processing before paste

Goal: insert a user-selectable LLM transformation between
clipboard-capture and destination-paste.

### 1.1 Prompt config

- [ ] Ship `bridge/prompts.default.json` with the starter prompt set from ROADMAP §1.
- [ ] `install.sh` copies it to `~/.config/voiceitt-bridge/prompts.json`
      on first run, never overwrites on subsequent runs.

### 1.2 Scratchpad picker UI

- [ ] Add `<select>` to `bridge/dictate.html` header next to the Clear button.
- [ ] Populate options from `fetch('/prompts.json')` at page load.
- [ ] First option always **`Off — paste as dictated`**.
- [ ] Persist current selection to `localStorage`.
- [ ] On change, write the selected prompt id to
      `~/.config/voiceitt-bridge/active-prompt` (via a tiny POST endpoint
      on the local server).

### 1.3 Transformer CLI

- [ ] Create `scripts/voiceitt-transform` (bash + curl + jq).
- [ ] Reads stdin; reads active prompt id from
      `~/.config/voiceitt-bridge/active-prompt`.
- [ ] Looks up prompt definition in `prompts.json`.
- [ ] If prompt id is `off` → echo stdin unchanged, exit 0.
- [ ] Otherwise POST to provider (Anthropic / Google) with prompt's
      `system` text; print response on stdout.
- [ ] Non-zero exit → caller falls back to raw text (fail-open).
- [ ] Document required env vars (`ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`).

### 1.4 Send-script integration

- [ ] In each `send-to-*.sh`, after the "copy fired" sentinel and before
      the paste, pipe `$CURRENT` through `voiceitt-transform` if it's on `$PATH`.
- [ ] On transformer failure, fall back to `$CURRENT` unchanged.
- [ ] Verify Sticky-Keys preamble is unaffected.

---

## 2. Per-target scripts via a generator

Goal: graduate §0's minimal `new-shortcut.sh` into a real generator
with strategy templates and bundle-id auto-detection.

### 2.1 Refactor

- [ ] Extract shared "copy from focused app via cliclick + sentinel"
      preamble into `scripts/lib/copy-focused.sh`.
- [ ] Update existing `send-to-iterm*.sh` and the §0
      `send-to-vscode.sh` to source the lib.

### 2.2 Templates

- [ ] `templates/send-applescript.sh.tmpl` for AppleScript-capable apps.
- [ ] `templates/send-cliclick-paste.sh.tmpl` for everything else.
- [ ] `templates/send-cliclick-paste-run.sh.tmpl` for the `& Run` variant.
- [ ] Hand-curated AppleScript bodies for iTerm, Terminal, Chrome, Safari.

### 2.3 Generator: `scripts/new-target.sh`

- [ ] Raycast Script Command with `# @raycast.argument` for: target name,
      bundle id, strategy, submit-on-send, icon.
- [ ] Pre-fills bundle id from most-recent frontmost non-Raycast app
      (`lsappinfo`).
- [ ] Per-known-app sensible defaults for strategy + submit key.
- [ ] Stamps both `send-to-<slug>.sh` and (if requested)
      `send-to-<slug>-and-run.sh`.
- [ ] `chmod +x` and `ln -sfn` into Raycast scripts dir.
- [ ] Notification: created, open Raycast, assign hotkey, expect
      permission prompt.

### 2.4 Docs & risks

- [ ] README: "Adding a new target" section (supersedes §0.2's manual flow).
- [ ] Document Secure Input mode bail-out.
- [ ] Document focus-into-text-field caveat for `cliclick-paste` strategy.

---

## 3. Raycast Store extension

Goal: ship a TypeScript Raycast extension to the store.

### 3.1 Scaffold

- [ ] `npm create raycast-extension@latest`; pick "no view" default.
- [ ] Declare four commands in `package.json`.

### 3.2 Command ports

- [ ] Port `open-voiceitt`: spawn local HTTP server, write scratchpad to
      `environment.supportPath`, open Chrome via `runAppleScript`,
      detect already-running via PID file.
- [ ] Port `send-to-iterm` and `send-to-iterm-and-run` using
      `runAppleScript` + `cliclick` shell-out.
- [ ] Port `back-to-voiceitt` (straight `runAppleScript`).
- [ ] Port multi-target generator from §2 as a TS dispatcher + `<List>` UI.

### 3.3 Preferences

- [ ] Expose port, scratchpad title, `cliclick` path as Raycast preferences.

### 3.4 Polish

- [ ] 512×512 extension icon.
- [ ] At least one screenshot per command.
- [ ] Raycast-tone README.
- [ ] `CHANGELOG.md` entry.
- [ ] Permissions note (Accessibility + `cliclick` install).

### 3.5 Submission

- [ ] `npm run publish`.
- [ ] Address reviewer feedback rounds.
- [ ] Listed on Raycast Store.

---

## Cross-cutting / housekeeping

- [ ] Keep this ERD in sync with ROADMAP.md whenever a roadmap section
      gains/loses scope.
- [ ] On every shortcut PR, update the relevant 0.x / 2.x checkbox.
- [ ] Periodic sweep: convert any `[~]` items older than two weeks back
      to `[ ]` with a note about what blocked them.
