# y-team

A Claude Code plugin for running a self-orchestrating agent team in tmux. You install it once and use it on any project. The Team Lead agent decides which specialists are needed and spawns them itself — no manual pane management.

---

## How it works

```
You (stakeholder)
    │
    ▼
Team Lead  ──spawn──►  Product-Architect
(pane 0)   ──spawn──►  Engineer Web / iOS / Android / Backend
           ──spawn──►  Designer
           ──spawn──►  QA
           ──spawn──►  SRE
```

- **Team Lead** lives in the left pane. It's the only agent you talk to.
- The active roster (which personas are available for *this* project) lives in `.claude/y-team/team.json`.
- All other agents are spawned by Team Lead on demand via the plugin's `spawn-agent.sh`.
- Agents signal back to Team Lead when their work is done; Team Lead gates each phase transition.
- Agent-to-agent messages are delivered automatically by `inbox-watcher.js`.

---

## Personas

| Persona | When to add to a project |
|---|---|
| `team-lead` | Always — orchestrator. Implicit, no need to add. |
| `product-architect` | Almost always — owns REQUIREMENTS.md and PLAN.md (merged PM + Architect role). |
| `engineer-web` | Web frontend work. |
| `engineer-ios` | iOS app work. |
| `engineer-android` | Android app work. |
| `engineer-backend` | API / services / data layer work. |
| `designer` | UI work that needs flows, specs, accessibility planning. |
| `qa` | Almost always — verifies acceptance criteria, writes integration + e2e tests. |
| `sre` | Anything that deploys. Covers DevOps / CI-CD too. |

Pick a small set per project. A typical web app might run `team-lead` + `product-architect` + `engineer-web` + `engineer-backend` + `qa` + `sre`. Mobile-only projects swap engineers accordingly.

---

## Prerequisites

- [tmux](https://github.com/tmux/tmux)
- [Claude Code CLI](https://claude.ai/code) (`claude` on PATH)
- Node.js (for the inbox watcher)

---

## Install (local)

This plugin is local-only — it ships a marketplace manifest that points at the directory on disk. There's no remote install yet.

From any Claude Code session:

```
/plugin marketplace add /Users/yujungs700/dev/pet/claude-setup/.claude-plugin/marketplace.json
/plugin install y-team@y-team-marketplace
```

The marketplace `path` in `.claude-plugin/marketplace.json` is absolute, so it only works on this machine and at this exact location. If you move the repo, edit `path` accordingly.

After install, the `/y-team:*` commands are available globally — in any project, any session.

### Update

Because the plugin is `source: directory`, it reads from disk on load — so updates are just: pull the latest, then tell Claude Code to reload.

```bash
# In the plugin directory
cd /Users/yujungs700/dev/pet/claude-setup
git pull
```

Then in any Claude Code session:

```
/reload-plugins
```

That's it. No uninstall/reinstall needed. Changes to `commands/`, `agents/`, `scripts/`, `.claude-plugin/plugin.json` all pick up after `/reload-plugins`.

**Note:** `/plugin update` only works for git/URL-sourced plugins. Since this one is `source: directory`, you use `git pull` + `/reload-plugins` instead.

### Uninstall

```
/plugin uninstall y-team@y-team-marketplace
/plugin marketplace remove y-team-marketplace
```

### Iterating on the plugin itself

If you're actively editing this plugin's files (not just pulling updates), `/reload-plugins` picks up the changes between turns. No need to uninstall/reinstall.

---

## Use it on a project

### First-time kickoff (recommended)

From a fresh project directory:

```
/y-team:init
```

This walks you through a short conversational kickoff: what you're building, who it's for, any constraints. Based on your answers it proposes a roster, scaffolds `CLAUDE.md` and `.claude/y-team/team.json`, and offers to boot the tmux session. One command, project ready.

### Manual setup (if you prefer)

1. List available personas:
   ```
   /y-team:list
   ```

2. Add what you need (explicitly or by inference):
   ```
   /y-team:add engineer-web
   /y-team:add               # infers from recent discussion
   ```

3. Start the tmux session:
   ```
   /y-team:start
   ```

### Day-to-day

- Switch to the tmux session and talk to Team Lead. Team Lead reads `.claude/y-team/team.json` and spawns specialists as phases need them.
- You can also talk to specialist panes directly when you want to be in the weeds (e.g. whiteboarding with product-architect). Team Lead stays in charge of gates and milestones.
- `/y-team:status` shows the running session and live panes.
- `/y-team:stop` kills the session.

---

## Commands

| Command | What it does |
|---|---|
| `/y-team:init` | Conversational project kickoff — gathers brief, proposes roster, scaffolds CLAUDE.md and team.json |
| `/y-team:start` | Boot tmux session, launch Team Lead in pane 0 |
| `/y-team:list` | Show library personas + this project's active roster |
| `/y-team:add [persona]` | Add a persona to the active roster (infers from conversation if omitted) |
| `/y-team:remove <persona>` | Remove a persona from the active roster |
| `/y-team:status` | Show running session and live agent panes |
| `/y-team:stop` | Kill the tmux session |
| `/y-team:bug` | Report a bug in y-team — collects diagnostics and files a GitHub issue |

---

## Project file layout (created by Team Lead during work)

```
your-project/
├── .claude/
│   └── y-team/
│       ├── team.json          # active roster for this project
│       ├── ACTIVITY.md        # living log of tasks done, bugs fixed, phase gates (maintained by Team Lead)
│       └── inbox/             # agent-to-agent messages (runtime only, gitignored)
├── .claude/y-team/planning/
│   ├── ROADMAP.md             # phase order and status
│   ├── STATE.md               # live blockers, decisions, open questions
│   └── PHASE-<N>/
│       ├── REQUIREMENTS.md    # user stories + acceptance criteria
│       ├── DESIGN.md          # flows, specs, a11y (optional)
│       ├── PLAN.md            # task breakdown + assignments
│       └── VERIFICATION.md    # QA findings and sign-off
└── ... (your code)
```

### Activity log

`.claude/y-team/ACTIVITY.md` is a running dated log Team Lead appends to whenever work lands: completed tasks (with commit hash), bugs fixed, and phase gates (PLAN ready / VERIFIED / DEPLOYED). It's committed to the repo so you always have a traceable trail of what was done and when.

The `.claude/y-team/planning/` convention is borrowed from GSD but the plugin does not depend on the GSD plugin — the personas have the phase lifecycle baked in.

---

## Agent-to-agent messaging

`scripts/inbox-watcher.js` polls each agent's inbox file and feeds unread messages into the agent's tmux pane automatically. `scripts/send-inbox.js` writes messages to an agent's inbox.

Inboxes are stored at `.claude/y-team/inbox/<agent-name>.json` inside the project directory — one inbox directory per project, never shared globally. Running y-team on two projects simultaneously keeps their agent communication completely separate. `/y-team:init` adds `.claude/y-team/inbox/` to `.gitignore` so inbox files are never committed.

Watcher logs go to `/tmp/inbox-watcher-<session>.log`.

---

## Tmux quick reference

| Action | Key |
|---|---|
| Detach (session keeps running) | `Ctrl+B D` |
| Reattach | `tmux attach -t <session>` |
| Switch panes | Click (mouse on) or `Ctrl+B` arrow keys |
| Scroll in pane | Mouse scroll or `Ctrl+B [` then arrow keys |
| Kill session | `/y-team:stop` or `tmux kill-session -t <session>` |
