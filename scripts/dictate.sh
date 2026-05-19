#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Dictate (raw)
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon 🎤
# @raycast.description Open the Voiceitt scratchpad with AI post-processing OFF (raw passthrough).

set -e

# Force the in-page AI toggle to OFF via ?ai=0; honored by dictate.html.
# Delegates everything else (server boot, window-raise, env sourcing) to
# open-voiceitt.sh — install.sh symlinks both scripts into the same dir,
# so $(dirname "$0")/open-voiceitt.sh resolves correctly under Raycast.
export VOICEITT_AI_MODE=0
exec "$(dirname "$0")/open-voiceitt.sh"
