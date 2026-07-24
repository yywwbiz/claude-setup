---
description: Remove a persona from this project's active roster
argument-hint: "<persona-name>"
---

Remove a persona from `.claude/y-team/team.json`.

Steps:

1. If `$ARGUMENTS` is empty, tell the user the command requires a persona name and list the currently active personas from `.claude/y-team/team.json`. Stop.

2. Read `.claude/y-team/team.json` (if missing, tell the user there is no active roster yet and stop).

3. If the persona is not in `active`, tell the user it's not in the roster and list what is. Stop.

4. Remove the persona from `active` and write the file back (preserve JSON formatting — 2-space indent).

5. Confirm: "Removed `<persona>` from the active roster."

6. If a tmux session is running and that persona has a live pane, tell the user the pane is still alive — they can close it manually with `tmux kill-pane` or it will be gone next time they `/y-team:stop` and `/y-team:start`.

## Notes

- Never remove `team-lead`. If the user tries, refuse and explain that Team Lead is structural.
