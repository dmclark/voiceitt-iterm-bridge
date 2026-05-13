---
name: adding-send-to-target
description: "Scaffolds a new send-to-<app>.sh Raycast Script Command that pipes the Voiceitt scratchpad into a target macOS app. Use when the user asks to add, wire up, or support a new send-to target (e.g., 'add a send-to-Slack', 'wire up Notes', 'make a Raycast shortcut for <app>'). Enforces the Sticky-Keys-safe paste ritual that is the entire point of this repo."
---

# adding-send-to-target

Add a new `scripts/send-to-<app>.sh` Raycast Script Command. Most of the work is already done by `scripts/new-shortcut.sh` — your job is to pick the right base script, run the helper, and verify.

## When to load

Trigger phrases:

- "add a send-to-<app>"
- "wire up <app> as a Raycast target"
- "make a Voiceitt shortcut for <app>"
- "support <app> in the bridge"

Do **not** use this skill for non-target scripts (e.g., `open-voiceitt.sh`, `new-shortcut.sh`, `voiceitt-transform`) or for editing `bridge/dictate.html`.

## Workflow

### 1. Pick the strategy

Two strategies exist. Choose by asking: does the target app have a useful AppleScript dictionary for inserting text into its active session/document?

| Strategy           | When to use                                                                 | Base script                          |
|--------------------|------------------------------------------------------------------------------|--------------------------------------|
| **cliclick paste** | Default. Anything that's a normal text field / editor / chat input.         | `scripts/send-to-vscode.sh`          |
| **AppleScript**    | Only when the app exposes something like `tell session to write text …`.    | `scripts/send-to-iterm.sh`           |

If unsure, default to cliclick paste. It works in 95% of apps.

### 2. Find the bundle id

```
osascript -e 'id of app "AppName"'
```

If the user already gave the bundle id, skip this.

### 3. Run the helper

```
scripts/new-shortcut.sh --name "<Display Name>" --bundle-id <bundle.id> [--base send-to-iterm.sh]
```

`new-shortcut.sh` does all of:

- Slugifies the name into `send-to-<slug>.sh`
- Copies the chosen base script
- Substitutes the Raycast title, notification title, and (for cliclick base) `TARGET_BUNDLE_ID`
- `chmod +x` and re-runs `install.sh` so Raycast picks it up

If the user passed `--base send-to-iterm.sh` (AppleScript strategy), the helper prints a ⚠ warning that **step 6** of the new script must be hand-edited — the AppleScript body still talks to iTerm. Open the file and rewrite step 6 to drive the new app's scripting dictionary.

### 4. Verify the script keeps the Sticky-Keys ritual intact

The base scripts already encode this; only worry if you hand-edit. Steps 1–5 of every `send-to-*.sh` MUST remain:

1. Stamp clipboard with a `SENTINEL`
2. Release stuck modifiers via `cliclick ku:cmd,alt,ctrl,shift,fn`
3. Issue Cmd+A / Cmd+C through `cliclick` (NOT AppleScript `keystroke … using command down`)
4. Poll `pbpaste` for ~1s to confirm copy fired
5. On timeout, `osascript display notification` and `exit 1` — never paste stale text

Step 6 (the destination-specific paste) is the only part that varies between scripts.

### 5. Required Raycast headers

`install.sh` filters on `@raycast.schemaVersion`, so a script without these will not appear in Raycast. The base scripts already have them; preserve all six lines:

```bash
# @raycast.schemaVersion 1
# @raycast.title Send to <App>
# @raycast.mode silent
# @raycast.packageName Voiceitt
# @raycast.icon <emoji>
# @raycast.description <one line>
```

### 6. Verify it actually works

There are no automated tests. State explicitly that verification requires the user (on macOS, with Sticky Keys ON):

1. Re-run `./install.sh` (already done by `new-shortcut.sh`, but mention it)
2. Trigger the new Raycast command via its hotkey
3. Confirm text lands intact in the target app
4. Confirm no modifier keys stay latched after

If you cannot run this yourself (you almost certainly can't), say so — do not imply verification passed.

### 7. Commit

One logical change per commit. Branch prefix `feat/` (it's new functionality):

```
feat(scripts): add send-to-<app>
```

Stay on whatever branch the user is on unless they ask otherwise. Never push without explicit instruction.

## Things that will break the bridge

- Replacing `cliclick` with AppleScript `keystroke … using command down` — defeats the entire Sticky-Keys-safety purpose of this repo
- Adding the `@raycast.schemaVersion` header to a non-Raycast helper (it'll be symlinked into `~/.config/raycast/scripts/` and clutter the launcher)
- Hand-editing the base scripts to "improve" steps 1–5 — they're load-bearing
