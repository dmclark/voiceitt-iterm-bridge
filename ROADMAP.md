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

### The core problem

Triggering the Raycast hotkey itself changes focus. By the time our script
runs, "the app the user wanted to paste into" is no longer frontmost — Raycast
or the scratchpad is. So we cannot simply read `frontmost` at send time. The
target has to be **remembered out-of-band** before the user dictates.

### Proposed design — explicit "target" with a sensible default

Add a small piece of persistent state at `~/.config/voiceitt-bridge/target.json`:

```json
{
  "kind": "iterm" | "app" | "window",
  "appName": "iTerm",
  "bundleId": "com.googlecode.iterm2",
  "windowId": 12345,
  "label": "iTerm — main session"
}
```

Three new / modified Raycast commands:

| Command                       | Behavior                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| `Set Voiceitt Target`         | Captures the currently frontmost app + window and writes it to `target.json`.             |
| `Send to Target`              | Replaces `send-to-iterm.sh`. Reads `target.json` and dispatches to the right strategy.    |
| `Send to Target & Run`        | Same, but submits Return at the end (only meaningful for terminal-like targets).          |

`Set Voiceitt Target` is what closes the focus-loss problem: the user clicks
into the destination they want, then triggers the hotkey, which records the
target *before* opening the scratchpad. `Open Voiceitt Scratchpad` can be
extended to call `Set Voiceitt Target` first, so the common flow ("focus the
app I want to dictate into, then press my hotkey") just works.

### Dispatch strategies inside `Send to Target`

The script picks one of these based on `target.json`:

1. **Native AppleScript path** — for apps with a real scripting dictionary:
   - `iTerm` (current implementation)
   - `Terminal.app` (`do script` / `tell window N to do script`)
   - `Google Chrome` / `Safari` (`execute javascript` to set a textarea value)
   - `Notes`, `Messages`, etc. where applicable
   - Highest fidelity, no key synthesis, Sticky-Keys-proof.

2. **Generic "activate + cliclick paste" path** — for everything else:
   ```bash
   osascript -e "tell application id \"$BUNDLE_ID\" to activate"
   sleep 0.05
   "$CLICLICK" ku:cmd,alt,ctrl,shift,fn
   "$CLICLICK" kd:cmd t:v ku:cmd
   ```
   `cliclick` posts CGEvents below the Sticky Keys layer, so Cmd+V works even
   with Sticky Keys on. Caveats: relies on whatever control had focus inside
   that app being a paste target; some apps (e.g. 1Password, secure fields)
   refuse synthetic paste.

3. **Window-targeted path** (optional, harder) — if `target.json` records a
   specific `windowId`, raise that window first via Accessibility (AX) APIs
   before pasting. AppleScript can't cleanly target an arbitrary window by
   ID across all apps; this would either need a small Swift helper using
   `AXUIElement` or a third-party tool like `yabai`. Recommend deferring
   this until a real user need surfaces.

### `Run` semantics on non-terminals

`Send to Target & Run` only makes sense for terminal-shaped targets. For other
apps the `Run` variant should either:

- fall back to plain paste (no Return), or
- press Return via cliclick (`"$CLICLICK" kp:return`) for chat apps where
  Enter sends the message.

Decide per-target by adding an optional `submitKey` field to `target.json`
(`"return"`, `"cmd+return"`, `null`).

### Work breakdown

| Step | Description                                                                  | Est. effort |
| ---- | ---------------------------------------------------------------------------- | ----------- |
| 1    | Add `set-target.sh` Raycast command that records frontmost app + window.    | 0.5 day     |
| 2    | Refactor `send-to-iterm*.sh` into a single dispatcher reading `target.json`. | 0.5 day     |
| 3    | Implement AppleScript paths for iTerm, Terminal, Chrome, Safari.             | 0.5 day     |
| 4    | Implement generic cliclick-paste fallback.                                   | 0.25 day    |
| 5    | Update README + add notification feedback ("Target set: iTerm — window 1").  | 0.25 day    |
| 6    | (Optional) AX-based window raising via small Swift helper.                   | 1–2 days    |

Total: **~2 days** for the practical version, plus an optional 1–2 days for
window-precise targeting.

### Risks and open questions

- **Stale targets** — if the user closes the recorded window, the dispatcher
  should detect that (AppleScript `exists window id …`) and fall back to
  "any window of `appName`", with a notification.
- **Secure input mode** — when macOS is in Secure Input (e.g. password
  prompt focused), no synthetic input works. Detect via
  `IsSecureEventInputEnabled` and bail out with a clear notification.
- **Sticky Keys + Cmd+V** — `cliclick` is believed to bypass it, but worth
  retesting on the user's actual config before promising support for arbitrary
  apps.
- **Multi-display / Spaces** — activating an app in another Space causes a
  Space switch. May want a "don't switch Space" mode that uses AX to send
  text without raising the window. Defer.

---

## 2. Turning this into a Raycast extension on the Raycast store

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
