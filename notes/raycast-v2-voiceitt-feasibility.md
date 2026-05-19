# Raycast v2 + Voiceitt feasibility spike

**Branch:** `explore/raycast-v2-voiceitt-feasibility`  
**Date:** 2026-05-15

This is a rough feasibility outline, not an ERD. Direction chosen after the
initial comparison: **build a Raycast extension/command flow that preserves
this repo's Voiceitt browser-extension path**, rather than integrating Voiceitt
as a Raycast Dictation transcription provider.

Primary reason: the extension-wrapper path avoids Voiceitt developer API usage
fees. The whole point of this bridge is to keep using the Voiceitt Chrome
extension on a localhost scratchpad instead of metered Voiceitt API streaming.

## Source notes

- Raycast v2 beta adds first-party **Dictation**: press/hold to talk, direct
  paste into the current app, Auto Styling, custom vocabulary/instructions,
  Styles, and Dictation History. We are **not** depending on that feature.
- Raycast v2 manual says **Custom Providers** are **coming soon**, alongside
  local models and other not-yet-in-beta features. Treat this as interesting
  background only; it is not part of the selected path.
- Raycast developer docs currently document extension APIs for React/TS/Node
  commands, `Clipboard.paste`, `Clipboard.copy(..., { concealed: true })`,
  `getFrontmostApplication`, `getApplications`, preferences, storage, window
  management, and Raycast AI prompts.
- I could not find a public extension API for microphone capture, Raycast
  Dictation transcripts, or registering a custom Dictation transcription
  provider.
- The VoiceInk prototype used Voiceitt's **native API path**, not the browser
  extension: REST login + Socket.IO streaming to Voiceitt, with 16 kHz mono
  PCM Int16 LE audio. That path is explicitly out of scope for the normal
  workflow here because of usage fees.
- The current bridge intentionally avoids the Voiceitt API cost problem by
  using the Chrome extension on `http://localhost:7531/dictate.html`.
- Post-transcription processing is part of the desired plan, but it is not yet
  fully implemented. The Raycast extension design should leave an explicit
  stage for LLM cleanup/formatting after Voiceitt writes text and before the
  final paste.

## Current baseline

```diagram
╭──────────────╮   speaks    ╭───────────────────╮   writes   ╭──────────────╮
│    User      │────────────▶│ Voiceitt Chrome   │───────────▶│ Scratchpad   │
╰──────────────╯             │ extension         │            │ localhost    │
                             ╰───────────────────╯            ╰──────┬───────╯
                                                                      │
                                                                      │ per-target
                                                                      │ Raycast script
                                                                      ▼
                                                             ╭────────────────╮
                                                             │ Target app via │
                                                             │ clipboard/copy │
                                                             ╰────────────────╯
```

Strengths:

- Uses the Voiceitt extension the user already relies on.
- Avoids the Voiceitt developer API consumption that made the VoiceInk
  prototype fiscally unattractive.
- Sticky-Keys-safe because the scripts use `cliclick` instead of AppleScript
  synthetic modifiers.
- Simple deployment: bash + one HTML file + local Python server.

Pain points this spike is trying to address:

- One Raycast hotkey/script per target app.
- Clipboard history gets filled with transient dictation payloads.
- Targeting is static: `send-to-vscode`, `send-to-iterm`, etc., rather than
  "send back to wherever I started dictating from".

## Out of scope — Voiceitt as a Raycast Dictation provider

This direction is intentionally parked. It is not the path to prototype.

Reasons:

- It depends on Voiceitt's developer API, which brings back usage-fee risk.
- Raycast does not currently document a public extension API for microphone
  capture, Raycast Dictation transcript replacement, or custom Dictation
  provider registration.
- Even if Raycast later exposes a Dictation-provider SDK, a Voiceitt provider
  would need REST auth, Socket.IO streaming, token refresh, model-load latency
  handling, reconnect handling, and secure developer-credential distribution.

Keep this only as background context. The selected design below assumes **no
Voiceitt API usage** in the normal workflow.

## Selected path — Raycast extension around the existing Voiceitt bridge

### What this would mean

Keep the current Voiceitt browser-extension strategy, but move targeting into
Raycast state instead of separate `send-to-<app>.sh` scripts.

Proposed flow:

