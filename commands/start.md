---
description: Start the y-team tmux session — boots Team Lead in pane 0
---

Run the y-team session-start script for this project.

Steps:

1. Confirm `.claude/y-team/team.json` exists in the project. If it does not, create it with this minimum content:
   ```json
   {
     "active": ["team-lead", "product-architect"]
   }
   ```
   Tell the user the default roster was created and they can add more with `/y-team:add`.

2. Run the start script via Bash:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/start-session.sh
   ```

3. After the session is created, tell the user:
   - The tmux session name (basename of the project directory)
   - That Team Lead is now running in pane 0
   - That they should switch to that tmux session to talk to Team Lead
