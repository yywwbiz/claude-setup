---
description: Kill the y-team tmux session for this project
---

Stop the running y-team session.

Steps:

1. Determine the session name: basename of the current project directory.

2. Check if the session exists:
   ```bash
   tmux has-session -t "<session>" 2>/dev/null
   ```

3. If not running: tell the user there's no session to stop and exit.

4. **Confirm with the user before killing.** Killing the session terminates all agent panes and their Claude conversations. Ask: "About to kill tmux session `<session>` — this terminates Team Lead and all spawned agents. Confirm?"

5. After confirmation, kill the session:
   ```bash
   tmux kill-session -t "<session>"
   ```

6. Also kill any inbox-watcher processes for that session:
   ```bash
   pkill -f "inbox-watcher.js <session>" 2>/dev/null || true
   ```

7. Confirm: "Session `<session>` stopped. Inbox watchers cleaned up."