```diagram
╭────────────╮  hotkey: start dictation   ╭────────────────────────╮
│ Target app │───────────────────────────▶│ Raycast extension      │
│ focused    │                            │ stores target app/window│
╰────────────╯                            ╰───────────┬────────────╯
                                                       │ opens/raises
                                                       ▼
                                             ╭────────────────────╮
                                             │ Chrome scratchpad   │
                                             │ Voiceitt extension  │
                                             ╰──────────┬─────────╯
                                                        │ raw + processed text
                                                        ▼
╭────────────╮  hotkey: send dictation     ╭────────────────────────╮
│ Target app │◀────────────────────────────│ Raycast extension      │
│ restored   │   Clipboard.paste/concealed │ reads localhost state  │
╰────────────╯                             ╰────────────────────────╯
```

The key behavior change is: **capture the target before switching to Chrome**.
When the user invokes "Start Voiceitt Dictation" from Slack/VS Code/iTerm/etc.,
the extension stores the frontmost app/window. After dictation, "Send Voiceitt
Dictation" reads the scratchpad output and pastes back into that saved target.

### Why this is feasible

The required public APIs mostly exist:

- `getFrontmostApplication()` can capture the app before opening Chrome.
- `WindowManagement.getActiveWindow()` may capture a specific window where
  available, though it is Raycast Pro-gated and macOS-only for now.
- `Clipboard.paste(text)` pastes into the current selection of the frontmost
  app.
- `Clipboard.copy(text, { concealed: true })` explicitly avoids Raycast
  Clipboard History if we need a fallback path.
- Raycast preferences/storage can hold port, scratchpad URL/title, `cliclick`
  path, and last target metadata.
- Node can fetch from the local server.

### Target architecture

```diagram
╭────────────────────╮
│ Destination app    │
│ user was working in│
╰─────────┬──────────╯
          │ Start Voiceitt Dictation hotkey
          ▼
╭────────────────────╮        stores         ╭────────────────────╮
│ Raycast extension  │──────────────────────▶│ Target state        │
│ start command      │                       │ app/window metadata │
╰─────────┬──────────╯                       ╰────────────────────╯
          │ opens/raises Chrome
          ▼
╭────────────────────╮       dictation       ╭────────────────────╮
│ Scratchpad page    │◀──────────────────────│ Voiceitt extension  │
│ localhost:7531     │                       │ in Chrome           │
╰─────────┬──────────╯                       ╰────────────────────╯
          │ raw text
          ▼
╭────────────────────╮
│ Post-transcription │
│ processing stage   │
│ planned/incomplete │
╰─────────┬──────────╯
          │ raw + processed output
          ▼
╭────────────────────╮
│ POST               │
│ /scratchpad-state  │
╰─────────┬──────────╯
          │ latest state
          ▼
╭────────────────────╮
│ Local bridge server│
│ latest state only  │
╰─────────┬──────────╯
          │ Send Voiceitt Dictation hotkey fetches latest text
          ▼
╭────────────────────╮      activates/pastes ╭────────────────────╮
│ Raycast extension  │──────────────────────▶│ Destination app    │
│ send command       │                       │ focused insertion  │
╰────────────────────╯                       ╰────────────────────╯
```

### Proposed Raycast extension commands

| Command | Mode | Hotkey role | Behavior |
| --- | --- | --- | --- |
| **Start Voiceitt Dictation** | no-view | From destination app | Capture frontmost app/window, persist target state, start/raise local server, open/raise scratchpad in Chrome. |
| **Send Voiceitt Dictation** | no-view | From scratchpad | Fetch latest scratchpad state, prefer processed output when available, reactivate saved target, paste text, optionally clear state. |
| **Show Voiceitt Target** | view/detail, optional | Troubleshooting | Display saved target, latest scratchpad revision, paste method, and server status. |
| **Clear Voiceitt Target** | no-view, optional | Recovery | Clear saved target if it points to the wrong app/window. |

The minimal prototype only needs the first two commands. The latter two are
quality-of-life commands for the hardened version.

### Bridge/server contract

The local server currently has `/transform`, `/load`, `/file`, and `/events`.
The `/transform` route is the beginning of the post-transcription processing
story, but the full processing pipeline is not complete yet. The Raycast plan
should therefore treat processing as an explicit stage with a safe fallback to
raw Voiceitt text.

The server does **not** yet expose "give me the current scratchpad output". To
avoid Cmd+A/Cmd+C from Chrome, the page/server would need a local sync endpoint,
for example:

- `POST /scratchpad-state` whenever the scratchpad output changes.
- `GET /scratchpad-state` from the Raycast extension when sending.
- In-memory only. No history. Reload starts clean, matching the existing
  scratchpad mental model.

Candidate shape:

