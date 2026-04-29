#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Send to iTerm & Run
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon 🚀
# @raycast.description Copy from focused app (Voiceitt textarea), inject into the current iTerm tab, then submit. Sticky-Keys safe via cliclick.

set -e
CLICLICK="/opt/homebrew/bin/cliclick"

SENTINEL="__voiceitt_copy_sentinel_$RANDOM__"
printf '%s' "$SENTINEL" | pbcopy

"$CLICLICK" ku:cmd,alt,ctrl,shift,fn >/dev/null 2>&1 || true
sleep 0.05

"$CLICLICK" kd:cmd w:60 t:a w:120 t:c w:60 ku:cmd

CURRENT=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  CURRENT=$(pbpaste)
  if [ "$CURRENT" != "$SENTINEL" ] && [ -n "$CURRENT" ]; then
    break
  fi
  sleep 0.1
done

if [ "$CURRENT" = "$SENTINEL" ] || [ -z "$CURRENT" ]; then
  osascript -e 'display notification "Cmd+A/Cmd+C did not capture text. Make sure the Voiceitt textarea is focused." with title "Send to iTerm & Run"'
  exit 1
fi

osascript <<'EOF'
set clipText to (the clipboard as text)
tell application "iTerm"
  activate
  tell current window
    tell current session
      write text clipText newline yes
    end tell
  end tell
end tell
EOF
