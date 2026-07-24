---
description: List available personas and show which are active for this project
---

Show the user the y-team persona library and active roster.

Steps:

1. List all available personas by reading filenames in `${CLAUDE_PLUGIN_ROOT}/agents/`. Each `.md` file in that directory is one persona; the persona name is the basename without `.md`.

2. Read the active roster from `.claude/y-team/team.json` in the current project. If the file does not exist, treat the active roster as empty.

3. Display a table with two columns:
   - Persona (basename)
   - Status (✓ active / ○ available)

4. Below the table, briefly describe what each persona does (one short line per persona — pull the role description from the `## Role Definition` or opening paragraph of each persona file).

5. Remind the user they can add with `/y-team:add <persona>` or `/y-team:add` (let me infer) and remove with `/y-team:remove <persona>`.
