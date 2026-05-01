# Roadmap

## History

The idea of a "bridge" originally came out of my work trying to make Voiceitt just another LLM [VoiceInk](https://github.com/Beingpax/VoiceInk) could use as a transcription backend. I've successfully built a [working prototype](https://github.com/dmclark/VoiceInk). The issue is that API consumption to be fiscally viable.

This approach is to provide the same functionality without the API. We are serving a page locally (the extension does not work on local files), essentially replacing [https://web.voiceitt.com/dictate] with a local page so that we can add keyboard shortcuts to send the text to local apps..`

## Future work

Three larger pieces of work that the current toolkit doesn't yet cover. All
are deliberately out of scope for the first version — this doc is the plan for
"phase two" once the basic iTerm bridge has shaken out in daily use.

---

## 1. AI post-processing before paste

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

The proposal: insert an **LLM transformation pass** after the copy and
before the paste, parameterised by **which prompt the user picked**. The
prompt is not tied to the destination app; the user chooses it directly
(e.g. "fix dictation noise", "format as bullet list", "translate to
Spanish", "rewrite as a polite email", "leave it alone"). The same
selected prompt is used regardless of which `send-to-*` hotkey ultimately
fires.

```diagram
                  Today                                    Proposed
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  Voiceitt textarea       │             │  Voiceitt textarea       │
  │                          │             │  + prompt picker ▼       │
  ╰─────────────┬────────────╯             ╰─────────────┬────────────╯
                │ Cmd+A / Cmd+C                          │ Cmd+A / Cmd+C
                ▼                                        ▼
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  macOS clipboard (raw)   │             │  macOS clipboard (raw)   │
  ╰─────────────┬────────────╯             ╰─────────────┬────────────╯
                │                                        │
                │                                        ▼
                │                          ╭──────────────────────────╮
                │                          │  LLM transformation pass │
                │                          │  prompt = picker value   │
                │                          ╰─────────────┬────────────╯
                │                                        │
                │                                        ▼
                │                          ╭──────────────────────────╮
                │                          │ Clipboard rewritten with │
                │                          │ transformed text         │
                │                          ╰─────────────┬────────────╯
                ▼                                        ▼
  ╭──────────────────────────╮             ╭──────────────────────────╮
  │  Destination (verbatim)  │             │  Destination (transformed)│
  ╰──────────────────────────╯             ╰──────────────────────────╯
```

The destination is incidental — the *prompt* is what determines what
happens to the text. iTerm is just one possible sink.

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

Editing is just "open the JSON file in your editor". No UI for v1. The
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
