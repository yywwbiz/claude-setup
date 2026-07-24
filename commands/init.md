---
description: Kick off a new project — gather brief, propose roster, scaffold CLAUDE.md and team.json
---

Run the y-team project kickoff. This is the conversational onboarding that happens **before** tmux starts, so the roster and project brief are in place when Team Lead boots.

## Flow

### 1. Confirm we're in a fresh project

Check whether `.claude/team.json` already exists in the current working directory.

- If it exists, ask: "This project already has a y-team roster. Re-run init from scratch (overwrites team.json and CLAUDE.md), or cancel?"
- If they say cancel, stop. Suggest `/y-team:add` or `/y-team:list` instead.
- If they say re-run, proceed but warn that the existing files will be overwritten.

### 2. Gather the project brief

Ask the user, in an open-ended way:

> "What are we building? Give me the project name and a one-paragraph brief — what it does, who it's for, and any constraints you already know (deadline, platforms, stack)."

Wait for their answer. If their answer is thin, ask up to **3 short clarifying questions** — but not more. Examples of when to ask:

- Platforms unclear → "Web, mobile, or both?"
- Backend implied but not stated → "Do you need a backend service, or is this client-only?"
- Deploy target unclear when SRE might be relevant → "Where will this run — your own server, a PaaS, just local for now?"
- Team-size context absent → "Is this a solo pet project, or will others contribute?"

Do not interrogate. If the brief is good enough after one round, move on.

### 3. Propose a roster

Based on the brief, recommend 3–5 personas from the library at `${CLAUDE_PLUGIN_ROOT}/agents/`. Use this judgment:

- **product-architect** — recommend for almost any non-trivial project. Skip only for tiny scripts where there's nothing to design.
- **engineer-web / -ios / -android / -backend** — match to the platforms in the brief. Don't add all four; only what's needed.
- **designer** — recommend when the brief mentions UI/UX, polish, accessibility, or visual design. Skip for pure backend/CLI work.
- **qa** — recommend for anything user-facing or revenue-touching. Skip for throwaway prototypes.
- **sre** — recommend when there's a deploy target. Skip for local-only experiments.

`team-lead` is structural — never propose it (it boots automatically).

Present the proposal as a short list with one line of reasoning each. Example:

> Suggested roster:
> - **product-architect** — you've got real product requirements (streaks, weekly digest) that need acceptance criteria
> - **engineer-web** — web app
> - **engineer-backend** — auth + streak logic + email job
> - **qa** — user-facing, will need integration tests for the auth flow
> - **sre** — you mentioned deploying to Fly.io

Ask: "Look right? Add/remove anyone, or shall we go with this?"

### 4. Iterate on the roster

Take their feedback. They might say "add designer," "drop sre, I'll deploy by hand," etc. Adjust the list. Confirm the final roster before writing files.

### 5. Scaffold the files (light mode)

Create only these files:

**`.gitignore`** — append (or create) an entry to keep the agent inbox out of version control:
```
# y-team agent inbox — runtime only, not for source control
.claude/y-team-inbox/
```
If `.gitignore` already exists, append only the lines that aren't already present.

**`.claude/team.json`** — the active roster:
```json
{
  "active": ["team-lead", "product-architect", "engineer-web", "..."]
}
```
Always include `"team-lead"` first. Use the personas from step 4.

**`CLAUDE.md`** — project brief that every spawned agent reads:
```markdown
# <project name>

<the one-paragraph brief from step 2, refined with any clarifications>

## Active Team

This project uses the y-team plugin. Active personas:
- <list each from team.json with a one-line role description>

The active roster lives in `.claude/team.json`. Team Lead reads it before spawning.

## Project Files

- `.planning/ROADMAP.md` — phase order and status (created when first phase is planned)
- `.planning/STATE.md` — live blockers, decisions, open questions
- `.planning/PHASE-<N>/` — per-phase REQUIREMENTS.md, PLAN.md, VERIFICATION.md

## Standing Rules

- Coverage ≥95% on every commit
- One commit per task, conventional commit messages
- No phase starts without PLAN.md; no phase closes without QA verified + SRE deployed
```

Do NOT create `.planning/` files. Team Lead and product-architect will create those when the first phase begins (light scaffolding mode).

### 6. Offer to boot the session

Ask: "Ready to boot Team Lead now? [Y/n]"

- If yes (or empty): run `/y-team:start` by invoking the script:
  ```bash
  ${CLAUDE_PLUGIN_ROOT}/scripts/start-session.sh
  ```
  Then tell the user to attach to the tmux session and that Team Lead has the brief from `CLAUDE.md`.

- If no: tell them to run `/y-team:start` when ready, and that the project is set up.

## Notes

- Always confirm the roster with the user before writing files. Don't make silent decisions.
- The brief in `CLAUDE.md` matters — it's the context every spawned agent inherits. Get it right before scaffolding.
- If the user gives a vague brief and resists clarifying, write what you have. They can edit `CLAUDE.md` later.
