#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Open Voiceitt Scratchpad
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon 🪟
# @raycast.description Start a tiny localhost HTTP server (so Chrome extensions like Voiceitt work) and open the Scratchpad in Chrome.

PAD_DIR="$HOME/.config/voiceitt-bridge"
PAD_PORT=7531
PAD_URL="http://localhost:${PAD_PORT}/dictate.html"
PAD_TITLE="Voiceitt Scratchpad"
LOG_FILE="$PAD_DIR/server.log"

# 1) If a Chrome window with our title is already open, just bring it forward.
ALREADY_OPEN=$(osascript <<EOF
tell application "Google Chrome"
  set found to false
  repeat with w in windows
    if title of w contains "$PAD_TITLE" then
      set index of w to 1
      activate
      set found to true
      exit repeat
    end if
  end repeat
  return found
end tell
EOF
)

if [ "$ALREADY_OPEN" = "true" ]; then
  exit 0
fi

# 2) Make sure our local HTTP server is running on $PAD_PORT.
if ! lsof -iTCP:"$PAD_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  # Start in the background, detached, surviving this script's exit.
  nohup python3 -m http.server "$PAD_PORT" --bind 127.0.0.1 --directory "$PAD_DIR" \
    >>"$LOG_FILE" 2>&1 </dev/null &
  disown 2>/dev/null || true

  # Wait briefly for it to bind.
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if lsof -iTCP:"$PAD_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
fi

# 3) Open the page in a new Chrome window so Voiceitt can attach to it.
open -na "Google Chrome" --args --new-window "$PAD_URL"
