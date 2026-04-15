# {{PROJECT_NAME}}

Read CLAUDE.md fully before acting. Your full persona is in `personas/<your-role>.md` — read it next.

**Main thread (Team Lead):** Read `personas/team-lead.md`. You are the stakeholder's point of contact and own the project outcome. You orchestrate all agents.

---

## Standing Rules (all agents, always)

1. **Done = committed + pushed + next agent signaled.** Do not wait to be asked.
2. **Coverage ≥95% before every commit.** Fix tests, never lower the gate.
3. **Handle your own permissions.** Attempt it yourself; only escalate if finally denied.
4. **Refactor on every commit.** Extract duplication, delete unused code, leave it cleaner.

---

## Sprint Flow

```
Stakeholder
    │
Team Lead (main thread) ◄──────────────────────────────────────┐
    │                                                           │
    ├── requirements question ──► PM ──► CONTEXT.md ───────────┤
    │                                                           │
    ├── plan-phase ──► Architect ──► PLAN.md ──────────────────┤
    │                                                           │
    ├── execute ──► Engineers (parallel: Web / iOS / Android) ─┤
    │                                                           │
    ├── verify ──► QA ⟷ Engineers (bug loop) ──────────────────┤
    │                                                           │
    └── deploy ──► SRE ─────────────────────────────────────────┘
```

Every agent signals back to Team Lead. Team Lead gates each transition and briefs the stakeholder.

**PM is optional.** On smaller projects Team Lead handles phase context directly. Spawn PM when product requirements need dedicated ownership across multiple parallel workstreams.

---

## Agents

```
# AGENTS — parsed by scripts/spawn-agent.sh (Team Lead spawns these; comment out unused roles)
# PM Agent is optional — omit on smaller projects; Team Lead handles phase context directly
PM Agent         | I am the PM Agent. Read CLAUDE.md then personas/pm.md. Monitor STATE.md for requirements questions from Team Lead. Maintain REQUIREMENTS.md and ROADMAP.md. When Team Lead requests phase context, run /gsd:discuss-phase <N>, commit+push, signal Team Lead.
Architect Agent  | I am the Architect Agent. Read CLAUDE.md then personas/architect.md. Wait for CONTEXT.md from Team Lead, run /gsd:plan-phase <N>, commit+push, signal Team Lead.
Engineer Web     | I am the Web Engineer. Read CLAUDE.md then personas/engineer-web.md. Wait for signal from Team Lead with my assigned tasks. Run /gsd:execute-phase <N>, coverage ≥95%, commit+push, signal Team Lead.
Engineer iOS     | I am the iOS Engineer. Read CLAUDE.md then personas/engineer-ios.md. Wait for signal from Team Lead with my assigned tasks. Run /gsd:execute-phase <N>, coverage ≥95%, commit+push, signal Team Lead.
Engineer Android | I am the Android Engineer. Read CLAUDE.md then personas/engineer-android.md. Wait for signal from Team Lead with my assigned tasks. Run /gsd:execute-phase <N>, coverage ≥95%, commit+push, signal Team Lead.
QA Agent         | I am the QA Agent. Read CLAUDE.md then personas/qa.md. Wait for signal from Team Lead that all engineers are done. Coverage ≥95% first, /gsd:verify-work <N>, write integration+e2e tests, commit+push, signal Team Lead.
SRE Agent        | I am the SRE Agent. Read CLAUDE.md then personas/sre.md. Wait for signal from Team Lead. Deploy pipeline, validate health checks, log in STATE.md, signal Team Lead.
```

Start: `./start-session.sh` — opens Team Lead pane. Team Lead spawns agents as needed via `./scripts/spawn-agent.sh`.

---

## Files

| File | Owner |
|---|---|
| `.planning/STATE.md` | All agents — decisions, blockers, open questions |
| `.planning/ROADMAP.md` | PM (owns), Team Lead (reads) |
| `.planning/REQUIREMENTS.md` | PM (owns), Architect, Engineers (read) |
| `{{SPEC_FILE}}` | Architect, Engineers, QA |
| `personas/<role>.md` | That agent only |

Conflicts: `{{SPEC_FILE}}` wins on tech; `STATE.md` wins on current blockers.

---

## GSD

Required. Check with `/gsd:help`. Install: `npx get-shit-done-cc@latest --claude --local`

No phase starts without PLAN.md. No phase closes without `/gsd:verify-work` passing.

---

## Commits

`<type>(<phase>-<task>): <description>` — one commit per task.
Types: `feat` `fix` `test` `refactor` `docs` `chore`

Session start: `git pull` — Session end: `git add -A && git commit && git push`
Mid-task stop: `/gsd:pause-work`

---

## Definition of Done

**Per phase:**
- [ ] Tests pass, coverage ≥95% on all touched modules
- [ ] No dead code, no duplication, no hardcoded credentials
- [ ] All acceptance criteria verified by QA
- [ ] Integration + e2e tests written and passing
- [ ] Deployed, health checks passing, deployment logged
- [ ] Team Lead has briefed stakeholder

**Per milestone:**
- [ ] All phases done, coverage ≥95% full codebase, e2e green on prod
- [ ] `/gsd:audit-milestone` passes, `/gsd:complete-milestone` run

---

## Environment

```bash
# Required env vars — never hardcode
# {{ENV_VAR_1}}=...

# Setup
# {{SETUP_CMD}}
```
