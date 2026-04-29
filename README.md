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

## Files

```
scripts/
  open-voiceitt.sh         # Starts python3 http.server on :7531, opens Chrome window
  send-to-iterm.sh         # Cmd+A/Cmd+C → inject clipboard into current iTerm tab (no Return)
  send-to-iterm-and-run.sh # Same, plus Return (submits the line)
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
[ROADMAP.md](./ROADMAP.md).
