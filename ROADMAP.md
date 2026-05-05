# Roadmap

## History

The idea of a "bridge" originally came out of my work trying to make Voiceitt just another LLM [VoiceInk](https://github.com/Beingpax/VoiceInk) could use as a transcription backend. I've successfully built a [working prototype](https://github.com/dmclark/VoiceInk). The issue is that API consumption is too high to be fiscally viable.

This approach is to provide the same functionality without the API. We are serving a page locally (the extension does not work on local files), essentially replacing [https://web.voiceitt.com/dictate] with a local page so that we can add keyboard shortcuts to send the text to local apps..`

## Future work

Three larger pieces of work that the current toolkit doesn't yet cover. All
are deliberately out of scope for the first version — this doc is the plan for
"phase two" once the basic iTerm bridge has shaken out in daily use.

---

## 0. Adding a new shortcut/target (do this first)

**Priority: next up.** Before any of the larger items below, the workflow for
**adding a new `send-to-<app>` shortcut** needs to be a documented, repeatable
process — not a copy-paste-and-edit improv session against
`scripts/send-to-iterm.sh`. The first concrete trial of this is **adding a
shortcut for VS Code** (manually, end-to-end), with the steps captured as we
go so the next target after that is faster and more obvious.

This is a deliberate stepping stone toward the generator described in §2:
we want one or two real, hand-built `send-to-*` scripts to exist (and be in
daily use) before we try to template them. Otherwise the templates encode
guesses instead of what actually worked.

### Goals

1. **A user-facing "Add a new shortcut" section in the README** that walks
   through the whole loop in order: pick a target app, find its bundle id,
   copy the closest existing `send-to-*.sh`, edit the destination block,
   `chmod +x`, symlink into Raycast's scripts dir, assign a hotkey, accept
   the macOS Accessibility/automation permission prompts on first trigger,
   verify with a Sticky-Keys-on dictation.
2. **A first hand-built non-iTerm shortcut: `send-to-vscode.sh`.** Manually
   authored from `send-to-iterm.sh`, using the `cliclick`-paste strategy
   (VS Code has no useful AppleScript dictionary for "paste into the active
   editor"). Treat this as the prototype the generator will later mimic.
3. **A small helper script `scripts/new-shortcut.sh`** that automates the
   mechanical parts of step 1 — slugify the target name, stamp out a new
   `send-to-<slug>.sh` from a chosen base script, fill in the bundle id and
   Raycast headers, `chmod +x`, and create the Raycast symlink. This is the
   *minimum* generator: no templates, no strategy picker, just "clone this
   existing script, rename it, point it at this app." The richer generator
   from §2 supersedes it later.

### Concrete plan

| Step | Task | Notes |
| ---- | ---- | ----- |
| 1 | Manually add `scripts/send-to-vscode.sh` by copying `send-to-iterm.sh` and replacing the iTerm AppleScript block with a `cliclick`-based activate + Cmd+V into VS Code (`com.microsoft.VSCode`). | Captures the real-world friction the README + helper script need to address. |
| 2 | Write the **README "Adding a new shortcut" section** based on what step 1 actually required — including how to find a bundle id (`osascript -e 'id of app "Visual Studio Code"'` or `lsappinfo`), and which permission prompts to expect on first run. | The doc is the deliverable, not a side-effect. |
| 3 | Build `scripts/new-shortcut.sh`: a Raycast Script Command (or plain CLI) that takes `--name`, `--bundle-id`, and `--base` (defaults to `send-to-iterm.sh`), and produces a renamed, header-rewritten copy in `scripts/` plus the Raycast symlink. | One template, one substitution pass. No strategy picker yet. |
| 4 | Verify the loop end-to-end: run `new-shortcut.sh --name "Notes" --bundle-id com.apple.Notes`, assign a hotkey in Raycast, dictate, send. Note any manual edits still required and feed them back into step 3. | This is what tells us the helper is "good enough." |
| 5 | Cross-link from §2 ("Per-target scripts via a generator") back to this section, so the generator work picks up where the manual helper leaves off instead of starting from scratch. | Avoids re-litigating the design later. |

### Why a small helper now, instead of jumping straight to §2's generator

- §2's generator wants strategy templates (`applescript` vs.
  `cliclick-paste`), bundle-id auto-detection, optional `&-and-run`
  companions, and per-app submit-key defaults. That's a lot of design to
  commit to before we've added a *single* non-iTerm target by hand.
- The minimum useful automation — "clone an existing script, rename
  everything, drop the symlink in" — saves 90% of the typing without
  locking in any template decisions.
- Doing VS Code manually first will surface concrete questions (does
  `cliclick`'s Cmd+V land in the right pane? does VS Code need a focus
  click first? does Sticky Keys interfere?) whose answers belong in the
  README *and* in §2's eventual templates.

### Out of scope for this item

- Multiple strategy templates (deferred to §2).
- Bundle-id auto-detection from frontmost app (deferred to §2).
- A picker UI or per-target config file (deferred to §2 / §3).
- Anything LLM-related (that's §1).

---

## 0.5. Two-pane scratchpad + a little visual polish (prep for §1)

**Priority: do this before §1.** The scratchpad is currently a single
`<textarea>` that gets dictated into and then Cmd+A/Cmd+C'd straight onto
the clipboard. As soon as we add the AI transformation pass from §1, that
single field stops being enough: the user needs to see *both* what they
actually said and what the model is about to paste, so they can sanity-check
the rewrite before it lands in the destination app. Splitting the pane now
— while there's still no LLM in the loop — lets us land the visual change
on its own and keeps §1 a pure "wire up the transform" change.

While we're in there, the page is also a bit utilitarian. A small,
deliberate font + spacing pass costs almost nothing and makes the tool feel
like something the user *wants* to leave open, which matters because it's
literally the surface they stare at while dictating.

### Goals

1. **Two stacked fields in `bridge/dictate.html`:**
   - **Top — "Dictated"**: the existing textarea. Voiceitt writes into this
     one, exactly as today. Cmd+A/Cmd+C semantics on this field are
     unchanged so the existing `send-to-*` scripts keep working with no
     edits.
   - **Bottom — "To be pasted"**: a second textarea, read-only for now (a
     light-grey placeholder like *"Will mirror the dictated text until AI
     post-processing is enabled (§1)."*). In v0.5 it just mirrors the top
     field on input; in §1 it gets replaced by the LLM output. Editable in
     §1 so the user can tweak before sending — read-only here just to keep
     the v0.5 change behaviorally inert.
2. **A header label per pane** (`Dictated` / `To be pasted`), small and
   muted, so the split is obvious without screaming.
3. **A typography pass** — see "Suggested font" below. Nothing heavy, no
   webfont sprawl, no CSS framework.
4. **Send scripts keep targeting the bottom field at send time.** In v0.5
   that's a no-op (top and bottom are identical). The change here is just
   updating `send-to-*.sh` to Cmd+A/Cmd+C the *bottom* textarea via a
   `focus()` step so §1 doesn't have to touch bash at all.

### Suggested font

**Atkinson Hyperlegible** (Braille Institute, OFL-licensed, free on Google
Fonts). Reasons:

- Designed specifically for low-vision and accessibility use cases — a
  thematic fit for a tool whose whole point is dictating instead of typing.
- Has *character* (notice the `g`, `Q`, the slashed zero) without being
  loud, so it reads as deliberate rather than default.
- Renders cleanly at the textarea's existing 22 px size on macOS and
  Chrome; doesn't need any weight tuning.
- One font file, one `@import`, no icon set, no JS.

Fallback chain stays system-native:

```css
font-family: "Atkinson Hyperlegible", -apple-system, BlinkMacSystemFont,
             "SF Pro Text", system-ui, sans-serif;
```

If we'd rather not pull in a webfont at all, **Inter** (already cached on
many machines) or just `ui-rounded` on macOS (gives SF Rounded for free,
zero download) are both fine second choices. Avoid anything display-y or
heavy (Fraunces, Space Grotesk Bold, etc.) — the page is a working
surface, not a hero section.

Other small touches in the same pass, all cheap:

- Slightly warmer background (`#fafaf7` instead of pure `#ffffff`) so the
  page reads as "scratchpad" rather than "blank document".
- `border-radius: 8px` on each pane and a thin `#e6e6e1` divider between
  them.
- Header strip stays as-is structurally but picks up the new font.

### Making the insertion point easier to find

The current textarea uses the OS default caret: a 1-px black line that
blinks 60 times a minute and gets lost the instant you look away. This is
a real problem for a dictation surface — when you look back to see what
Voiceitt produced, you want your eye to land on the caret in well under a
second. A few low-cost CSS-only fixes, in increasing order of intrusiveness:

1. **High-contrast caret colour.** One line:
   ```css
   textarea { caret-color: #ff3b30; }   /* macOS system red */
   ```
   This alone is the single biggest win — a saturated red 1-px caret on a
   warm-white page is *much* easier to spot than the default black one,
   even peripherally. Doesn't affect text colour, doesn't affect selection.
2. **Make the caret physically taller and a hair thicker by bumping the
   font size on the focused pane.** The caret height is the line-height of
   the focused run of text; nothing else controls it. Going from 22 px →
   26 px on the active textarea (and back to 22 px on the inactive one)
   gives a noticeably chunkier caret without any custom rendering. Pair
   with `transition: font-size 80ms ease;` so it doesn't feel jarring.
3. **A "current line" highlight.** When a textarea is focused, paint the
   line containing the caret with a faint band (`background:
   linear-gradient(...)` driven by JS that watches `selectionStart` and
   the computed line-height, or just `box-shadow: inset 0 0 0 9999px
   rgba(255,235,150,0.18)` on `:focus` for the whole field as a cheap
   stand-in). The cheap version — tinting the *whole focused field* — is
   a one-line CSS change and already makes "which pane has the caret"
   obvious; the per-line version is a follow-up if it's still not enough.
4. **Pulse on focus / on caret-jump.** When the field gains focus or the
   caret moves after being idle for >2 s, briefly (300 ms) animate a
   `box-shadow` ring at the caret's location, or just flash the whole
   focused pane's border from `#e6e6e1` → `#ff3b30` → back. Effectively a
   "where did I leave off?" beacon. Implement with a small JS helper that
   listens to `selectionchange` and `focus`.
5. **Custom faux-caret (only if 1–4 still aren't enough).** Hide the
   native caret with `caret-color: transparent` and overlay a `<div>`
   positioned from `selectionStart` via a hidden mirror element — this is
   how CodeMirror / Monaco / Slate do it. Lets us draw a 3 px-wide,
   high-contrast, optionally non-blinking bar. It's the "real" fix but
   involves a mirror-textarea trick and ~50 lines of JS, so reserve it for
   if 1–4 don't move the needle.

Recommended starting point for v0.5: ship **(1) + (2) + the cheap (3)
focused-pane tint** in the same diff. They're collectively ~10 lines of
CSS and one `:focus` selector, and together they answer "which pane am I
in?" and "where in that pane is my caret?" without any JS. Save (4) and
(5) for if those three aren't enough once they're in daily use.

### Concrete plan

| Step | Task | Notes |
| ---- | ---- | ----- |
| 1 | Refactor `bridge/dictate.html` to two stacked textareas in a flex column, with `Dictated` / `To be pasted` mini-labels above each. Keep `id="pad"` on the top one for backwards compat with any existing wiring. | Pure HTML/CSS change. |
| 2 | Add an `input` listener on the top textarea that mirrors its value into the bottom one. This is the v0.5 stand-in for §1's transform. | One line of JS. |
| 3 | Drop in the Atkinson Hyperlegible `@import` (or vendor a single woff2 into `bridge/` if we'd rather not hit Google Fonts), apply the font + warmer background + rounded panes. | Visual only. |
| 4 | Update `send-to-iterm.sh` (and `-and-run`) to focus the *bottom* textarea before the Cmd+A/Cmd+C step — the simplest way is to give the bottom field a known `id` (e.g. `pad-out`) and have the script trigger a `focus()` via the existing AppleScript-driving-Chrome path, *or* just have the page itself keep focus on the bottom field whenever its contents change. Pick whichever is less invasive. | Behaviorally a no-op in v0.5 because top and bottom are identical. Sets §1 up to need zero bash changes. |
| 5 | Smoke-test: dictate into the top pane, confirm the bottom pane mirrors live, confirm `Send to iTerm` still pastes the right text. Confirm Sticky Keys behavior is unchanged. | Same manual test as today. |

### Out of scope for this item

- Any LLM call (that's §1).
- Making the bottom pane editable (deferred to §1, where editing it
  actually means something).
- A prompt picker (§1).
- A diff view between the two panes (nice idea, but premature until we
  have an LLM rewriting the bottom one).

---

## 1. AI post-processing

### Inspiration
 VoiceInk's killer feature isn't
the transcription — it's the **post-transcription enhancement stage**, where
recognised text is run through an LLM (grammar fixes, formatting, custom
prompts, "Hey AI" commands) before being inserted at the cursor. That stage
is what makes dictated text feel *typed* rather than *spoken*, and it's
notably absent from Voiceitt's own pipeline.

The bridge is the obvious place to bolt the same idea on for Voiceitt
users: we already have a clipboard intercept point between Voiceitt's
scratchpad and the destination app, and that's exactly where VoiceInk's
enhancement stage sits relative to its own active-element write path.

**Status:** exploration / not implemented.

### The idea

Today the bridge is mechanical: Voiceitt produces text in the scratchpad,
the `send-to-*` script Cmd+A/Cmd+C's it onto the clipboard, then
AppleScripts (or pastes) it into the destination verbatim. We never look at
what the user said.

The proposal — building on §0.5's two-pane layout — is to insert an
**LLM transformation pass between the input field (top, where Voiceitt
writes) and the output field (bottom, what `send-to-*` actually
copies)**, parameterised by **which prompt the user picked** (e.g. "fix
dictation noise", "format as bullet list", "translate to Spanish",
"rewrite as a polite email", "leave it alone"). The same selected
prompt is used regardless of which `send-to-*` hotkey ultimately fires;
the destination is incidental.

The crucial reframing: **the transform belongs to the input→output
transition, not to the output→clipboard one.** It runs *as soon as
Voiceitt finishes a phrase*, not when the user hits a hotkey. By the
time any `send-to-*` fires, the rewritten text is already sitting in
the output field, ready to be Cmd+A/Cmd+C'd. The hotkey-side bash is
**unchanged from §0.5** — it already targets the output field — so all
of §1's work lives in the page.

```diagram
                  Today                                    Proposed
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  Voiceitt textarea       │             │  Input field (top)       │
  │                          │             │  written by Voiceitt     │
  ╰─────────────┬────────────╯             ╰─────────────┬────────────╯
                │ Cmd+A / Cmd+C                          │ on Voiceitt insert
                ▼                                        ▼
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  macOS clipboard (raw)   │             │  LLM transformation pass │
  ╰─────────────┬────────────╯             │  prompt = picker value   │
                │                          ╰─────────────┬────────────╯
                │                                        │
                │                                        ▼
                │                          ╭──────────────────────────╮
                │                          │  Output field (bottom)   │
                │                          │  user can edit / re-run  │
                │                          ╰─────────────┬────────────╯
                │                                        │ Cmd+A / Cmd+C
                │                                        │ (unchanged from §0.5)
                │                                        ▼
                │                          ╭──────────────────────────╮
                │                          │  macOS clipboard         │
                │                          ╰─────────────┬────────────╯
                ▼                                        ▼
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  Destination (verbatim)  │             │  Destination (transformed)│
  ╰──────────────────────────╯             ╰──────────────────────────╯
```

### Trigger mechanics (investigated)

Before designing the picker / config / API call, we needed to know *when*
the LLM transform should fire. A short DevTools probe in
`bridge/dictate.html` (now removed) logged every event and `value`-setter
call on the `#pad` textarea while dictating into it. The findings:

- **Voiceitt writes via `document.execCommand('insertHTML', …)`.** Its
  content script (`handleRecognisedText.*.js`) literally logs `>>>
  execCommand insertHTML "…"` for each recognised phrase.
- **Each utterance = exactly one trusted `input` event**, carrying the
  full phrase as a single delta (e.g. `Δ=+51` for a 51-char sentence).
  Voiceitt waits for the user to pause, decides "this phrase is final",
  then commits the whole thing in one go. There are no per-word partials,
  no progressive updates, and no IME `compositionstart` /
  `compositionend` pair.
- **The `inputType` on the trusted event is empty** (`''`), because
  that's how Chrome reports `execCommand('insertHTML')`. The preceding
  synthetic `beforeinput` does carry `inputType: 'insertFromPaste'` but
  is `isTrusted: false`. So `isTrusted` alone *cannot* distinguish
  Voiceitt's writes from real keystrokes (both end-of-chain `input`
  events are trusted). The Voiceitt signature is the *preceding*
  synthetic `paste` ClipboardEvent (`isTrusted: false`).
- **No direct `pad.value = …` assignments.** A patched
  `HTMLTextAreaElement.prototype` value setter never fired, so we don't
  need to ship that patch in production.
- **`MutationObserver` is silent** on textarea value changes (as
  expected — textarea content isn't in the DOM tree). Confirms there's
  no observer-based fallback to fall back *to*.
- Voiceitt itself reads `pad.value` via a `getPrevText` helper to
  maintain its own `previousInsertedText` (that's how it knows whether
  to prepend a space). Useful context but not something we need to act
  on.

#### Two triggers, deliberately different rules

Manual edits to the input field (typing, paste from another app, hand
fixes to a misrecognised word) **must not** auto-fire the LLM. The
whole point of editing the input field by hand is usually to correct a
recognition error the model would otherwise paper over (or get wrong
twice). Forcing an explicit user action for hand edits keeps the user
in charge of when — and whether — to round-trip a manual change through
the model.

That gives us two triggers with different mechanics:

**1. Auto-trigger: Voiceitt insertions only.** Latch a flag whenever a
synthetic (`isTrusted: false`) `paste` event hits the input field, then
consume it on the very next `input`:

```js
let voiceittWriting = false;
inputField.addEventListener('paste', (e) => {
  if (!e.isTrusted) voiceittWriting = true;       // Voiceitt's signature
}, true);
inputField.addEventListener('input', () => {
  if (!voiceittWriting) return;                    // ignore real typing
  voiceittWriting = false;
  scheduleTransform();                              // debounce ~700 ms
});
```

The debounce coalesces multi-utterance bursts ("Let me try this again."
*pause* "I am not sure if it will work.") into a single LLM call. After
it fires, the result is written into the output field and we record
`lastInputSentToLLM = inputField.value`.

**2. Manual trigger: a "Re-run through LLM" button** in the header,
next to the prompt picker and Clear:

```diagram
╭───────────────────────────────────────────────────────────────────────╮
│ Voiceitt Scratchpad   [Prompt: Fix dictation ▼]  [↻ Re-run]  [Clear] │
╰───────────────────────────────────────────────────────────────────────╯
```

- **Enabled iff** `inputField.value !== lastInputSentToLLM`. So the
  button lights up the moment the user types into (or otherwise edits)
  the input field, and goes dark again as soon as any transform
  completes.
- **Click semantics:** identical to the auto-trigger's debounced fire —
  send the current input through the LLM, write into the output field,
  update `lastInputSentToLLM`.
- **Keyboard shortcut:** `⌘↵` while the input field is focused is the
  obvious binding — same gesture as "submit this draft" in most apps.

Editing the **output** field directly is allowed (the field becomes
editable in §1, per §0.5) and **does not** affect the Re-run button or
`lastInputSentToLLM`. Once you're hand-tweaking the output, you're
past the model.

The "Off — paste as dictated" prompt is then implemented trivially:
the transform function is identity (`output = input`), so the auto and
manual paths both just mirror. No special-casing the send scripts and
no special-casing the trigger logic.

### Why per-prompt, not per-destination

A first pass tied prompts to the destination ("if going to iTerm, clean
shell noise; if going to Slack, soften tone"). On reflection that's the
wrong axis:

- The *same* destination can want very different transformations from one
  send to the next. Sending to iTerm might be a literal command one minute
  and a paragraph of context for an Amp prompt the next.
- The user has the intent in their head *while dictating*, before they
  even pick a hotkey. Letting them pick the prompt at dictation time —
  next to the textarea they're already looking at — matches that
  workflow.
- Per-destination defaults can still be layered on later (the picker can
  remember "last prompt used for Send to Slack"), but the primary control
  belongs to the user, not the script.

### The prompt picker

A `<select>` in the scratchpad header, next to the Clear button:

```
╭──────────────────────────────────────────────────────────────────╮
│ Voiceitt Scratchpad   [Prompt: Fix dictation ▼]   [Clear (⌘K)]   │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  (textarea)                                                      │
│                                                                  │
╰──────────────────────────────────────────────────────────────────╯
```

Behavior:

- Options are loaded at page open from a config file (see below).
- The first option is always **`Off — paste as dictated`**, so the user
  can opt out without uninstalling anything.
- The current selection is persisted to `localStorage` so it survives
  page reloads.
- Changing the selection writes the chosen prompt id to a sidecar file
  (`~/.config/voiceitt-bridge/active-prompt`) that the `send-to-*`
  scripts read at send time. Filesystem because: no extra server
  endpoint, trivially debuggable, plays nice with bash.

A keyboard shortcut (e.g. `⌘1`–`⌘9`) to jump straight to a numbered
prompt is an obvious follow-up but not needed for v1.

### Config file (v1)

JSON in `~/.config/voiceitt-bridge/prompts.json`. Easy for the scratchpad
to `fetch('/prompts.json')` from the local server, easy for bash to read
with `jq`, no extra dependencies.

```json
{
  "default": "fix-dictation",
  "prompts": [
    {
      "id": "off",
      "label": "Off — paste as dictated",
      "provider": "off"
    },
    {
      "id": "fix-dictation",
      "label": "Fix dictation noise",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "system": "Lightly clean dictated text. Remove disfluencies (um, uh, false starts, restarts). Fix obvious capitalisation and punctuation. Do not change wording, do not add information, do not summarise. Output only the cleaned text."
    },
    {
      "id": "shell-command",
      "label": "Shell command",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "system": "Convert dictated text into a single shell command. Output ONLY the command, no commentary, no markdown fences, no trailing newline. If already a valid command, return unchanged."
    },
    {
      "id": "amp-prompt",
      "label": "Amp / coding-assistant prompt",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "system": "Clean a dictated coding-assistant prompt. Remove disfluencies, keep the user's intent, tone, and any specific names or paths they mentioned. Do not add information. Output only the cleaned prompt."
    },
    {
      "id": "bullet-list",
      "label": "Reformat as bullet list",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "system": "Restructure the user's dictated text as a Markdown bullet list. Preserve their wording where possible; do not invent points."
    },
    {
      "id": "polite-email",
      "label": "Polite email tone",
      "provider": "anthropic",
      "model": "claude-haiku-4-5",
      "system": "Rewrite the user's dictated text as a polite, concise email body. Keep their facts and intent. No greeting or sign-off."
    },
    {
      "id": "gemini-rewrite",
      "label": "Heavy rewrite (Gemini 2.5 Pro)",
      "provider": "google",
      "model": "gemini-2.5-pro",
      "system": "Rewrite the user's dictated text into clear, well-structured prose. Preserve all facts and intent. Do not add information."
    }
  ]
}
```

A starter version of this file ships in `bridge/prompts.default.json` and
`install.sh` copies it into `~/.config/voiceitt-bridge/prompts.json` on
first run (and never overwrites on subsequent runs, so user edits stick).

The canonical text for the default `fix-dictation` system prompt lives in
[`prompts/default.md`](./prompts/default.md) — that file is the
human-editable source of truth, and its contents are what gets inlined as
the `system` field of the default prompt entry in `bridge/prompts.default.json`
(and, on first install, in the user's `prompts.json`). Keeping the prose in
its own Markdown file means it can be edited and reviewed without wading
through JSON escaping, and the build/install step is responsible for
folding it back into the JSON.

Editing is just "open the JSON file in your editor" (or, for the default
prompt, edit `prompts/default.md` and re-seed). No UI for v1. The
scratchpad reloads its picker on every page open, so the workflow is:
edit → reload tab → new prompts in the dropdown.

### SQLite — when, not if

JSON is the right v1. Reasons we'd graduate to SQLite later:

- Per-prompt usage stats (which prompts get used / abandoned).
- History of dictated → transformed pairs, for debugging and "undo".
- Per-destination prompt defaults ("when sending to Slack, default the
  picker to *polite-email*").
- Multi-machine sync via Litestream / a shared file.
- An in-app prompt editor that needs transactional writes.

None of that is on the v1 path. The interface the rest of the system sees
is "give me the active prompt's `system` text and `provider` info"; that
contract works the same whether the backing store is JSON or SQLite, so
the migration is contained.

### Where the call goes

The cleanest insertion point in each `send-to-*.sh` is right after the
existing "copy actually fired" sentinel check and before the AppleScript
paste. Pulling the relevant lines out of `scripts/send-to-iterm.sh`:

```bash
# 5b) Run text through the active prompt's LLM transformation.
if command -v voiceitt-transform >/dev/null 2>&1; then
  TRANSFORMED=$(printf '%s' "$CURRENT" | voiceitt-transform) || TRANSFORMED="$CURRENT"
  printf '%s' "$TRANSFORMED" | pbcopy
fi
```

Properties this gives us:

- **Destination-agnostic.** The same shim drops into every `send-to-*.sh`
  the per-target generator from §2 produces. No per-script prompt logic.
- **Opt-in.** If `voiceitt-transform` isn't on `$PATH`, the script
  behaves identically to today.
- **Fail-open.** Any non-zero exit from the transformer falls back to
  raw text. A network blip never blocks a paste.
- **Picker-driven.** The transformer reads
  `~/.config/voiceitt-bridge/active-prompt` to know which prompt id to
  load from `prompts.json`. If the active prompt is `off`, it exits
  immediately with the input unchanged.
- **Existing Sticky-Keys preamble unchanged.** The transformer only
  sees text that already passed the "copy actually fired" check.

### What `voiceitt-transform` is

A tiny CLI (~60 lines of bash + `curl` + `jq`). Reads stdin, looks up the
active prompt in `prompts.json`, posts to the chosen provider, prints
transformed text on stdout.

```bash
#!/bin/bash
# voiceitt-transform — read stdin, write transformed text to stdout.
set -e

CONFIG_DIR="${VOICEITT_BRIDGE_CONFIG:-$HOME/.config/voiceitt-bridge}"
PROMPTS_FILE="$CONFIG_DIR/prompts.json"
ACTIVE_FILE="$CONFIG_DIR/active-prompt"

INPUT=$(cat)
PROMPT_ID="$(cat "$ACTIVE_FILE" 2>/dev/null || jq -r .default "$PROMPTS_FILE")"
PROMPT_JSON="$(jq --arg id "$PROMPT_ID" '.prompts[] | select(.id == $id)' "$PROMPTS_FILE")"

PROVIDER="$(jq -r .provider <<<"$PROMPT_JSON")"
case "$PROVIDER" in
  off|"") printf '%s' "$INPUT"; exit 0 ;;
esac

SYSTEM="$(jq -r .system <<<"$PROMPT_JSON")"
MODEL="$(jq -r .model <<<"$PROMPT_JSON")"
TIMEOUT="${VOICEITT_TRANSFORM_TIMEOUT:-2.5}"

case "$PROVIDER" in
  anthropic)
    curl -sS --max-time "$TIMEOUT" https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d "$(jq -n --arg s "$SYSTEM" --arg u "$INPUT" --arg m "$MODEL" \
            '{model:$m, max_tokens:1024, system:$s, messages:[{role:"user", content:$u}]}')" \
      | jq -r '.content[0].text'
    ;;
  openai)
    # ... analogous chat-completions call ...
    ;;
  google)
    # Google AI Studio (Gemini API). Same key works for personal AI Studio
    # accounts as for paid Vertex-style use; the v1beta endpoint accepts both.
    curl -sS --max-time "$TIMEOUT" \
      "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GOOGLE_API_KEY}" \
      -H "content-type: application/json" \
      -d "$(jq -n --arg s "$SYSTEM" --arg u "$INPUT" \
            '{system_instruction:{parts:[{text:$s}]}, contents:[{role:"user", parts:[{text:$u}]}]}')" \
      | jq -r '.candidates[0].content.parts[0].text'
    ;;
  ollama)
    curl -sS --max-time "$TIMEOUT" http://localhost:11434/api/chat \
      -d "$(jq -n --arg s "$SYSTEM" --arg u "$INPUT" --arg m "$MODEL" \
            '{model:$m, stream:false, messages:[{role:"system", content:$s},{role:"user", content:$u}]}')" \
      | jq -r '.message.content'
    ;;
esac
```

Provider/API key env conventions:

| Env var                       | Default                       | Purpose                                                                 |
| ----------------------------- | ----------------------------- | ----------------------------------------------------------------------- |
| `ANTHROPIC_API_KEY`           | (required for anthropic)      | API auth.                                                               |
| `OPENAI_API_KEY`              | (required for openai)         | API auth.                                                               |
| `GOOGLE_API_KEY`              | (required for google)         | Google AI Studio API key — get one at https://aistudio.google.com/apikey. |
| `VOICEITT_BRIDGE_CONFIG`      | `~/.config/voiceitt-bridge`   | Override config dir (useful for testing).                               |
| `VOICEITT_TRANSFORM_TIMEOUT`  | `2.5`                         | `curl --max-time`. Beyond this we fall back to raw text.                |

Note that **provider/model live in the prompt definition**, not in env
vars. That's deliberate: a "polite email" prompt may want a smarter model
than a "fix dictation" prompt, and the user is the one who knows which.

### Latency

The bridge today is snappy — hotkey to paste is well under 200ms. An LLM
round-trip is 400ms–2s depending on provider, model, and network. That's
noticeable, especially for the lightweight "fix dictation" prompt which
runs on every send.

Mitigations, in order of effort:

1. **Pick a fast small model per prompt.** Haiku, Groq Llama,
   `gemini-2.5-flash`, or local Ollama (`llama3.2:3b`) all clear the bar
   for "remove disfluencies in one short utterance". Reserve heavier
   models — `claude-sonnet-4-5`, `gpt-4o`, `gemini-2.5-pro` (the model
   used in VoiceInk via an AI Studio account) — for prose-restructuring
   prompts where the user has already accepted the latency cost by
   picking that prompt.
2. **Hard timeout + fall-open.** `--max-time 2.5`. If the API stalls, the
   user gets raw text rather than a hung paste. Matches the existing
   "bail loudly" philosophy.
3. **`Off` is one keystroke away.** When latency is unacceptable for a
   given send, the user picks `Off — paste as dictated` from the dropdown
   and the call is skipped entirely.

Local Ollama is interesting because it removes both the API-key step and
network unpredictability — at the cost of asking the user to run a model.
Worth supporting via the `provider: "ollama"` enum but probably not the
default.

### Trigger model

Always-on, governed by the picker. The picker is the trigger model — when
the user wants raw text, they pick `Off`. No per-script variants
(`-clean.sh`, `-raw.sh`); each `send-to-*.sh` does whatever the active
prompt says.

A "Hey AI"–style command syntax (recognise `"hey AI, …"` as an *ad-hoc*
prompt overriding the picker) is a tempting follow-up, but the picker
covers ~90% of the value with no command-detection ambiguity. Defer.

### What this does *not* try to do (v1)

- **No streaming insertion.** Text is buffered in the scratchpad; one
  round trip, one paste.
- **No screen / clipboard context capture.** The transformer sees only the
  dictated text and the active prompt's system message.
- **No in-app prompt editor.** Users edit `prompts.json` in their text
  editor. SQLite + a real editor is the post-v1 path.
- **No per-destination defaults.** Picker selection is global across all
  `send-to-*` hotkeys. Layer per-destination memory in later if it's
  actually wanted.
- **No history / undo.** The scratchpad keeps the raw text after send, so
  the user can switch the picker to `Off` and re-send to get the verbatim
  version.

### Open questions

1. **Picker → script communication.** Sidecar file
   (`~/.config/voiceitt-bridge/active-prompt`) is proposed. Alternative:
   the scratchpad POSTs the dictated text to a small local endpoint that
   handles the LLM call *and* puts the result on the clipboard, so the
   `send-to-*` scripts don't change at all. Cleaner separation but adds a
   server endpoint. Filesystem feels right for v1.
2. **Default prompt on first install.** `fix-dictation` (most users
   benefit) vs `off` (preserve current behaviour). Probably `off` —
   surprise-free defaults.
3. **Where does the API key live?** Inheriting from the user's shell env
   (whatever launches Raycast → already has it) is simplest. Document a
   `~/.config/voiceitt-bridge/env` sourced by the `send-to-*` scripts as
   a fallback for users whose Raycast doesn't inherit shell env.
4. **`prompts.json` schema versioning.** Add a top-level `"version": 1`
   now so future migrations (especially the SQLite one) have an anchor.

### Suggested next steps

1. Add `bridge/prompts.default.json` with the starter prompts above and a
   top-level `"version": 1`.
2. Update `install.sh` to seed `~/.config/voiceitt-bridge/prompts.json`
   from the default (only if absent).
3. Add the picker `<select>` to `bridge/dictate.html`: fetch
   `/prompts.json`, render options, persist selection to `localStorage`,
   and on change `fetch()` (POST or write via a tiny server-side handler)
   the chosen id to the sidecar file. Simplest: serve the bridge dir with
   a script that handles `POST /active-prompt`.
4. Add `scripts/voiceitt-transform` (the bash CLI sketched above), and
   the two-line `voiceitt-transform` invocation in each existing
   `send-to-*.sh`.
5. README section: "Optional: AI transformation before paste" with the
   picker screenshot, env-var setup, and a `prompts.json` example.

Estimated effort for steps 1–5: **~1 day**, the bulk of which is the
HTML picker and the sidecar-write plumbing rather than the LLM call
itself.

---

## 1.5. Session context + learned-corrections memory (extension of §1)

**Priority: after §1 has shaken out in daily use.** §1 sends one phrase
at a time through the LLM, with no memory of what came before in the
same dictation session and no memory of how the *user* corrected past
output. That's the right v1 — small, stateless, debuggable — but it
leaves two known-quantity wins on the table.

**Status:** exploration / not implemented.

### What this does *not* try to do

Improve Voiceitt's *own* recognition accuracy. We're downstream of
Voiceitt; by the time text reaches the input field it's already
committed via `execCommand('insertHTML')`. Voiceitt's recogniser
doesn't see anything we do here. Everything below is about making the
**LLM rewrite stage** in §1 produce text that's closer to what the
user actually meant — which the user experiences as "it stopped
mishearing me" even though, strictly, the mishearing happened upstream
and we just got better at silently fixing it.

### Two distinct mechanisms

#### A) Rolling session context (cheap, low-risk)

Pass the last *N* (input, output) pairs from the current session as
extra context to the LLM call, alongside the current utterance.
Concretely: prepend a short "Recent dictation in this session, for
disambiguation only — do not repeat or summarise" block to the user
message in `voiceitt-transform`.

What this fixes:

- **Homophones decided by topic.** "Right the function" reads as "Write
  the function" once the model has seen three previous utterances about
  editing code.
- **Pronouns and back-references.** "It crashed again" gets to keep
  "it" instead of being awkwardly expanded, because the model can see
  the antecedent two utterances back.
- **Consistent capitalisation of project-specific names.** If
  `Voiceitt` came out as `voice it` in the first utterance, the user
  fixes it to `Voiceitt` in the input field, and the next utterance
  mentions it again, the model now has a precedent to follow rather
  than re-guessing per phrase.
- **Tone / register drift.** A long polite-email session stays in the
  same register instead of each utterance being rewritten in isolation.

What it doesn't fix: anything that requires *cross-session* memory.
Once the page reloads or the user changes prompts, the rolling window
resets. That's intentional — it keeps the mechanism small and
inspectable, and it avoids the model dragging stale context into a new
topic.

Bound the window aggressively: last **5 utterances** *or* **800 tokens
of context**, whichever comes first. More than that and (a) latency
creeps up, (b) the model starts paraphrasing context as if it were
input, (c) the cost-per-send doubles for marginal gain.

#### B) Learned-corrections memory (high-leverage, more design)

When the user **edits the output field by hand** before sending — or
edits the input field to fix a recognition error before the LLM runs
again — *that edit is a labelled training example*. We saw what
Voiceitt produced, we saw what the LLM produced, and now we see what
the user actually wanted. Persist the diff and feed it back into
future transforms.

The naive version, which is also probably the right v1: append every
non-trivial diff to a JSONL file
(`~/.config/voiceitt-bridge/corrections.jsonl`) with shape:

```json
{"ts": "2026-…", "prompt_id": "fix-dictation",
 "voiceitt_raw": "amp threads",
 "llm_output": "Amp threads",
 "user_final": "Amp threads"}
```

…and at LLM call time, scan the file for entries where
`voiceitt_raw` contains substrings present in the current utterance,
and inject the top-K most-recent matches as few-shot examples in the
system prompt:

```
The user has previously corrected dictations like:
  Voiceitt heard: "amp threads"      → User wanted: "Amp threads"
  Voiceitt heard: "voice it bridge"  → User wanted: "voiceitt-bridge"
Apply the same conventions where they obviously fit.
```

What this fixes:

- **Personal jargon, project names, paths, command names.** The
  highest-frequency category of "Voiceitt is wrong" complaints is
  proper nouns the recogniser has never been trained on. The user
  fixes `amp` → `Amp` and `voice it` → `Voiceitt` exactly *once*; from
  then on the LLM applies the convention silently.
- **Recurring punctuation preferences.** If the user keeps deleting
  the Oxford comma the model adds, after a few corrections the
  few-shot examples nudge the model not to add it.
- **Acronym vs. spelled-out preference per term.** "VS Code" vs "Visual
  Studio Code" gets pinned to whichever one the user keeps reverting to.

Why this is more design than (A):

- **Diff harvesting is fiddly.** We need to detect "the user edited the
  output before sending" without harvesting noise (e.g., the user typed
  one character, then Cmd+Z'd it). Probably: only record a diff at the
  moment a `send-to-*` hotkey actually fires, comparing
  `lastInputSentToLLM` / `lastLLMOutput` to the input and output field
  contents at fire time.
- **Substring matching is a weak retriever.** It'll over-trigger on
  short common words ("the", "a"). Sketch: only index substrings of
  length ≥ 4 that *changed* between `voiceitt_raw` and `user_final`,
  not all substrings.
- **Privacy.** This file *is* a personal dictation log. It should never
  leave the machine, never get synced via the eventual SQLite/Litestream
  story without explicit opt-in, and the README must say so loudly.
- **A "forget this" affordance** is required from day one — a
  `voiceitt-corrections forget <substring>` CLI, or a button in the
  scratchpad that pops up the last harvested diff and lets the user
  delete it. Otherwise the file becomes a graveyard of typos the model
  thinks are intentional.
- **Token budget.** Few-shot examples eat into the same context the
  rolling window in (A) wants. At ~80 tokens per `(raw, final)` pair,
  budget K = 4 examples ≈ 320 tokens. Combine with (A)'s 800 → ~1.1k
  tokens of context per call, still well within Haiku's window.

### Where this lives in the pipeline

Both mechanisms are pure additions to `voiceitt-transform`:

```
input → voiceitt-transform
          ├─ load active prompt (today)
          ├─ load rolling session context  (mechanism A)
          ├─ retrieve relevant corrections (mechanism B)
          ├─ build system prompt: prompt.system + context + few-shots
          └─ POST to provider → stdout
```

Session context is per-tab state, so it lives in `bridge/dictate.html`
and gets POSTed to the local server alongside each transform request
(yet another reason §1.4's `POST /active-prompt` endpoint should grow
into a more general "transform request" handler rather than a sidecar
file). Corrections memory is persistent state, lives in
`~/.config/voiceitt-bridge/corrections.jsonl`, and is read directly by
`voiceitt-transform`.

### Suggested order of attack

1. **Mechanism A first**, sized to "5 utterances or 800 tokens". One
   afternoon of work; immediate user-visible improvement on the
   second-and-later utterance of any session. Easy to A/B against §1's
   stateless baseline by toggling the context block on/off via a
   `?context=0` query string on the page.
2. **Live on (A) for a week or two.** It will become obvious whether
   (B) is worth building, because the user will notice exactly which
   recurring corrections the rolling-context mechanism *fails* to
   absorb (anything that doesn't appear in the last 5 utterances).
3. **Mechanism B**, starting with the dumbest possible retriever
   (substring match on changed-runs-of-≥-4-chars) and the JSONL store.
   Add a SQLite migration only when the JSONL file gets large enough
   that linear scans hurt — which, for a personal dictation log,
   probably takes months.
4. **Forget-affordance and privacy README** ship in the same PR as (B).
   Non-negotiable.

### Out of scope for §1.5

- Fine-tuning a custom Voiceitt or LLM model on the corrections corpus
  (a real ML pipeline, miles outside this project's scope).
- Sharing the corrections corpus across machines or users.
- Embedding-based retrieval for (B) — substring match is fine until
  it's demonstrably not.
- Any attempt to feed corrections *back to Voiceitt*. Voiceitt's API
  doesn't expose a "user lexicon" hook from where we sit; if it ever
  does, that becomes a separate roadmap item.

---

## 2. Pluggable target window — paste anywhere, not just iTerm

### Where we are today

`scripts/send-to-iterm.sh` and `scripts/send-to-iterm-and-run.sh` hardcode the
destination via AppleScript:

```applescript
tell application "iTerm"
  activate
  tell current window
    tell current session
      write text clipText newline yes
    end tell
  end tell
end tell
```

That's reliable and bypasses Sticky Keys entirely (no synthetic Cmd+V), but it
is iTerm-specific. We want to be able to dictate into Slack, a Chrome textarea
on a different tab, VS Code, Notes, a different terminal emulator, etc.

### Why this isn't just "read frontmost app at send time"

Triggering the Raycast hotkey itself changes focus. By the time our script
runs, "the app the user wanted to paste into" is no longer frontmost — Raycast
or the scratchpad is. So we cannot simply read `frontmost` at send time. The
target has to be **fixed ahead of time**.

There's a second, OS-level reason this matters: macOS gates cross-app
automation per (controlling app, controlled app) pair. The first time Raycast
(or `osascript` invoked from Raycast) tries to script Slack, the user gets a
"Allow Raycast to control Slack?" prompt. `cliclick` similarly requires
Accessibility permission for whichever process is invoking it. **Each new
target app implies at least one fresh permission prompt that the user has to
answer.** Any design has to make that moment obvious instead of mysterious.

### Approach A — Per-target scripts via a generator (recommended)

> **Builds on §0.** The minimal `scripts/new-shortcut.sh` shipped in §0
> already implements the core of this approach (clone a chosen base script,
> substitute the display name + bundle id, chmod +x, symlink via
> `install.sh`). The work below is a graduation of that helper into a richer
> generator with strategy templates, bundle-id auto-detection, and `& Run`
> companions — *not* a from-scratch design. Anywhere this section says
> "generator", read it as "extend `new-shortcut.sh`".

Instead of one dynamic dispatcher that figures out the right strategy at
runtime, ship a small **generator** that stamps out a new dedicated
`send-to-<app>.sh` Raycast command for each app the user wants to target. The
user then enables the new command in Raycast and assigns it a hotkey, exactly
like the existing iTerm scripts.

Why this fits the problem well:

- **One hotkey per target** is actually the natural mental model — the user
  knows whether they're dictating to iTerm vs. Slack vs. VS Code; a dedicated
  hotkey per target avoids needing a "set target" step before every send.
- **Permissions surface naturally and exactly once.** The first time the user
  triggers `Send to Slack`, macOS prompts to allow Raycast to control Slack
  (or to allow Accessibility for `cliclick`). That mapping — one prompt per
  generated command — is much easier to reason about than a single dispatcher
  that occasionally trips a new prompt depending on internal state.
- **No persistent state file, no focus-loss bug, no picker UI** to design.
- **Generated scripts are inspectable bash.** The user can hand-tweak any of
  them (different paste strategy, different submit key, different icon) without
  understanding a runtime config schema.
- **Removing a target = deleting the script.** No orphaned state.

Sketch:

```
scripts/
  new-target.sh                 # The generator. Prompted once per new app.
  send-to-iterm.sh              # Existing.
  send-to-iterm-and-run.sh      # Existing.
  send-to-slack.sh              # Generated.
  send-to-vscode.sh             # Generated.
  send-to-chrome-textarea.sh    # Generated.
  ...
templates/
  send-applescript.sh.tmpl      # AppleScript-driven (iTerm-style) targets.
  send-cliclick-paste.sh.tmpl   # Generic activate-and-Cmd+V targets.
  send-cliclick-paste-run.sh.tmpl
```

`new-target.sh` is a Raycast Script Command with arguments
(`# @raycast.argument1 …`) that asks for:

| Argument          | Example         | Purpose                                                          |
| ----------------- | --------------- | ---------------------------------------------------------------- |
| Target name       | `Slack`         | Used for the Raycast title (`Send to Slack`) and the file name.  |
| Bundle id         | `com.tinyspeck.slackmacgap` | Used in `osascript -e 'tell application id "…" to activate'`. Pre-filled by detecting the most-recently-frontmost non-Raycast app, so usually the user just presses Enter. |
| Strategy          | `applescript` \| `cliclick-paste` | Which template to instantiate. Default: `cliclick-paste` for unknown apps; `applescript` is offered for iTerm, Terminal, Chrome, Safari. |
| Submit on send    | `none` \| `return` \| `cmd+return` | Whether the `& Run` variant should also press a key after pasting. Defaults sensibly per known app (chat apps → `return`, terminals → `return`, editors → `none`). |
| Icon              | `💬`           | Optional emoji for the Raycast row.                               |

The generator does:

1. Slugify the target name → `slack`.
2. Read the right template, substitute `{{TARGET_NAME}}`, `{{BUNDLE_ID}}`,
   `{{ICON}}`, `{{SUBMIT_KEY}}`.
3. Write `scripts/send-to-<slug>.sh` (and, if "& Run" is requested, a
   `send-to-<slug>-and-run.sh` companion).
4. `chmod +x` and `ln -sfn` into `~/.config/raycast/scripts/` — same
   convention `install.sh` already uses.
5. Show a notification: *"Created Send to Slack. Open Raycast and assign a
   hotkey. The first trigger will prompt for permission to control Slack."*

#### Strategy templates

`send-applescript.sh.tmpl` — for apps with a real scripting dictionary:

```bash
osascript <<EOF
set clipText to (the clipboard as text)
tell application id "{{BUNDLE_ID}}"
  activate
  -- per-app body, hand-curated for iTerm/Terminal/Chrome/Safari
end tell
EOF
```

`send-cliclick-paste.sh.tmpl` — for everything else:

```bash
osascript -e 'tell application id "{{BUNDLE_ID}}" to activate'
sleep 0.05
"$CLICLICK" ku:cmd,alt,ctrl,shift,fn >/dev/null 2>&1 || true
"$CLICLICK" kd:cmd w:60 t:v w:60 ku:cmd
{{#SUBMIT_KEY_RETURN}}sleep 0.05
"$CLICLICK" kp:return{{/SUBMIT_KEY_RETURN}}
```

Both templates reuse the existing sentinel-on-clipboard / Sticky-Keys-safe
copy preamble verbatim — that part isn't target-specific.

#### Work breakdown

| Step | Description                                                                       | Est. effort |
| ---- | --------------------------------------------------------------------------------- | ----------- |
| 1    | Extract the shared "copy from focused app via cliclick + sentinel" preamble into a sourced `lib/copy-focused.sh`. | 0.25 day |
| 2    | Build the two strategy templates and small substitution logic in `new-target.sh`. | 0.5 day     |
| 3    | Pre-fill bundle id by inspecting `lsappinfo list` for the most-recent frontmost non-Raycast app. | 0.25 day |
| 4    | Curate AppleScript bodies for the four "first-class" apps (iTerm, Terminal, Chrome, Safari). | 0.5 day |
| 5    | README section: "Adding a new target", with the permission-prompt walkthrough.    | 0.25 day    |

Total: **~2 days**, same ballpark as the dispatcher approach but with a
materially simpler runtime.

#### Risks and open questions

- **Bundle id discovery** — for very new or weirdly-named apps,
  `lsappinfo info -only bundleid <pid>` is reliable; a fallback to "the user
  types the bundle id" is fine.
- **Wrong control focused inside the target app** — `cliclick-paste` only
  works when the destination app's focused control accepts paste. The
  generated script can't know that; document it, and let users hand-edit the
  generated script if they need an app-specific click-into-the-text-field
  step before pasting.
- **Sticky Keys + Cmd+V** — believed to be safe because `cliclick` posts
  CGEvents below the Sticky Keys layer. Verify on the user's machine before
  promising support for non-terminal apps.
- **Secure Input mode** — when macOS is in Secure Input (a password field is
  focused anywhere on the system), no synthetic input works. The shared
  preamble should detect this and bail with a clear notification.
- **Discoverability** — users can end up with a long list of `send-to-*`
  Raycast commands. That's actually fine; Raycast is built for it. If it ever
  gets unwieldy we can group them under a Raycast extension (see section 3).

### Approach B — Single dynamic dispatcher (alternative considered)

For completeness, the originally-considered design: store the chosen target
in `~/.config/voiceitt-bridge/target.json`, add a `Set Voiceitt Target`
command that captures the current frontmost app and writes that file, and
have a single `Send to Target` command that reads it and dispatches.

Why we're not going with this as the primary plan:

- Adds a mandatory "set target" step before every new dictation context.
- Permission prompts pop up at unpredictable moments (whenever the dispatcher
  first encounters a new target app), which is confusing.
- The `Set Target` command itself has the focus-loss problem unless we're
  clever about timing — it has to read `frontmost` *before* the user invokes
  it, which is awkward.
- Less flexible: per-target tweaks (a custom AppleScript body, a different
  submit key) require editing a config file rather than just editing a small
  bash script.

It's still a valid fallback if the per-script approach produces too many
commands for someone's taste, and the underlying paste strategies are the
same — so switching to a dispatcher later would mostly be a UI change.


---

## 3. Turning this into a Raycast extension on the Raycast store

### Today vs. extension

Right now we ship **Raycast Script Commands** — plain bash files with
`# @raycast.*` headers, distributed by `git clone` + `./install.sh`. The
Raycast store does **not** list script-command repos; it only lists proper
**Extensions**, which are TypeScript/React projects built against
`@raycast/api`, published via Raycast's own publish flow.

A store-quality extension is a real port, not a wrapper.

### What the port involves

| Area                       | Today (script commands)                   | Extension (TypeScript)                                                                  |
| -------------------------- | ----------------------------------------- | --------------------------------------------------------------------------------------- |
| Language / runtime         | Bash + AppleScript                        | TypeScript + React (`@raycast/api`)                                                     |
| Commands                   | 4 `.sh` files with header comments        | 4 commands declared in `package.json`, each a TS module exporting `default`             |
| User-visible UI            | None (silent commands + osascript notifs) | Optional `<List>`, `<Form>`, `<Detail>`, plus `showHUD` / `showToast` for feedback      |
| Config                     | Hardcoded constants + `~/.config/...`     | Raycast preferences (typed schema in `package.json`, accessed via `getPreferenceValues`) |
| External binary (cliclick) | `brew install cliclick` (user-managed)    | Same — store policy disallows bundling unsigned binaries; document as a prerequisite     |
| Local HTTP server          | `python3 -m http.server` via `nohup`      | Spawn from a `no-view` command using `child_process`, track PID across runs              |
| HTML scratchpad            | Symlinked into `~/.config/...`            | Bundled in the extension; either copied to `environment.supportPath` on first run, or served by an in-process Node `http.createServer` |
| AppleScript                | Heredocs in bash                          | `runAppleScript` from `@raycast/utils`                                                  |
| Distribution               | `git clone` + `install.sh`                | `npm run publish` → Raycast review → store listing                                      |

### Sequence of work

1. **Scaffold** with `npm create raycast-extension@latest`. Pick "no view" as
   the default mode for the four commands. (~0.5 day)
2. **Port `open-voiceitt`** — spawn `python3 -m http.server` (or a small
   in-process Node server) bound to `127.0.0.1:7531`, write the scratchpad
   HTML to `environment.supportPath` on first run, open Chrome via
   `runAppleScript`. Detect "already running" via PID file in the same support
   path. (~1 day)
3. **Port the two `send` commands** — `runAppleScript` for the iTerm path, and
   shell out to `cliclick` for the Cmd+A/Cmd+C step. Use `showToast` instead
   of `display notification`. (~0.5 day)
4. **Port `back-to-voiceitt`** — straight `runAppleScript` translation.
   (~0.25 day)
5. **Preferences** — expose port, scratchpad title, and `cliclick` path as
   Raycast preferences so users on Intel Macs (`/usr/local/bin/cliclick`) work
   out of the box. (~0.25 day)
6. **Bundle the iTerm/target picker work** from section 2, since by the time
   we're publishing it would be strange not to support more than iTerm. This
   is the biggest TS-side surface: a `<List>` of running apps + windows for
   "Set Target", and a TypeScript dispatcher mirroring the bash one. (~1–2
   days, on top of section 2's work.)
7. **Polish for store review** — extension icon (512×512 PNG), at least one
   screenshot per command, a README written to Raycast's tone, a
   `CHANGELOG.md` entry, and a permissions note covering Accessibility +
   "cliclick must be installed". (~0.5 day)
8. **Submit** via `npm run publish`. Iterate on reviewer feedback.

### Estimated total effort

- **Pure 1:1 port** of today's four commands (still iTerm-only): ~**2–3 days**
  of focused work for someone who has shipped a Raycast extension before;
  ~**4–5 days** for a first-timer.
- **Port + multi-target support from section 2**: add ~**2 days**.
- **Review turnaround**: typically days to a couple of weeks, with one or two
  rounds of small fixes.

So a realistic "ready to publish" budget is **~1 working week**, plus review.

### Major risks / unknowns

- **Bundling `cliclick`** — the cleanest UX would be to ship it inside the
  extension, but Raycast's store policies forbid shipping arbitrary binaries.
  Mitigation: detect `cliclick` on launch and, if missing, show a one-click
  toast that copies the `brew install cliclick` command to the clipboard.
- **Long-lived HTTP server** — Raycast's command processes are short-lived.
  We have to spawn the server detached (`spawn(..., { detached: true,
  stdio: 'ignore' }).unref()`) and persist its PID, exactly like the bash
  version does. Reviewers may push back on this; the alternative is to start
  the server on every "Send" command and tear it down on idle.
- **Chrome window detection** — `runAppleScript` works fine, but if Chrome
  isn't running we currently rely on `open -na`. Need to mirror that exactly
  to avoid first-run regressions.
- **No-Sticky-Keys testing** — the whole point of this tool is Sticky Keys
  compatibility. The reviewer almost certainly won't have Sticky Keys on, so
  we need to document and test that path ourselves before submission.
- **Telemetry / privacy** — Raycast extensions cannot exfiltrate clipboard
  contents. Our flow only moves clipboard data through local AppleScript and
  cliclick; that should be fine, but the README must say so explicitly.

### Decision point

A Raycast extension is mostly worthwhile if other Voiceitt users (or
one-finger typists generally) want this. For a single-user setup, the current
script-commands flow is materially simpler to maintain. Recommend: do
section 2 first, live on it for a few weeks, then decide whether to invest
the week needed for a store extension.
