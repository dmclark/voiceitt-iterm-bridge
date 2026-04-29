#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Back to Voiceitt
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon 🌐
# @raycast.description Bring the Voiceitt Scratchpad Chrome window forward by its title.

PAD_TITLE="Voiceitt Scratchpad"

osascript <<EOF
tell application "Google Chrome"
  activate
  set found to false
  repeat with w in windows
    if title of w contains "$PAD_TITLE" then
      set index of w to 1
      set found to true
      exit repeat
    end if
  end repeat
  if not found then
    do shell script "osascript -e 'display notification \"Scratchpad window not found. Run Open Voiceitt Scratchpad first.\" with title \"Back to Voiceitt\"'"
  end if
end tell
EOF
