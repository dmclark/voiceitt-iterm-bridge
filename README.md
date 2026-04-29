# voiceitt-amp-bridge

A small toolkit that lets you dictate prompts with [Voiceitt](https://www.voiceitt.com/)
(a Chrome-only voice dictation extension) and send them straight to the
[Amp CLI](https://ampcode.com/) running in iTerm, then jump back to dictate the next prompt.

## Why

Voiceitt only works in Chrome. The Amp CLI runs in a terminal. This bridges the gap
without any custom server, web UI, or API integration — just a tiny local HTML
scratchpad served over `http://localhost`, plus a few Raycast Script Commands.

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
                                   │  Amp CLI in iTerm   │
                                   ╰────────────────────╯
```

## Prerequisites

- macOS (tested on macOS Tahoe)
- [Raycast](https://www.raycast.com/) — for global hotkeys + script commands
- [iTerm2](https://iterm2.com/) — your Amp CLI terminal
- Google Chrome with the Voiceitt extension installed
- `python3` (ships with macOS / Xcode CLT) — runs the local web server
- `cliclick` (`brew install cliclick`) — sends Cmd+A/Cmd+C reliably under Sticky Keys
- Accessibility permissions granted to **Raycast** (and **iTerm** if you'll test from a terminal)

## Install

```bash
git clone <this-repo> ~/voiceitt-amp-bridge
cd ~/voiceitt-amp-bridge
./install.sh
```

`install.sh` symlinks the scripts into `~/.config/raycast/scripts/` and the
HTML scratchpad into `~/.config/voiceitt-bridge/`. Then in Raycast:

1. Settings → Extensions → Script Commands → **Add Script Directory**
2. Pick `~/.config/raycast/scripts`
3. Assign hotkeys to each command (suggestions below).

## Hotkey suggestions

| Command                    | Suggested hotkey | What it does                                                      |
| -------------------------- | ---------------- | ----------------------------------------------------------------- |
| Open Voiceitt Scratchpad   | `⌥⇧O`            | Starts the local server (if needed) and opens the page in Chrome. |
| Send to Amp                | `⌥⇧V`            | Cmd+A/Cmd+C in Chrome, paste into iTerm. Doesn't press Return.    |
| Send to Amp & Run          | `⌥⇧↩`            | Same as above plus Return — submits to Amp.                       |
| Back to Voiceitt           | `⌥⇧B`            | Brings the Scratchpad Chrome window forward by title.             |

## Daily use

1. `⌥⇧O` — Scratchpad opens in Chrome (light theme, big textarea).
2. Activate Voiceitt and dictate. Text appears in the textarea.
3. `⌥⇧V` (or `⌥⇧↩`) — text lands in iTerm's Amp prompt.
4. `⌥⇧B` — returns to the Scratchpad. `⌘K` clears the textarea for the next prompt.

## Files

```
scripts/
  open-voiceitt.sh       # Starts python3 http.server on :7531, opens Chrome window
  send-to-amp.sh         # Cmd+A/Cmd+C → inject clipboard into iTerm (no Return)
  send-to-amp-and-run.sh # Same, plus Return (submits to Amp)
  back-to-voiceitt.sh    # Find Chrome window titled "Voiceitt Scratchpad", raise it
bridge/
  dictate.html           # The Scratchpad page (light theme, autofocus, ⌘K to clear)
install.sh               # Symlinks scripts and html to their runtime locations
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
  Keys can also block).
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