```json
{
  "raw": "what Voiceitt wrote into the Dictated pane",
  "processed": "LLM-cleaned or formatted text, if available",
  "output": "what should be pasted right now",
  "activePane": "dictated|output",
  "processingStatus": "raw|pending|processed|failed",
  "revision": 42,
  "updatedAt": "2026-05-15T12:34:56-04:00"
}
```

Default behavior for prototype: paste `output`. While post-transcription
processing is incomplete, `output` may simply equal `raw`. Preserve `raw`,
`processed`, `processingStatus`, and `activePane` so the ERD can later decide
whether the send command should wait for processing, paste raw immediately, or
honor the focused pane.

That endpoint would keep dictation text off the macOS clipboard until the final
paste.

### Target state model

Store this in Raycast local storage when starting dictation:

```json
{
  "bundleId": "com.microsoft.VSCode",
  "appName": "Visual Studio Code",
  "capturedAt": "2026-05-15T12:34:56-04:00",
  "windowId": "optional-if-WindowManagement-works",
  "windowTitle": "optional-for-display-only"
}
```

Prototype default: require only `bundleId` + `appName`. Treat window metadata as
best-effort. The first version should reactivate the saved app and paste into
whatever field/control is focused there; exact cursor restoration is a later
hardening problem.

### Pros

- Directly targets the user's two stated pain points:
  - one start/send flow instead of one shortcut per target app;
  - no repeated raw dictation entries in clipboard history.
- Preserves the browser-extension path, so it avoids Voiceitt API cost.
- Can be prototyped incrementally on top of this repo.
- Keeps post-transcription processing in the plan without making the Raycast
  extension depend on it being finished first.
- The extension can expose a small UI later: current target, send mode, history,
  troubleshooting, preferences.

### Cons / risks

- Still depends on Chrome + the Voiceitt extension + localhost.
- Requires the user to start dictation from the destination app if we want a
  reliable saved target. Starting from the scratchpad has no way to infer
  "where should this go?" unless the user set a target earlier.
- Restoring a specific cursor/field is harder than restoring an app. If the
  user changes focus inside the target app between "start" and "send", the
  paste may land in the wrong control.
- `WindowManagement` is Pro-gated and not available on Windows; we may need a
  non-Pro fallback that stores only app bundle id.
- `Clipboard.paste()` likely uses Raycast's native paste mechanism, but it
  still needs empirical Sticky-Keys testing. If it latches modifiers, fallback
  to the current `cliclick` ritual.
- The exact behavior of `Clipboard.paste()` with Clipboard History should be
  verified. The documented guaranteed no-history API is `Clipboard.copy(...,
  { concealed: true })`; if `Clipboard.paste()` internally writes to the
  clipboard without concealment, it may not solve the history problem by itself.
- Post-transcription processing is not complete yet. The send command needs an
  intentional policy: paste raw if processing is pending/failed, wait briefly,
  or let the user choose.
- Store review may object to a long-lived localhost server or to shelling out to
  `cliclick`, even if this is acceptable for a private extension.

### Level of effort

| Scope | Estimate | Deliverable |
| --- | ---: | --- |
| Feasibility prototype, private only | 2–4 days | Add `/scratchpad-state`; one Raycast extension with "Start" and "Send" commands; store last target; paste back raw or processed output. |
| Hardened private extension | 1–2 weeks | Preferences, error states, target display, app/window restore, Sticky Keys verification, concealed fallback, docs. |
| Store-ready extension | 2–4 weeks + review | Polish, icons/screenshots, reviewer-safe server story, permission docs, no bundled unsigned binaries. |

## Minimal prototype plan

This is the smallest experiment that would answer most feasibility questions:

1. Add local state sync to the bridge server:
   - `POST /scratchpad-state` with `{ raw, processed, output, activePane,
     processingStatus, revision }`;
   - `GET /scratchpad-state` returns the latest state;
   - keep state in memory only; no history.
2. Create a private Raycast extension with two no-view commands:
   - **Start Voiceitt Dictation**:
     - call `getFrontmostApplication()`;
     - optionally call `WindowManagement.getActiveWindow()` if available;
     - store target metadata in Raycast storage;
     - open/raise the scratchpad in Chrome.
   - **Send Voiceitt Dictation**:
     - fetch `http://127.0.0.1:7531/scratchpad-state`;
     - choose `output` according to the processing policy;
     - activate the saved target app;
     - paste the output text with `Clipboard.paste()`;
     - if history pollution appears, test `Clipboard.copy(..., { concealed:
       true })` + `cliclick` paste as fallback.
3. Test with Sticky Keys ON:
   - VS Code text editor;
   - iTerm current prompt;
   - Slack/Chrome textarea;
   - multi-line dictated text;
   - transformed vs raw pane selection.

