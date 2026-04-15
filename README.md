# claude-setup

Templates for running a self-orchestrating Claude Code agent team in tmux.

The human starts one session. The Team Lead agent decides which specialist agents are needed and spawns them itself — no manual pane management required.

---

## How it works

```
You (stakeholder)
    │
    ▼
Team Lead  ──spawn──►  Architect
(pane 0)   ──spawn──►  Engineer Web
           ──spawn──►  QA Agent
           ──spawn──►  SRE Agent
```

- **Team Lead** lives in the left pane. It's the only agent you talk to.
- All other agents are spawned by the Team Lead on demand via `scripts/spawn-agent.sh`.
- Agents signal back to the Team Lead when their work is done; the Team Lead gates each phase transition.
- Agent-to-agent messages are delivered automatically by `scripts/inbox-watcher.js`.

---

## Prerequisites

- [tmux](https://github.com/tmux/tmux)
- [Claude Code CLI](https://claude.ai/code) (`claude` on PATH)
- Node.js (for the inbox watcher)
- [GSD](https://github.com/dnl-fm/get-shit-done-cc) installed in the project: `npx get-shit-done-cc@latest --claude --local`

---

## Setup

### 1. Copy templates into your project

```bash
cp -r templates/. /path/to/your/project/
```

This copies:
```
CLAUDE.md                  # project config — edit placeholders
start-session.sh           # human entry point
scripts/
  spawn-agent.sh           # called by Team Lead to open agent panes
  inbox-watcher.js         # delivers agent-to-agent messages
personas/
  team-lead.md
  pm.md
  architect.md
  engineer-web.md
  engineer-ios.md
  engineer-android.md
  qa.md
  sre.md
```

### 2. Edit `CLAUDE.md`

Replace the placeholders:

| Placeholder | Replace with |
|---|---|
| `{{PROJECT_NAME}}` | Your project name |
| `{{SPEC_FILE}}` | Path to your main spec/design doc (e.g. `docs/SPEC.md`) |
| `{{ENV_VAR_1}}` | Required env vars |
| `{{SETUP_CMD}}` | Project setup command (e.g. `npm install`) |

Comment out any agent roles you don't need in the `# AGENTS` block.

### 3. Make scripts executable

```bash
chmod +x start-session.sh scripts/spawn-agent.sh
```

### 4. Start the session

```bash
./start-session.sh
```

This opens a tmux session with the Team Lead pane and launches `claude --dangerously-skip-permissions`. You're now talking to the Team Lead.

---

## Agent roster

| Agent | File | When Team Lead spawns it |
|---|---|---|
| PM | `personas/pm.md` | Large projects with complex product requirements |
| Architect | `personas/architect.md` | When phase context is ready and a PLAN.md is needed |
| Engineer Web | `personas/engineer-web.md` | After PLAN.md is ready (web tasks assigned) |
| Engineer iOS | `personas/engineer-ios.md` | After PLAN.md is ready (iOS tasks assigned) |
| Engineer Android | `personas/engineer-android.md` | After PLAN.md is ready (Android tasks assigned) |
| QA | `personas/qa.md` | After all assigned engineers signal completion |
| SRE | `personas/sre.md` | After QA signals the phase is verified |

PM is optional — skip it on smaller projects and let the Team Lead handle phase context directly.

---

## How the Team Lead spawns agents

The Team Lead calls `scripts/spawn-agent.sh` via its Bash tool:

```bash
./scripts/spawn-agent.sh <session> <agent-label>
```

- `session` — the tmux session name (printed when you ran `start-session.sh`)
- `agent-label` — case-insensitive, partial match against the AGENTS block (e.g. `arch`, `eng web`, `qa`)

The script:
1. Verifies the session exists
2. Matches the label against `CLAUDE.md`'s AGENTS block
3. Splits a new pane, rebalances to main-vertical layout
4. Launches `claude --dangerously-skip-permissions` in the new pane
5. Starts the inbox watcher for that agent
6. Sends the role prompt

---

## Agent-to-agent messaging

`scripts/inbox-watcher.js` polls each agent's inbox file in `~/.claude/teams/default/inboxes/` and feeds unread messages into the agent's tmux pane automatically.

Agents write to each other's inboxes using the Claude Code SendMessage tool. The watcher picks up the message and types it into the target pane.

Watcher logs go to `/tmp/inbox-watcher-<session>.log`.

---

## Tmux quick reference

| Action | Key |
|---|---|
| Detach (session keeps running) | `Ctrl+B D` |
| Reattach | `tmux attach -t <session>` |
| Switch panes | Click (mouse on) or `Ctrl+B` arrow keys |
| Scroll in pane | Mouse scroll or `Ctrl+B [` then arrow keys |
| Kill session | `tmux kill-session -t <session>` |
