# voiceitt-iterm-bridge

A small toolkit that lets you dictate prompts with [Voiceitt](https://www.voiceitt.com/)
(a Chrome-only voice dictation extension) and send them straight into the
**current iTerm tab** — whatever shell, REPL, or CLI tool (Amp, Claude Code,
`bash`, `python`, `ssh`, …) is running there — then jump back to dictate the
next prompt.

## Why

Voiceitt only works in Chrome. Most CLI work happens in a terminal. This
bridges the gap without any custom server, web UI, or API integration — just a
tiny local HTML scratchpad served over `http://localhost`, plus a few Raycast
Script Commands.

## Architecture

```
╭───────────────────╮   dictate    ╭────────────────────╮
│  Voiceitt (Chrome)│─────────────▶│ Scratchpad textarea │
╰───────────────────╯              │   localhost:7531    │
                                   ╰──────────┬──────────╯
                                              │ Cmd+A, Cmd+C (cliclick)
                                              ▼
                                   ╭────────────────────╮
                                   │  macOS clipboard    │
                                   ╰──────────┬──────────╯
                                              │ iTerm AppleScript
                                              ▼
                                   ╭────────────────────╮
                                   │  Current iTerm tab  │
                                   ╰────────────────────╯
```

## Prerequisites

- macOS (tested on macOS Tahoe)
- [Raycast](https://www.raycast.com/) — for global hotkeys + script commands
- [iTerm2](https://iterm2.com/) — your terminal of choice
- Google Chrome with the Voiceitt extension installed
- `python3` (ships with macOS / Xcode CLT) — runs the local web server
- `cliclick` (`brew install cliclick`) — sends Cmd+A/Cmd+C reliably under Sticky Keys
- Accessibility permissions granted to **Raycast** (and **iTerm** if you'll test from a terminal)

## Install

```bash
git clone <this-repo> ~/voiceitt-iterm-bridge
cd ~/voiceitt-iterm-bridge
./install.sh
```

`install.sh` symlinks the scripts into `~/.config/raycast/scripts/` and the
HTML scratchpad into `~/.config/voiceitt-bridge/`. Then in Raycast:

1. Settings → Extensions → Script Commands → **Add Script Directory**
2. Pick `~/.config/raycast/scripts`
3. Assign hotkeys to each command (suggestions below).

## Hotkey suggestions

| Command                    | Suggested hotkey | What it does                                                          |
| -------------------------- | ---------------- | --------------------------------------------------------------------- |
| Open Voiceitt Scratchpad   | `⌥⇧O`            | Starts the local server (if needed) and opens the page in Chrome.     |
| Send to iTerm              | `⌥⇧V`            | Cmd+A/Cmd+C in Chrome, paste into the current iTerm tab. No Return.   |
| Send to iTerm & Run        | `⌥⇧↩`            | Same as above plus Return — submits the line to whatever's running.   |
| Back to Voiceitt           | `⌥⇧B`            | Brings the Scratchpad Chrome window forward by title.                 |

## Daily use

1. `⌥⇧O` — Scratchpad opens in Chrome (light theme, big textarea).
2. Activate Voiceitt and dictate. Text appears in the textarea.
3. `⌥⇧V` (or `⌥⇧↩`) — text lands in the current iTerm tab.
4. `⌥⇧B` — returns to the Scratchpad. `⌘K` clears the textarea for the next prompt.

## Adding a new shortcut (e.g. VS Code, Slack, Notes)

Every `send-to-*.sh` is a small bash script with a Raycast header. Adding a
new target is a copy-paste-edit job — roughly five minutes once you know the
target app's bundle id.

### Pick the right base script

Two strategies, two starting points:

| Strategy           | When to use                                            | Start from                  |
| ------------------ | ------------------------------------------------------ | --------------------------- |
| **AppleScript**    | App has a useful scripting dictionary for "insert text into the active session" (iTerm, Terminal). | `scripts/send-to-iterm.sh`  |
| **cliclick paste** | Everything else (VS Code, Slack, Notes, browsers, most editors). | `scripts/send-to-vscode.sh` |

When in doubt, copy `send-to-vscode.sh` — the cliclick-paste strategy works
in any app that accepts a normal Cmd+V into its focused control.

### Find the target app's bundle id

```bash
osascript -e 'id of app "Visual Studio Code"'   # com.microsoft.VSCode
osascript -e 'id of app "Slack"'                # com.tinyspeck.slackmacgap
osascript -e 'id of app "Notes"'                # com.apple.Notes
```

### Edit four things

1. **Raycast header** — `@raycast.title`, `@raycast.description`, `@raycast.icon`.
2. **`TARGET_BUNDLE_ID`** — the value from the previous step.
3. **The notification title** in the "did not capture text" `osascript`
   line, so the failure toast says the right app name.
4. **Filename** — `scripts/send-to-<slug>.sh`.

The Cmd+A/Cmd+C copy preamble (steps 1–5 in every script) is destination-agnostic
and shouldn't change.

### Wire it up

```bash
chmod +x scripts/send-to-<slug>.sh
./install.sh           # idempotent — picks up the new script automatically
```

### First-trigger permission prompts

Open Raycast → Settings → Extensions → Script Commands → find your new
**Send to <App>** → assign a hotkey. The first time you trigger it, macOS
will pop **one or two** prompts:

- *"Raycast wants to control \<App\>"* — click **Allow**. (Both strategies
  trigger this because `osascript ... activate` counts as control.)
- If you've never granted Accessibility to Raycast or to `cliclick`'s host
  process, you may also see an Accessibility prompt → **System Settings →
  Privacy & Security → Accessibility** → enable Raycast.

If you accidentally dismissed either, find them under **System Settings →
Privacy & Security → Automation** (per-app toggles) and **→ Accessibility**.

### Verify with Sticky Keys ON

The whole point of this toolkit is Sticky-Keys-safe dictation. Always test
your new shortcut with **Sticky Keys ON** before declaring victory:

1. System Settings → Accessibility → Keyboard → Sticky Keys → ON.
2. Open the destination app, focus the field/editor that should receive text.
3. `⌥⇧O` (or however you open the Scratchpad) → dictate a sentence.
4. Trigger the new hotkey.
5. Text should land in the destination intact, with no stuck modifiers
   afterwards.

If the paste arrives but with a stuck Cmd (e.g. the next keypress triggers
a menu shortcut), the modifier-release line in the script
(`"$CLICLICK" ku:cmd,alt,ctrl,shift,fn ...`) didn't fire — re-check that
your edited script still has it before step 6.

## Files

```
scripts/
  open-voiceitt.sh         # Starts python3 http.server on :7531, opens Chrome window
  send-to-iterm.sh         # Cmd+A/Cmd+C → inject clipboard into current iTerm tab (no Return)
  send-to-iterm-and-run.sh # Same, plus Return (submits the line)
  send-to-vscode.sh        # Cmd+A/Cmd+C → activate VS Code → cliclick Cmd+V into active editor
  back-to-voiceitt.sh      # Find Chrome window titled "Voiceitt Scratchpad", raise it
bridge/
  dictate.html             # The Scratchpad page (light theme, autofocus, ⌘K to clear)
install.sh                 # Symlinks scripts and html to their runtime locations
```

## Why each piece exists

- **Local HTTP server** — Chrome extensions like Voiceitt refuse to run on
  `file://` URLs. Serving over `http://localhost:7531` gives Voiceitt a real
  origin to attach to.
- **Regular Chrome window (not `--app`)** — Chrome's `--app=` mode disables
  most extensions. We open a normal window with a unique `<title>` instead.
- **`cliclick` for Cmd+A / Cmd+C** — macOS Sticky Keys (often used by
  one-finger typists) interferes with synthetic modifiers from
  AppleScript's `keystroke "..." using command down`. `cliclick` posts
  CGEvents at a lower level that bypass that interference. Sticky Keys
  continues to work normally for the user's physical typing.
- **iTerm's `write text ... newline yes/no`** — pastes directly into the
  current session via AppleScript, avoiding a synthetic Cmd+V (which Sticky
  Keys can also block). Because it targets the *current* iTerm session, it
  works with whatever you're running there — Amp, a shell, Python, SSH, etc.
- **Sentinel + clipboard polling** — the script stamps the clipboard with
  a known marker before copying, then waits to confirm the clipboard
  actually changed. If the copy silently fails (e.g. wrong app focused),
  you get a macOS notification instead of a stale paste.

## Troubleshooting

- **"Cmd+A/Cmd+C did not capture text" notification** — the textarea wasn't
  focused. Click into it and try again, or use `⌥⇧O` to refocus.
- **Voiceitt palette doesn't appear on the page** — confirm you're on
  `http://localhost:7531/dictate.html` (not `file://`). Try Voiceitt on
  a known-good site (Gmail) first to rule out an extension issue.
- **`cliclick` warns about Accessibility** — when run from iTerm, the
  permission applies to *iTerm*, not cliclick. Add iTerm to System Settings
  → Privacy & Security → Accessibility. For Raycast use, add **Raycast**.
- **Wrong Chrome window comes forward on "Back to Voiceitt"** — keep the
  Scratchpad as the active tab in its window. The script matches by
  window title, which reflects the active tab's `<title>`.
- **Text landed in the wrong iTerm tab** — the scripts target the *current*
  session of the *current* iTerm window. Click the iTerm tab you want to
  receive text into before triggering, or just leave that tab focused while
  you dictate.

## Roadmap

Two larger pieces of follow-up work — pluggable paste target (any app, not
just iTerm) and a possible Raycast store extension — are planned in
[ROADMAP.md](./notes/ROADMAP.md).
