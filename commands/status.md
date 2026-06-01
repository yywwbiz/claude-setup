---
description: Show running tmux session info and live agent panes
---

Show the user the current y-team session state.

Steps:

1. Determine the expected session name: basename of the current project directory.

2. Check if the tmux session exists via Bash:
   ```bash
   tmux has-session -t "<session>" 2>/dev/null && echo "running" || echo "stopped"
   ```

3. If stopped: tell the user the session is not running and suggest `/y-team:start`. Stop.

4. If running, list the panes:
   ```bash
   tmux list-panes -t "<session>" -F '#{pane_index} #{@agent} #{pane_title}'
   ```

5. Show:
   - Session name
   - Number of panes
   - Each pane's index and agent label (the `@agent` variable, or pane title as fallback)

6. Show the active roster from `.claude/team.json` for comparison — so the user can see which active personas are currently spawned vs. not.
