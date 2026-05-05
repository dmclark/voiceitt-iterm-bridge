#!/bin/bash
# Symlink the scripts and the HTML scratchpad into the locations Raycast and
# the open-voiceitt server expect. Safe to re-run.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RAYCAST_DIR="$HOME/.config/raycast/scripts"
BRIDGE_DIR="$HOME/.config/voiceitt-bridge"

mkdir -p "$RAYCAST_DIR" "$BRIDGE_DIR"

# Remove stale symlinks from the previous "amp" naming, if present.
for stale in send-to-amp.sh send-to-amp-and-run.sh; do
  if [ -L "$RAYCAST_DIR/$stale" ]; then
    rm -f "$RAYCAST_DIR/$stale"
    echo "removed stale  $RAYCAST_DIR/$stale"
  fi
done

for f in "$REPO_DIR"/scripts/*.sh; do
  # Only symlink real Raycast Script Commands. Helpers like new-shortcut.sh
  # have no @raycast.schemaVersion header and should stay out of Raycast's dir.
  if ! grep -q '^# @raycast\.schemaVersion' "$f"; then
    continue
  fi
  name="$(basename "$f")"
  target="$RAYCAST_DIR/$name"
  ln -sfn "$f" "$target"
  chmod +x "$f"
  echo "linked  $target  ->  $f"
done

ln -sfn "$REPO_DIR/bridge/dictate.html" "$BRIDGE_DIR/dictate.html"
echo "linked  $BRIDGE_DIR/dictate.html  ->  $REPO_DIR/bridge/dictate.html"

# serve.py: tiny HTTP server with a POST /transform endpoint that shells
# out to voiceitt-transform. Replaces `python3 -m http.server` (see
# scripts/open-voiceitt.sh and bridge/serve.py).
ln -sfn "$REPO_DIR/bridge/serve.py" "$BRIDGE_DIR/serve.py"
echo "linked  $BRIDGE_DIR/serve.py  ->  $REPO_DIR/bridge/serve.py"

# voiceitt-transform: the LLM-cleaning CLI. Not a Raycast Script Command
# (no @raycast.schemaVersion header), so the Raycast loop above skips it;
# symlink it explicitly so serve.py can find it next to itself.
ln -sfn "$REPO_DIR/scripts/voiceitt-transform" "$BRIDGE_DIR/voiceitt-transform"
chmod +x "$REPO_DIR/scripts/voiceitt-transform"
echo "linked  $BRIDGE_DIR/voiceitt-transform  ->  $REPO_DIR/scripts/voiceitt-transform"

cat <<MSG

Done. Next steps:
  1. Open Raycast → Settings → Extensions → Script Commands → Add Script Directory
  2. Pick: $RAYCAST_DIR
  3. Assign hotkeys to each of the four commands.

If you haven't already:
  - brew install cliclick
  - Grant Accessibility permission to Raycast (System Settings → Privacy & Security → Accessibility)

MSG
