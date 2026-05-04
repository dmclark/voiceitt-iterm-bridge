#!/bin/bash
# new-shortcut.sh — stamp out a new send-to-<app>.sh from an existing one.
#
# Usage:
#   scripts/new-shortcut.sh --name "Slack" --bundle-id com.tinyspeck.slackmacgap
#   scripts/new-shortcut.sh --name "Notes" --bundle-id com.apple.Notes --base send-to-vscode.sh
#   scripts/new-shortcut.sh --name "Terminal" --bundle-id com.apple.Terminal --base send-to-iterm.sh --force
#
# What it does (and only what it does):
#   1. Slugifies --name into a filename: "VS Code" -> "vs-code".
#   2. Copies scripts/<base> to scripts/send-to-<slug>.sh.
#   3. Substitutes the display name and bundle id in the new file
#      (Raycast header, TARGET_BUNDLE_ID, failure-notification title).
#   4. chmod +x the result and re-runs install.sh so Raycast picks it up.
#
# What it does NOT do (intentionally, per ERD §0.3):
#   - No strategy picker (use --base to choose).
#   - No bundle-id auto-detection from frontmost app (deferred to ROADMAP §2).
#   - No "& Run" companion script.
#   - No editing of the copy preamble; that's destination-agnostic.

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

NAME=""
BUNDLE_ID=""
BASE="send-to-vscode.sh"   # cliclick-paste default — works in most apps
FORCE=0

usage() {
  sed -n '2,20p' "$0"
  exit "${1:-1}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --name)        NAME="$2"; shift 2 ;;
    --bundle-id)   BUNDLE_ID="$2"; shift 2 ;;
    --base)        BASE="$2"; shift 2 ;;
    --force)       FORCE=1; shift ;;
    -h|--help)     usage 0 ;;
    *)             echo "unknown arg: $1" >&2; usage 1 ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$BUNDLE_ID" ]; then
  echo "error: --name and --bundle-id are required" >&2
  usage 1
fi

BASE_PATH="$SCRIPTS_DIR/$BASE"
if [ ! -f "$BASE_PATH" ]; then
  echo "error: base script not found: $BASE_PATH" >&2
  exit 1
fi

# Slugify: lowercase, spaces -> hyphens, strip anything that isn't [a-z0-9-].
SLUG=$(printf '%s' "$NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' _' '--' \
  | tr -cd 'a-z0-9-' \
  | sed -E 's/-+/-/g; s/^-//; s/-$//')

if [ -z "$SLUG" ]; then
  echo "error: name '$NAME' slugified to empty string" >&2
  exit 1
fi

OUT_PATH="$SCRIPTS_DIR/send-to-$SLUG.sh"
if [ -e "$OUT_PATH" ] && [ "$FORCE" -ne 1 ]; then
  echo "error: $OUT_PATH already exists. Pass --force to overwrite." >&2
  exit 1
fi

# Pull the old display name and bundle id out of the base script so we can
# substitute them. Both base scripts follow the same shape.
OLD_NAME=$(grep -E '^# @raycast\.title Send to ' "$BASE_PATH" \
  | sed -E 's/^# @raycast\.title Send to //')
OLD_BUNDLE_ID=$(grep -E '^TARGET_BUNDLE_ID=' "$BASE_PATH" \
  | head -1 | sed -E 's/^TARGET_BUNDLE_ID="?([^"]*)"?$/\1/')

if [ -z "$OLD_NAME" ]; then
  echo "error: could not read '@raycast.title Send to ...' from $BASE_PATH" >&2
  exit 1
fi

# OLD_BUNDLE_ID may legitimately be empty for AppleScript-strategy bases
# (e.g. send-to-iterm.sh hardcodes "iTerm" inside the AppleScript and has no
# TARGET_BUNDLE_ID variable). In that case we can't do a clean substitution —
# warn the user that they'll need to hand-edit step 6.
NEEDS_HAND_EDIT=0
if [ -z "$OLD_BUNDLE_ID" ]; then
  NEEDS_HAND_EDIT=1
fi

# Do the substitutions. Using a temp file + mv to keep this atomic-ish.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Escape sed replacement metachars in the user-supplied strings.
esc() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }
NAME_ESC=$(esc "$NAME")
OLD_NAME_ESC=$(esc "$OLD_NAME")
BUNDLE_ID_ESC=$(esc "$BUNDLE_ID")
OLD_BUNDLE_ID_ESC=$(esc "$OLD_BUNDLE_ID")

# 1) Raycast title
# 2) Notification title in the failure osascript line ("Send to <Old>")
# 3) TARGET_BUNDLE_ID line, if the base has one
sed -E \
  -e "s|(^# @raycast\\.title Send to ).*|\\1${NAME_ESC}|" \
  -e "s|Send to ${OLD_NAME_ESC}|Send to ${NAME_ESC}|g" \
  "$BASE_PATH" > "$TMP"

if [ "$NEEDS_HAND_EDIT" -eq 0 ]; then
  sed -i '' -E \
    -e "s|^TARGET_BUNDLE_ID=\"${OLD_BUNDLE_ID_ESC}\"|TARGET_BUNDLE_ID=\"${BUNDLE_ID_ESC}\"|" \
    "$TMP"
fi

mv "$TMP" "$OUT_PATH"
trap - EXIT
chmod +x "$OUT_PATH"

echo "created  $OUT_PATH"
echo "  base       : $BASE"
echo "  display    : Send to $NAME"
echo "  bundle id  : $BUNDLE_ID"

# Re-run install.sh so the new script gets symlinked into Raycast's dir.
if [ -x "$REPO_DIR/install.sh" ]; then
  "$REPO_DIR/install.sh" >/dev/null
  echo "linked   ~/.config/raycast/scripts/send-to-$SLUG.sh"
fi

if [ "$NEEDS_HAND_EDIT" -eq 1 ]; then
  cat <<EOF

⚠ Base '$BASE' uses the AppleScript strategy and has no TARGET_BUNDLE_ID
  variable to substitute. Open $OUT_PATH and replace the AppleScript body
  in step 6 to talk to '$NAME' (bundle id $BUNDLE_ID) instead of '$OLD_NAME'.
  See README → "Adding a new shortcut" for guidance.
EOF
fi

cat <<EOF

Next steps:
  1. Open Raycast → Settings → Extensions → Script Commands.
  2. Find 'Send to $NAME' and assign a hotkey.
  3. Trigger it once. macOS will prompt to allow Raycast to control $NAME — click Allow.
  4. Verify with Sticky Keys ON: focus $NAME, dictate in the Scratchpad, hit the hotkey.
EOF
