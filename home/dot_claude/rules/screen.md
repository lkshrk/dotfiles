# Taking over the screen: announce first, then wait for "go"

The user is often working or gaming on the desktop while I run. Anything that changes what they see or what receives their input is taking over the screen, and is a hard stop:

- focusing, moving, resizing, closing or killing windows (`hyprctl dispatch`, `quit-app`, `focus-app`, `kill`/`systemctl kill` of a GUI app's process or unit);
- launching or restarting GUI apps, the shell or the bar (`omarchy restart …`, `hyprctl reload`);
- switching workspaces or monitors, changing display layout, brightness, locking or blanking screens;
- typing, clicking or pasting into windows (`wtype`, `ydotool`, `wl-copy` over the user's clipboard), screenshots or screen recording.

Before any of these:

1. Say exactly what will happen on screen and which window or app it touches, in the reply, before the tool call.
2. Wait for the user to answer "go" (or equivalent). Approval covers that one action only.
3. Never run a command that acts on "the active/focused window". Target by window address, pid or unit, and verify the target right before acting. A focus dispatch can fail silently and leave a different window (a game) active.

If the target can't be pinned down safely, don't act: describe the command and let the user run it.

This applies to me and to every subagent I dispatch.