## Milestones toward an ERD

### Milestone 1 — Local state endpoint only

- Add `/scratchpad-state` to `bridge/serve.py`.
- Add page-side sync from `bridge/dictate.html` to the endpoint.
- Manually verify with `curl` that the server always has the latest output.
- No Raycast extension yet.

Open questions answered by this milestone:

- How often should the page sync: on every input, debounced, or only after LLM
  transform completion?
- Should the server store raw + transformed text, or only the active output?
- What is the initial processing policy while post-transcription processing is
  incomplete: `output = raw`, or `output = processed when available else raw`?
- Does the endpoint need a per-run token, or is localhost-only acceptable for a
  private prototype?

### Milestone 2 — Private two-command Raycast extension

- Scaffold a private Raycast extension.
- Implement Start/Send as no-view commands.
- Store target app metadata with Raycast storage.
- Use `Clipboard.paste()` first because it may avoid direct clipboard-history
  writes.
- Prefer processed output when `processingStatus == "processed"`; otherwise use
  the prototype policy from Milestone 1.
- Test whether `Clipboard.paste()` pollutes Raycast Clipboard History.

Open questions answered by this milestone:

- Does `getFrontmostApplication()` capture the destination before Raycast steals
  focus reliably enough?
- Does `Clipboard.paste()` preserve Sticky-Keys safety?
- Does `Clipboard.paste()` avoid history pollution, or do we need concealed
  copy + `cliclick` fallback?

### Milestone 3 — Targeting hardening

- Add optional `WindowManagement.getActiveWindow()` support if useful.
- Add a Show Target command so the user can inspect where text will go.
- Add Clear Target recovery.
- Decide whether the target is one-shot after send or sticky until replaced.

Open questions answered by this milestone:

- Is app-level targeting good enough for the user's real workflow?
- Does window-level targeting justify Raycast Pro dependency?
- Should the user ever manually choose a target, or is "start from destination"
  the only supported mental model?

### Milestone 4 — Packaging decision

- If this is personal/private only: keep dependency and permission docs minimal.
- If this should become store-ready: revisit long-lived server, `cliclick`
  fallback, icons, screenshots, review notes, and privacy language.

## Recommendation

Pursue the **private Raycast extension wrapper** as the only implementation
track for now.

Reasons:

- It preserves the proven and cheaper Voiceitt browser-extension path.
- It attacks the concrete workflow problems: per-target shortcuts and
  clipboard-history noise.
- It is small enough to discard if Raycast v2 changes the extension APIs during
  beta.
- It creates evidence for a later ERD: exact target-restore behavior,
  Clipboard History behavior, Sticky Keys behavior, and whether Raycast Pro
  Window Management is necessary.
- It avoids Voiceitt API credentials, token handling, and usage-fee exposure.

## Clarifying questions before turning this into an ERD

1. Is the top priority **personal/private use** or eventual **Raycast Store**
   distribution?
2. Are you willing to require Raycast Pro APIs if they materially improve
   window targeting, or should the design work for free Raycast users too?
3. Should "send" paste into the **app that was active when dictation started**,
   or should there also be a visible/manual "current target" picker?
4. How important is restoring a specific **window/control/cursor position** vs.
   just reactivating the app and pasting wherever focus currently is?
5. Should the extension always send the transformed `pad-out` text, or should
   it preserve the current page behavior where the focused pane can select raw
   vs transformed output?
6. While post-transcription processing is incomplete, should Send paste raw
   immediately, wait briefly for processed output, or ask/show a warning?
7. Is it acceptable for a private prototype to depend on `cliclick` as a
   fallback if `Clipboard.paste()` is not Sticky-Keys-safe?
8. Do you want the target to be one-shot after send, or sticky until replaced?
9. Do you want this spike to stay as a separate note, or should the selected
   direction replace/extend ROADMAP §3 and ERD §3?

## Issues the concept surfaces

- **Target capture timing:** If the user opens the scratchpad first, Raycast can
  only see Chrome as frontmost. The workflow likely needs a "start from target
  app" ritual.
- **Clipboard semantics:** `Clipboard.paste()` is promising but must be tested
  against Raycast Clipboard History. The fallback should explicitly use
  concealed clipboard writes.
- **Privacy:** `/scratchpad-state` would expose current dictated text to any
  local process that can reach `127.0.0.1:7531`. This is already a local tool,
  but the ERD should decide whether to add a random per-run token.
- **Raycast beta churn:** v2 is new; APIs and review expectations may change.
  Keep the prototype private and minimal until the beta settles.
