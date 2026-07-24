---
description: Add a persona to this project's active roster (infers from conversation if no argument)
argument-hint: "[persona-name]"
---

Add a persona to `.claude/y-team/team.json`. The argument is optional.

## If a persona name is provided ($ARGUMENTS is non-empty)

1. Verify `${CLAUDE_PLUGIN_ROOT}/agents/$ARGUMENTS.md` exists. If not, tell the user the available personas (list `.md` files in the agents directory) and stop.

2. Read `.claude/y-team/team.json` (create with `{"active": []}` if missing).

3. If the persona is already in `active`, tell the user and stop.

4. Add the persona to `active` and write the file back (preserve JSON formatting — 2-space indent).

5. Confirm: "Added `<persona>` to the active roster. Team Lead will spawn it when needed."

## If no persona name is provided

1. Review the recent conversation context — what is the user working on, what kind of work is needed (UI, backend, mobile, deployment, QA, design)?

2. Read the current active roster from `.claude/y-team/team.json`.

3. List all available personas from `${CLAUDE_PLUGIN_ROOT}/agents/`. Exclude any already in the active roster.

4. Use AskUserQuestion to suggest 2–4 personas that fit the discussed work, each as a single option. Include a short reason in the description ("Recommended because…"). The user picks one (or "Other" to type a custom name).

5. After they select, add the chosen persona to `.claude/y-team/team.json` and confirm.

## Notes

- Always preserve existing entries in `active` — never overwrite.
- `team-lead` is implicitly always active (it's the main pane); do not add it to the file.
- The file lives at `<project>/.claude/y-team/team.json`, not the plugin directory.
