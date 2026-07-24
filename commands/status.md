---
description: Show running tmux session info, live agent panes, and project progress
---

Show the user the current y-team session state and project progress.

Steps:

1. Determine the expected session name: basename of the current project directory.

2. Read project state files (do all reads in parallel):
   - `.planning/LAST_SESSION.md` — where things left off
   - `.planning/ROADMAP.md` — phase list and statuses
   - `.claude/y-team/team.json` — active roster

3. Check if the tmux session exists:
   ```bash
   tmux has-session -t "<session>" 2>/dev/null && echo "running" || echo "stopped"
   ```

4. If running, list the panes:
   ```bash
   tmux list-panes -t "<session>" -F '#{pane_index} #{@agent} #{pane_title}'
   ```

5. Output a single status block with two sections:

   **Project**
   - Current phase and stage (from LAST_SESSION.md, or "not started" if absent)
   - Last completed action and next action (from LAST_SESSION.md)
   - Open blockers if any
   - Phase list from ROADMAP.md: one line each showing phase name and status (done / active / pending)

   **Team session** (`<session-name>`)
   - "running" or "stopped — run /y-team:start to boot"
   - If running: each live pane's agent label
   - Active roster from team.json, marking which are currently spawned vs. not yet spawned

Keep the output tight — this should be scannable in a few seconds, not a wall of text.
