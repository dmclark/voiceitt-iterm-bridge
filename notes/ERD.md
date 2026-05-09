# ERD — Engineering Requirements & Delivery Checklist

**[📖 README](../README.md)** · **[🗺 Roadmap](./ROADMAP.md)** · **[🧩 ERD](./ERD.md)** · **[🅿️ Parking lot](./PARKING-LOT.md)**

---

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

<details>
<summary><h2 style="display:inline">0. New-shortcut workflow (current focus)</h2></summary>

Goal: make adding a `send-to-<app>` shortcut a documented, repeatable
process, with VS Code as the first hand-built non-iTerm target.

<details open>
<summary><h3 style="display:inline">0.1 Prototype: hand-built `send-to-vscode.sh`</h3></summary>

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

</details>

<details open>
<summary><h3 style="display:inline">0.2 README: "Adding a new shortcut" section</h3></summary>

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

</details>

<details open>
<summary><h3 style="display:inline">0.3 Helper: `scripts/new-shortcut.sh`</h3></summary>

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

</details>

<details open>
<summary><h3 style="display:inline">0.4 Cross-links</h3></summary>

- [x] Add a back-reference from ROADMAP §2 ("Per-target scripts via a
      generator") to ROADMAP §0, noting the §0 helper is the seed of §2's
      richer generator.

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">0.5 Two-pane scratchpad + visual polish (prep for §1)</h2></summary>

Goal: split `bridge/dictate.html` into a "Dictated" + "To be pasted" pair,
apply a light typography pass, and make the caret findable — all before
any LLM work in §1.

<details open>
<summary><h3 style="display:inline">0.5.1 Two-pane layout</h3></summary>

- [x] Refactor `bridge/dictate.html` into two stacked textareas in a flex
      column.
      *Each pane is its own `.pane` flex column (label + textarea), the
      two panes split the body 50/50 via `flex: 1`.*
- [x] Top textarea keeps `id="pad"` (back-compat with current send scripts).
- [x] Bottom textarea has its own id (e.g. `id="pad-out"`), `readonly` for v0.5.
- [x] Mini-labels above each pane: `Dictated` / `To be pasted`.
- [x] `input` listener on top pane mirrors its value into the bottom pane
      (placeholder for §1's LLM transform).
      *Cmd+K / Clear button now clear both panes; document-level click
      handler still bounces focus back to `pad` so the read-only bottom
      pane can't steal focus.*
- [x] Bottom pane shows a muted placeholder explaining it'll mirror the
      top until §1 lands.

</details>

<details open>
<summary><h3 style="display:inline">0.5.2 Send-script retargeting</h3></summary>

**Design pivot.** Original plan was to hard-code each `send-to-*.sh` to
target `pad-out`. Replaced with a page-side fix: `bridge/dictate.html`
no longer steals focus back to `pad` when Raycast briefly takes OS
focus, so the existing scripts (which already do `Cmd+A` / `Cmd+C` in
the focused app) now copy from whichever pane the user has focused.
Side benefit: lets the user deliberately send the raw `pad` text by
clicking into it before the hotkey, which the original plan would have
prevented.

- [x] ~~Update `send-to-iterm.sh` and `send-to-iterm-and-run.sh` to
      Cmd+A/Cmd+C the **bottom** textarea (`pad-out`) instead of `pad`.~~
      *Superseded by `fix(bridge): send-to-* respects which pane has focus`
      — no per-script edits needed.*
- [x] ~~Same change in `send-to-vscode.sh` and any future `send-to-*.sh`
      shipped by §0.3.~~ *Superseded; new `send-to-*.sh` scripts get the
      focus-driven behaviour for free via the page fix.*
- [ ] Smoke-test with Sticky Keys ON: focus the bottom pane → hotkey
      pastes cleaned text; focus the top pane → hotkey pastes raw
      dictated text. Repeat for iTerm and VS Code.

</details>

<details open>
<summary><h3 style="display:inline">0.5.3 Typography pass</h3></summary>

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
- [x] `border-radius: 8px` on each pane, thin `#e6e6e1` divider between them.
      *Landed alongside 0.5.1. `border-radius: 8px` on `textarea`,
      `border-top: 1px solid #e6e6e1` on `.pane + .pane` for the divider.*
- [x] Header strip picks up the new font.
      *Inherits via the `body` font-family chain; header background also
      shifted to `#f5f4ef` to harmonise with the new warmer page background.*

</details>

<details open>
<summary><h3 style="display:inline">0.5.4 Caret visibility (starter combo)</h3></summary>

- [x] `caret-color: #ff3b30` on both textareas.
      *Applied to the `textarea` selector so it covers `pad` today and
      the future `pad-out` (0.5.1) automatically.*
- [x] Focused pane bumps `font-size` 22 px → 26 px with
      `transition: font-size 80ms ease;`.
- [x] Focused pane gets a faint inset tint via
      `box-shadow: inset 0 0 0 9999px rgba(255,235,150,0.18)` on `:focus`.
- [~] Verify caret is findable in <1 s after looking away (manual check,
      Sticky Keys ON, both panes).
      *Single-pane today, so the focus styling is structurally redundant
      until 0.5.1 lands the second pane. Re-test then.*
- [-] Per-line highlight (deferred — only if the cheap focused-pane tint
      isn't enough in daily use).
- [-] Pulse-on-focus / pulse-on-caret-jump beacon (deferred — JS, follow-up).
- [x] Custom faux-caret overlay.
      *Pulled forward: native `caret-color` is fixed at 1 px and the user
      asked for a thicker bar. Implemented with the standard hidden-mirror
      `<div>` trick (~70 lines, comments included). Native caret hidden
      via `caret-color: transparent` on `:focus`; 3-px red `#faux-caret`
      div overlaid; recomputes on input/click/keyup/focus/scroll/select,
      `selectionchange`, resize, and across the 80 ms focus font-size
      transition via a short rAF loop.*

</details>

<details open>
<summary><h3 style="display:inline">0.5.5 Out of scope (explicit)</h3></summary>

- [-] LLM call (belongs to §1).
- [-] Bottom pane editable (belongs to §1, where editing it means something).
- [-] Prompt picker (belongs to §1).
- [-] Diff view between panes (premature until §1 rewrites the bottom one).

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">1. AI post-processing before paste</h2></summary>

Goal: insert a user-selectable LLM transformation **between the input
field (top) and the output field (bottom)** of the §0.5 two-pane
scratchpad. The transform fires when Voiceitt finishes a phrase, not at
hotkey time — so the existing `send-to-*.sh` bash is unchanged from
§0.5; all of §1's net-new logic lives in the page + a small CLI.

**MVP status (auto-trigger vertical slice).** The §1.3 auto-trigger +
manual `⌘↵` trigger are wired end-to-end through a new `bridge/serve.py`
that exposes `POST /transform` and shells out to the existing
`scripts/voiceitt-transform` (v0 Gemini). What this does *not* yet
include: the prompt picker (§1.2), the `POST /active-prompt` endpoint
and `~/.config/voiceitt-bridge/active-prompt` sidecar (§1.4), the
`.md`-file-driven prompt loading in `voiceitt-transform` (§1.5 — still
hardcoded), and updating the `send-to-*.sh` scripts to copy from
`pad-out` instead of `pad` (§0.5.2). Until §0.5.2 lands, the MVP is
verifiable in-page (dictate → bottom pane fills with cleaned text) but
the existing send hotkeys still pick up the raw text from `pad`.

**Default-off pivot (§1.0 below).** The MVP described in this status
block auto-fires the transform on every utterance. That has been
inverted: the auto-trigger is now gated on a master `AI` toggle in the
header, default OFF. The mechanics in §1.3 still apply *when the toggle
is on*; with it off, the page just mirrors `pad → pad-out` and never
calls the LLM. `⌘↵` keeps its one-shot-override behaviour.

<details open>
<summary><h3 style="display:inline">1.0 AI master toggle (default-off opt-in)</h3></summary>

The single switch that turns the entire §1 pipeline on. Inverts the
§1.3 MVP's auto-by-default behaviour so fresh installs cost zero LLM
calls until the user opts in.

- [x] Add a checkbox + label `AI` to the scratchpad header in
      `bridge/dictate.html`, between the status indicator and the
      Clear button.
- [x] Persist state to `localStorage` under
      `voiceitt-bridge:ai-enabled`. Default OFF.
- [x] Gate the §1.3 auto-trigger on the toggle: when OFF, mirror
      `pad.value → padOut.value` and set status to `off`; when ON,
      call `scheduleTransform()` as before.
- [x] Toggling OFF mid-call aborts any in-flight transform so a stale
      result doesn't land after the user opted out.
- [x] Toggling ON does **not** retroactively fire on whatever's already
      in `pad` — the next utterance triggers normally. Avoids surprise
      LLM cost on toggle-flip.
- [x] `⌘↵` in the input pane is **also gated** on the toggle: no-op
      when AI is off. "Off means off" across both auto-trigger and
      manual-trigger paths; firing the LLM with `pad-out` hidden would
      be invisible work. To try the LLM on a single phrase, flip the
      toggle on first.
- [x] Initial status indicator reflects the persisted toggle state
      (`off` on first paint when the toggle starts unchecked).
- [x] **Hide `#pane-out` entirely when AI is off.** Body class
      `ai-off` drives the CSS rule `body.ai-off #pane-out { display:
      none; }`. The Dictated pane's `flex: 1` expands to fill the body
      automatically. Toggling off while `pad-out` had focus bounces
      focus back to `pad` so the next dictation / hotkey send lands on
      a visible target. Reinforces the binary: AI on = two panes; AI
      off = single-pane scratchpad.
- [ ] Smoke-test: fresh `localStorage`, dictate three phrases, confirm
      no `/transform` POSTs in DevTools Network panel and only the
      Dictated pane is visible. Then check the box: `pad-out` appears,
      dictate, confirm one POST per utterance and the cleaned text
      lands in `pad-out`. Uncheck mid-flight: `pad-out` disappears and
      the in-flight request is cancelled in the Network panel.

</details>

<details open>
<summary><h3 style="display:inline">1.1 Prompt files (one Markdown file per prompt)</h3></summary>

- [x] Author `prompts/default.md` as the canonical "fix dictation noise"
      system prompt (the file body *is* the system message; no JSON,
      no front matter, no escaping).
- [ ] Ship a small starter set of additional `.md` files alongside it
      so the dropdown isn't a list of one on first run
      (e.g. `shell-command.md`, `bullet-list.md`, `polite-email.md`,
      `amp-prompt.md`).
- [ ] `install.sh` symlinks the repo's `prompts/` dir →
      `~/.config/voiceitt-bridge/prompts/` (idempotent, same convention
      already used for `bridge/dictate.html` and the Raycast scripts).
      User-added `.md` files in that directory survive re-installs;
      user edits to `default.md` (if they un-symlinked it) are never
      overwritten.
- [ ] **No `prompts.json`**, no top-level schema version, no `jq`-based
      lookup. Prompt id = filename (e.g. `default.md`); display label =
      filename minus `.md`, with `-`/`_` → spaces, title-cased
      (`polite-email.md` → `Polite email`).
- [ ] **No per-prompt `provider`/`model` in v1.** Project-wide defaults
      come from `$VOICEITT_PROVIDER` (default `anthropic`) and
      `$VOICEITT_MODEL` (default `claude-haiku-4-5`). Per-prompt
      overrides via optional YAML front matter are a planned follow-up,
      not v1.
- [x] ~~Decide v1 first-load default: select `default.md` (most users
      benefit) vs the synthesised `Off — paste as dictated` entry
      (surprise-free). Recommend `Off`; record the call here when made.~~
      *Subsumed by §1.0: the master toggle is the surprise-free default
      (off). When the toggle is on, the picker can default to
      `default.md` without revisiting this question.*

</details>

<details open>
<summary><h3 style="display:inline">1.2 Scratchpad picker UI</h3></summary>

- [ ] Add `<select id="prompt-picker">` to `bridge/dictate.html` header,
      between the title and the Clear button.
- [ ] Populate options at page load from a `GET /prompts/` directory
      listing served by the local bridge server (one option per `.md`
      file). Display label derived from filename per §1.1.
- [-] ~~First option is always the synthesised **`Off — paste as
      dictated`** (not a file on disk; the picker prepends it).~~
      *Superseded by §1.0's master toggle. The picker only lists real
      `.md` files; turning the LLM off entirely is what the toggle is
      for.*
- [ ] Persist current selection (filename, or the literal string `off`)
      to `localStorage` so it survives reloads.
- [ ] On change, write the chosen filename (or `off`) to
      `~/.config/voiceitt-bridge/active-prompt` via a small
      `POST /active-prompt` endpoint added to the local bridge server.
- [ ] Add a `↻ Re-run` button next to the picker; enabled iff
      `inputField.value !== lastInputSentToLLM`.
- [ ] Bind `⌘↵` (while the input field is focused) to the same action as
      the Re-run button.

</details>

<details open>
<summary><h3 style="display:inline">1.3 Trigger logic in `bridge/dictate.html`</h3></summary>

- [x] **Auto-trigger:** latch a `voiceittWriting` flag on any
      synthetic (`isTrusted: false`) `paste` event on the input field
      (capture phase); consume on the next `input` event; debounce
      ~700 ms before firing the transform. (Captures the
      `execCommand('insertHTML')` Voiceitt signature documented in
      ROADMAP §1 "Trigger mechanics".)
- [~] **Manual trigger:** `⌘↵` shipped (force-fires the transform
      bypassing the `lastInputSentToLLM` gate). The visible "↻ Re-run"
      button is part of §1.2 (picker UI) and lands with that.
- [x] After every successful transform, set
      `lastInputSentToLLM = inputField.value` so a future Re-run button
      gates correctly.
- [x] Editing the **output** field directly is allowed (output becomes
      editable here, removing the `readonly` from §0.5.1) and does **not**
      affect `lastInputSentToLLM`.
- [-] When the active prompt is `off`, the transform function is
      identity (`output = input`); no special-casing needed elsewhere.
      *Deferred to §1.2 (picker). MVP has no picker yet, so the only
      "off" path today is the fail-open one when the server-side call
      errors — which writes the raw input into the output pane and
      flags `fail-open: raw` in the header status indicator.*

</details>

<details open>
<summary><h3 style="display:inline">1.4 Local server endpoint for picker → CLI handoff</h3></summary>

- [x] Replace `python3 -m http.server` with `bridge/serve.py`
      (a `SimpleHTTPRequestHandler` subclass on `ThreadingHTTPServer`,
      ~100 lines of stdlib Python). Symlinked into
      `~/.config/voiceitt-bridge/` by `install.sh`; launched by
      `scripts/open-voiceitt.sh` instead of `python3 -m http.server`.
- [x] `POST /transform` with body `{ "text": "..." }` shells out to
      `voiceitt-transform`, returns the cleaned text as
      `text/plain; charset=utf-8`. Hard outer timeout from
      `$VOICEITT_TRANSFORM_HARD_TIMEOUT` (default 10 s); any non-2xx
      makes the page fail-open with raw input. (Shipped ahead of the
      picker because §1.3's auto-trigger needs *some* transform
      endpoint to call.)
- [x] **Error surfacing contract:** on a non-zero exit from
      `voiceitt-transform`, the bridge writes the subprocess's full
      stderr — which by contract includes the upstream provider's HTTP
      status code and raw response body (or the `curl` exit code +
      stderr on transport failure) — verbatim to `server.log`. The
      HTTP response back to the page stays a single-line 502 so the
      §1.3 fail-open behaviour is unchanged; the diagnosable detail
      lives in the log, not the wire. Stock `BaseHTTPRequestHandler`
      access/error log lines are suppressed (`log_request` /
      `log_error` overridden to no-ops) so each round-trip produces
      exactly one log entry — the rich `transform: in=… out=…` line
      on success or the multi-line failure block on error.
  - [ ] `GET /prompts/` returns a JSON array of `.md` filenames in
        `~/.config/voiceitt-bridge/prompts/` (needed by §1.2's picker).
  - [ ] `POST /active-prompt` with body `{ "id": "<filename>" }` (or
        `{ "id": "off" }`) writes that string to
        `~/.config/voiceitt-bridge/active-prompt`.
- [x] Document the chosen impl (Python `http.server` subclass) in the
      `bridge/serve.py` module docstring.
- [ ] *(Foreshadow §1.5.1):* let `POST /transform` grow to accept a
      rolling session-context buffer alongside the current text;
      don't change the wire shape in a way that requires a rewrite.

</details>

<details open>
<summary><h3 style="display:inline">1.5 Transformer CLI</h3></summary>

- [x] Create `scripts/voiceitt-transform` (bash + curl + jq).
      *Shipped as a v0 vertical slice: hardcoded "lightly clean
      dictated text" system prompt, hardcoded provider (Google AI
      Studio / Gemini 2.5 Flash). All the wiring below replaces the
      hardcoded bits with the real prompt-file pipeline.*
- [ ] Reads stdin; reads active prompt filename from
      `~/.config/voiceitt-bridge/active-prompt`, falling back to
      `default.md` if the file is missing/empty.
- [ ] If the active value is the literal `off` (or empty) → echo stdin
      unchanged, exit 0.
- [ ] Loads the system prompt by reading
      `~/.config/voiceitt-bridge/prompts/<filename>` verbatim (whole
      file body is the system message — no JSON, no front-matter
      parsing in v1). *Today the prompt is hardcoded inside the CLI;
      this item swaps that for an `.md` read.*
- [ ] Provider/model come from project-wide env vars
      `$VOICEITT_PROVIDER` (default `anthropic`) and `$VOICEITT_MODEL`
      (default `claude-haiku-4-5`). **No per-prompt overrides in v1.**
      *Today provider is hardcoded to Google; only `$VOICEITT_TRANSFORM_MODEL`
      is honoured.*
- [ ] Provider branches: `anthropic`, `openai`, `google` (AI Studio
      Gemini API), `ollama` (`http://localhost:11434`). *Only `google`
      branch exists today.*
- [x] Hard timeout via `curl --max-time "$VOICEITT_TRANSFORM_TIMEOUT"`.
      *Default is currently `6` s for standalone testing; needs to drop
      back to `~2.5` s once the send-script wrappers gain an explicit
      fail-open-to-raw-clipboard path. The page-side caller in §1.3
      already fail-opens, so server-side this can come down sooner.*
- [ ] Honour `$VOICEITT_BRIDGE_CONFIG` to override config dir (useful
      for testing). *Not needed yet — the v0 CLI has no config-dir
      reads. Add when prompt-file loading lands.*
- [ ] Document required env vars: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
      `GOOGLE_API_KEY`, `VOICEITT_BRIDGE_CONFIG`, `VOICEITT_PROVIDER`,
      `VOICEITT_MODEL`, `VOICEITT_TRANSFORM_TIMEOUT`.
- [x] `~/.config/voiceitt-bridge/env` fallback file: sourced by
      `scripts/open-voiceitt.sh` before launching `serve.py`, so the
      server (and the `voiceitt-transform` subprocess it spawns)
      inherits `GOOGLE_API_KEY` etc. even when Raycast didn't inherit
      them from the user's interactive shell. Plain `KEY=value` lines;
      gitignored. README walkthrough is still owed (§1.7).

</details>

<details open>
<summary><h3 style="display:inline">1.6 Page-side integration (the LLM POST)</h3></summary>

- [x] **Decision recorded:** the page POSTs `{ "text": "..." }` to
      `POST /transform` on the local bridge server, which shells out to
      `voiceitt-transform`. Picked over "page calls provider directly"
      so the API key stays in the shell env (`open-voiceitt.sh`
      inherits it from Raycast) and never lands in browser
      `localStorage`. The active-prompt id is **not** sent in the body
      yet — added when §1.2's picker lands and the CLI grows
      `.md`-file prompt loading (§1.5).
- [x] AbortController on every request so a fresh dictation cancels any
      in-flight transform; non-2xx responses fall open by writing the
      raw input into `pad-out` and flagging `fail-open: raw` in the
      header status indicator.
- [x] Send-scripts stay unchanged. **Caveat:** §0.5.2 (point them at
      `pad-out` instead of `pad`) is still open — until that lands the
      MVP is verifiable in-page only; the actual hotkey paste still
      grabs the raw `pad` text.

</details>

<details open>
<summary><h3 style="display:inline">1.7 README</h3></summary>

- [ ] New top-level section: **Optional: AI transformation before paste**.
- [ ] Picker screenshot.
- [ ] Env-var setup walkthrough (per provider), including
      `VOICEITT_PROVIDER` / `VOICEITT_MODEL` for choosing the
      project-wide default model.
- [ ] "Adding a new prompt" walkthrough: drop a new `.md` file into
      `prompts/`, save, reload the scratchpad tab. No JSON, no
      restart.
- [ ] Note that editing `prompts/default.md` (in place) is how the
      default "fix dictation noise" prompt is changed — the symlink
      means the file the user edits *is* the file the transformer
      reads.

</details>

<details open>
<summary><h3 style="display:inline">1.8 Out of scope for v1 (explicit)</h3></summary>

- [-] Streaming insertion (one round-trip, one paste).
- [-] Screen / clipboard context capture beyond the dictated text.
- [-] In-app prompt editor (post-v1; pairs with SQLite migration).
- [-] Per-destination prompt defaults (post-v1; layer on top of picker).
- [-] History / undo of dictated → transformed pairs.
- [-] "Hey AI, …" ad-hoc command syntax (deferred; picker covers ~90%).
- [-] Per-prompt `provider` / `model` overrides via YAML front matter
      (deferred; v1 uses project-wide `$VOICEITT_PROVIDER` /
      `$VOICEITT_MODEL` for everything).
- [-] SQLite-backed prompt store (deferred; "directory of `.md` files"
      is the v1 contract, and the migration is contained because the
      rest of the system only ever sees "give me the active prompt's
      system text").

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">1.5 Session context + learned-corrections memory (extension of §1)</h2></summary>

Goal: lift the LLM rewrite quality (§1) above what stateless,
single-utterance prompting can do — *without* changing Voiceitt's own
recogniser, which we don't control. Two mechanisms, A then B.

<details open>
<summary><h3 style="display:inline">1.5.1 Mechanism A — rolling session context</h3></summary>

- [ ] In `bridge/dictate.html`, keep an in-memory ring buffer of the last
      5 `(input, output)` pairs for the current session (cleared on
      reload or on prompt-picker change).
- [ ] On every transform request, POST the ring buffer alongside the
      current utterance (means §1.4's `POST /active-prompt` endpoint
      grows into a general `POST /transform` request handler).
- [ ] In `voiceitt-transform`, prepend a "Recent dictation in this
      session, for disambiguation only — do not repeat or summarise"
      block to the user message; cap at 800 tokens of context (5
      utterances *or* 800 tokens, whichever first).
- [ ] Add a `?context=0` query-string flag to the page that disables
      the context block, for quick A/B against the stateless baseline.
- [ ] Verify on a real session: dictate a project name (e.g.
      `Voiceitt`), correct it once in the input field, confirm the next
      utterance keeps the corrected capitalisation without further help.

</details>

<details open>
<summary><h3 style="display:inline">1.5.2 Mechanism B — learned-corrections memory</h3></summary>

- [ ] Define `~/.config/voiceitt-bridge/corrections.jsonl` schema:
      `{ts, prompt_id, voiceitt_raw, llm_output, user_final}` per line.
- [ ] In each `send-to-*.sh`, at the moment the hotkey actually fires,
      compare `lastInputSentToLLM` / `lastLLMOutput` (read from the
      page via a small endpoint) to the live input/output field
      contents; if non-trivially different, append a JSONL row.
- [ ] In `voiceitt-transform`, after loading the prompt, scan the JSONL
      for rows whose `voiceitt_raw` shares a changed-substring of
      length ≥ 4 with the current utterance; pick top-K most-recent
      (K = 4) and inject as few-shot examples in the system prompt.
- [ ] Cap added context: K × ~80 tokens ≈ 320 tokens, on top of A's
      800 → ~1.1k total context budget per call.
- [ ] **Forget-affordance:** ship in the same PR as B itself — either a
      `scripts/voiceitt-corrections` CLI with a `forget <substring>`
      subcommand, or a "delete last correction" button in the
      scratchpad header. Non-negotiable.
- [ ] Privacy README: explicit note that `corrections.jsonl` is a
      personal dictation log, never leaves the machine, and is excluded
      from any future sync story without explicit opt-in.

</details>

<details open>
<summary><h3 style="display:inline">1.5.3 Sequencing</h3></summary>

- [ ] Ship 1.5.1 (Mechanism A) on its own; live on it for ≥ 1 week.
- [ ] Re-evaluate whether 1.5.2 is worth building based on what A
      *fails* to absorb in real use (i.e. recurring corrections that
      keep falling out of the rolling window).
- [ ] Only then ship 1.5.2 + the forget-affordance + privacy README in
      one PR.

</details>

<details open>
<summary><h3 style="display:inline">1.5.4 Out of scope (explicit)</h3></summary>

- [-] Fine-tuning a custom Voiceitt or LLM model on the corpus (real
      ML pipeline, far outside this project).
- [-] Cross-machine / cross-user sharing of the corrections corpus.
- [-] Embedding-based retrieval for B (substring match until proven
      insufficient).
- [-] Feeding corrections back into Voiceitt itself (no API hook
      exists from where we sit).

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">2. Per-target scripts via a generator</h2></summary>

Goal: graduate §0's minimal `new-shortcut.sh` into a real generator
with strategy templates and bundle-id auto-detection.

<details open>
<summary><h3 style="display:inline">2.1 Refactor</h3></summary>

- [ ] Extract shared "copy from focused app via cliclick + sentinel"
      preamble into `scripts/lib/copy-focused.sh`.
- [ ] Update existing `send-to-iterm*.sh` and the §0
      `send-to-vscode.sh` to source the lib.

</details>

<details open>
<summary><h3 style="display:inline">2.2 Templates</h3></summary>

- [ ] `templates/send-applescript.sh.tmpl` for AppleScript-capable apps.
- [ ] `templates/send-cliclick-paste.sh.tmpl` for everything else.
- [ ] `templates/send-cliclick-paste-run.sh.tmpl` for the `& Run` variant.
- [ ] Hand-curated AppleScript bodies for iTerm, Terminal, Chrome, Safari.

</details>

<details open>
<summary><h3 style="display:inline">2.3 Generator: `scripts/new-target.sh`</h3></summary>

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

</details>

<details open>
<summary><h3 style="display:inline">2.4 Docs & risks</h3></summary>

- [ ] README: "Adding a new target" section (supersedes §0.2's manual flow).
- [ ] Document Secure Input mode bail-out.
- [ ] Document focus-into-text-field caveat for `cliclick-paste` strategy.

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">3. Raycast Store extension</h2></summary>

Goal: ship a TypeScript Raycast extension to the store.

<details open>
<summary><h3 style="display:inline">3.1 Scaffold</h3></summary>

- [ ] `npm create raycast-extension@latest`; pick "no view" default.
- [ ] Declare four commands in `package.json`.

</details>

<details open>
<summary><h3 style="display:inline">3.2 Command ports</h3></summary>

- [ ] Port `open-voiceitt`: spawn local HTTP server, write scratchpad to
      `environment.supportPath`, open Chrome via `runAppleScript`,
      detect already-running via PID file.
- [ ] Port `send-to-iterm` and `send-to-iterm-and-run` using
      `runAppleScript` + `cliclick` shell-out.
- [ ] Port `back-to-voiceitt` (straight `runAppleScript`).
- [ ] Port multi-target generator from §2 as a TS dispatcher + `<List>` UI.

</details>

<details open>
<summary><h3 style="display:inline">3.3 Preferences</h3></summary>

- [ ] Expose port, scratchpad title, `cliclick` path as Raycast preferences.

</details>

<details open>
<summary><h3 style="display:inline">3.4 Polish</h3></summary>

- [ ] 512×512 extension icon.
- [ ] At least one screenshot per command.
- [ ] Raycast-tone README.
- [ ] `CHANGELOG.md` entry.
- [ ] Permissions note (Accessibility + `cliclick` install).

</details>

<details open>
<summary><h3 style="display:inline">3.5 Submission</h3></summary>

- [ ] `npm run publish`.
- [ ] Address reviewer feedback rounds.
- [ ] Listed on Raycast Store.

</details>

</details>

---

<details open>
<summary><h2 style="display:inline">Cross-cutting / housekeeping</h2></summary>

- [ ] Keep this ERD in sync with ROADMAP.md whenever a roadmap section
      gains/loses scope.
- [ ] On every shortcut PR, update the relevant 0.x / 2.x checkbox.
- [ ] Periodic sweep: convert any `[~]` items older than two weeks back
      to `[ ]` with a note about what blocked them.

</details>
