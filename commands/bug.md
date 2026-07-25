---
description: Report a bug in the y-team setup — collects diagnostics and files a GitHub issue
---

Guide the user through filing a bug report against the y-team plugin repo. Collect context automatically so the report is actionable without back-and-forth.

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

### 3. Compose the issue

Build a GitHub issue from the collected information:

**Title:** one concise line summarizing the bug (derive from the user's description — do not ask)

**Body:**
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

### 4. Preview and confirm

Show the user the full issue title and body. Ask:

> "Does this look right? I'll file it to yywwbiz/claude-setup. (yes / edit / cancel)"

- **yes** → proceed to step 5
- **edit** → ask what to change, update the draft, re-confirm
- **cancel** → stop; offer to print the markdown so they can file it manually

### 5. File the issue

Check if `gh` is available:
```bash
gh --version 2>/dev/null
```

**If `gh` is available:**
```bash
gh issue create \
  --repo yywwbiz/claude-setup \
  --title "<title>" \
  --body "<body>"
```
Print the issue URL when done.

**If `gh` is not available:**
Tell the user:
> "`gh` CLI is not installed or not authenticated. Here's the formatted bug report — you can paste it directly into a new issue at https://github.com/yywwbiz/claude-setup/issues/new"

Then print the full markdown.

## Notes

- Never file without explicit confirmation.
- If the watcher logs are very long, trim to the most recent 50 lines — don't dump hundreds of lines into the issue.
- Sensitive paths (home directory) in logs should be replaced with `~` before including.
- If the user is not currently in a y-team project directory, that's fine — skip the team.json and ACTIVITY.md sections gracefully.
