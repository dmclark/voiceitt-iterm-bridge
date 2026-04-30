# Exploration: AI post-processing before paste

**Status:** exploration / not implemented
**Branch:** `explore/ai-post-processing`
**Origin:** Inspired by the post-transcription enhancement stage in
[T-019d2169-fcab-77ee-aec2-d1f8b6e46901](https://ampcode.com/threads/T-019d2169-fcab-77ee-aec2-d1f8b6e46901),
where transcribed text is run through an LLM (grammar fixes, formatting,
custom prompts, "Hey AI" commands) before being inserted at the cursor.

## The idea

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

## Why per-prompt, not per-destination

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

## The prompt picker

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

## Config file (v1)

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

A starter version of this file ships in
[bridge/prompts.default.json](../bridge/) and `install.sh` copies it into
`~/.config/voiceitt-bridge/prompts.json` on first run (and never overwrites
on subsequent runs, so user edits stick).

Editing is just "open the JSON file in your editor". No UI for v1. The
scratchpad reloads its picker on every page open, so the workflow is:
edit → reload tab → new prompts in the dropdown.

## SQLite — when, not if

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

## Where the call goes

The cleanest insertion point in each `send-to-*.sh` is right after the
existing "copy actually fired" sentinel check and before the AppleScript
paste. Pulling the relevant lines out of
[scripts/send-to-iterm.sh](../scripts/send-to-iterm.sh):

```bash
# 5b) Run text through the active prompt's LLM transformation.
if command -v voiceitt-transform >/dev/null 2>&1; then
  TRANSFORMED=$(printf '%s' "$CURRENT" | voiceitt-transform) || TRANSFORMED="$CURRENT"
  printf '%s' "$TRANSFORMED" | pbcopy
fi
```

Properties this gives us:

- **Destination-agnostic.** The same shim drops into every `send-to-*.sh`
  the per-target generator from [ROADMAP.md §1](../ROADMAP.md) produces.
  No per-script prompt logic.
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

## What `voiceitt-transform` is

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

## Latency

The bridge today is snappy — hotkey to paste is well under 200ms. An LLM
round-trip is 400ms–2s depending on provider, model, and network. That's
noticeable, especially for the lightweight "fix dictation" prompt which
runs on every send.

Mitigations, in order of effort:

1. **Pick a fast small model per prompt.** Haiku, Groq Llama,
   `gemini-2.5-flash`, or local Ollama (`llama3.2:3b`) all clear the bar
   for "remove disfluencies in one short utterance". Reserve heavier
   models — `claude-sonnet-4-5`, `gpt-4o`, `gemini-2.5-pro` (the model
   used in Voiceink via an AI Studio account) — for prose-restructuring
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

## Trigger model

Always-on, governed by the picker. The picker is the trigger model — when
the user wants raw text, they pick `Off`. No per-script variants
(`-clean.sh`, `-raw.sh`); each `send-to-*.sh` does whatever the active
prompt says.

A "Hey AI"–style command syntax (recognise `"hey AI, …"` as an *ad-hoc*
prompt overriding the picker) is a tempting follow-up, but the picker
covers ~90% of the value with no command-detection ambiguity. Defer.

## What this does *not* try to do (v1)

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

## Open questions

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

## Suggested next steps

1. Add `bridge/prompts.default.json` with the starter prompts above and a
   top-level `"version": 1`.
2. Update `install.sh` to seed `~/.config/voiceitt-bridge/prompts.json`
   from the default (only if absent).
3. Add the picker `<select>` to [bridge/dictate.html](../bridge/dictate.html):
   fetch `/prompts.json`, render options, persist selection to
   `localStorage`, and on change `fetch()` (POST or write via a tiny
   server-side handler) the chosen id to the sidecar file. Simplest:
   serve the bridge dir with a script that handles `POST /active-prompt`.
4. Add `scripts/voiceitt-transform` (the bash CLI sketched above), and
   the two-line `voiceitt-transform` invocation in each existing
   `send-to-*.sh`.
5. README section: "Optional: AI transformation before paste" with the
   picker screenshot, env-var setup, and a `prompts.json` example.

Estimated effort for steps 1–5: **~1 day**, the bulk of which is the
HTML picker and the sidecar-write plumbing rather than the LLM call
itself.
