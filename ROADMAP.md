# Roadmap

Two larger pieces of work that the current toolkit doesn't yet cover. Both are
deliberately out of scope for the first version — this doc is the plan for
"page two" once the basic iTerm bridge has shaken out in daily use.

---

## 1. Pluggable target window — paste anywhere, not just iTerm

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
  gets unwieldy we can group them under a Raycast extension (see section 2).

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
Previous ideas were discarded, but the above is the current plan.

## Turning this into a Raycast extension on the Raycast store

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
6. **Bundle the iTerm/target picker work** from section 1, since by the time
   we're publishing it would be strange not to support more than iTerm. This
   is the biggest TS-side surface: a `<List>` of running apps + windows for
   "Set Target", and a TypeScript dispatcher mirroring the bash one. (~1–2
   days, on top of section 1's work.)
7. **Polish for store review** — extension icon (512×512 PNG), at least one
   screenshot per command, a README written to Raycast's tone, a
   `CHANGELOG.md` entry, and a permissions note covering Accessibility +
   "cliclick must be installed". (~0.5 day)
8. **Submit** via `npm run publish`. Iterate on reviewer feedback.

### Estimated total effort

- **Pure 1:1 port** of today's four commands (still iTerm-only): ~**2–3 days**
  of focused work for someone who has shipped a Raycast extension before;
  ~**4–5 days** for a first-timer.
- **Port + multi-target support from section 1**: add ~**2 days**.
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
section 1 first, live on it for a few weeks, then decide whether to invest
the week needed for a store extension.
