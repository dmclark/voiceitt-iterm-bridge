#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Send to iTerm
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon 🎙️
# @raycast.description Copy from focused app (Voiceitt textarea) and inject into the current iTerm tab. Sticky-Keys safe via cliclick. Does NOT press Return.

set -e
CLICLICK="/opt/homebrew/bin/cliclick"

# 1) Stamp clipboard with a sentinel so we can detect whether copy actually fired.
SENTINEL="__voiceitt_copy_sentinel_$RANDOM__"
printf '%s' "$SENTINEL" | pbcopy

# 2) Release any stuck modifiers (Sticky Keys can latch Cmd from earlier typing).
"$CLICLICK" ku:cmd,alt,ctrl,shift,fn >/dev/null 2>&1 || true
sleep 0.05

# 3) Sticky-Keys-proof Cmd+A then Cmd+C in the currently focused app.
"$CLICLICK" kd:cmd w:60 t:a w:120 t:c w:60 ku:cmd

# 4) Wait (up to ~1s) for the clipboard to change off the sentinel.
CURRENT=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  CURRENT=$(pbpaste)
  if [ "$CURRENT" != "$SENTINEL" ] && [ -n "$CURRENT" ]; then
    break
  fi
  sleep 0.1
done

# 5) Bail out loudly if copy never landed, instead of pasting stale text.
if [ "$CURRENT" = "$SENTINEL" ] || [ -z "$CURRENT" ]; then
  osascript -e 'display notification "Cmd+A/Cmd+C did not capture text. Make sure the Voiceitt textarea is focused." with title "Send to iTerm"'
  exit 1
fi

# 6) Inject clipboard text directly into iTerm's current session.
osascript <<'EOF'
set clipText to (the clipboard as text)
tell application "iTerm"
  activate
  tell current window
    tell current session
      write text clipText newline no
    end tell
  end tell
end tell
EOF
