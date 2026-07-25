---
description: Report a bug in the y-team setup — collects diagnostics and shows a formatted report
---

Guide the user through preparing a bug report against the y-team plugin. Collect context automatically, format the report, and show it in the conversation. Filing is always the user's choice — never auto-file.

## Flow

### 1. Get the bug description

Ask the user two questions (can be in one message):

> "Describe the bug:
> 1. What happened?
> 2. What did you expect to happen instead?
>
> If you know the steps to reproduce, include those too."

Wait for their answer. Don't move on until you have at least a description of what went wrong.

### 2. Collect diagnostics automatically

Run all of the following in parallel via Bash. Tell the user "Collecting diagnostics…" while this runs.

```bash
# Plugin version
git -C "${CLAUDE_PLUGIN_ROOT}" log --oneline -1 2>/dev/null || echo "unknown"

# Active roster (if in a project)
cat .claude/y-team/team.json 2>/dev/null || echo "(no team.json — not in a y-team project)"

# Recent inbox watcher logs (last 50 lines across all sessions)
tail -n 50 /tmp/inbox-watcher-*.log 2>/dev/null || echo "(no watcher logs found)"

# Recent activity log (last 20 lines)
tail -n 20 .claude/y-team/ACTIVITY.md 2>/dev/null || echo "(no ACTIVITY.md found)"

# Platform info
echo "OS: $(uname -s) $(uname -r)"
echo "Shell: ${SHELL}"
node --version 2>/dev/null
tmux -V 2>/dev/null
```

### 3. Format and show the report

Derive a concise title from the user's description (do not ask). Then render the full report in the conversation as a markdown code block so the user can copy it:

```markdown
## What happened
<user's description>

## Expected behavior
<user's expected behavior>

## Steps to reproduce
<user's steps, or "Not provided" if they didn't include them>

## Diagnostics

**Plugin version:** <git hash and message>

**Active roster:**
<team.json contents or "(not in a y-team project)">

**Inbox watcher logs (last 50 lines):**
<log tail or "(none found)">

**Recent activity:**
<ACTIVITY.md tail or "(none found)">

**Environment:**
<platform/shell/node/tmux versions>
```

After showing the report, tell the user:

> "You can file this at **https://github.com/yywwbiz/claude-setup/issues/new** — paste the title and body above.
> If you'd like me to try filing it via `gh` CLI, just say so."

### 4. Only file via gh if the user explicitly asks

If the user says to try `gh`:

```bash
gh issue create \
  --repo yywwbiz/claude-setup \
  --title "<title>" \
  --body "<body>" 2>&1
```

If the command succeeds, print the issue URL.

If it fails (wrong domain, auth, network), tell the user what went wrong and remind them they can file manually at the URL above. Do not write the report to any file.

## Notes

- Never take an outward action (filing, writing files) without the user explicitly asking.
- Trim watcher logs to the most recent 50 lines — don't dump hundreds of lines.
- Replace home directory paths with `~` before including in the report.
- If not in a y-team project directory, skip team.json and ACTIVITY.md gracefully.
