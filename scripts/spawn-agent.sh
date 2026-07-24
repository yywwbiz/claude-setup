#!/usr/bin/env zsh
# spawn-agent.sh — called by Team Lead (via Bash tool) to open a new agent pane
#
# Opens a new pane in the live tmux session, sets its title, launches claude,
# sends the role prompt loaded from the plugin's agents/ directory, and starts
# the inbox watcher.
#
# Usage:
#   spawn-agent.sh <session> <persona-name> [--wait SECONDS] [--project PATH]
#
# Arguments:
#   session         tmux session name
#   persona-name    name of an agent file in ${CLAUDE_PLUGIN_ROOT}/agents/
#                   (e.g. product-architect, engineer-web, engineer-ios,
#                    engineer-android, engineer-backend, qa, sre, designer)
#
# Options:
#   -w, --wait SECONDS    seconds to wait for claude to load (default: 5)
#   -p, --project PATH    project directory (default: pwd)
#   -h, --help            show this help

set -euo pipefail

WAIT=5
PROJ="$(pwd)"
AGENT_CMD="claude --dangerously-skip-permissions"

# Plugin root — required so we can find agents/ regardless of where the script runs from
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  # Fallback: assume the script lives at <plugin-root>/scripts/spawn-agent.sh
  CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi
AGENTS_DIR="${CLAUDE_PLUGIN_ROOT}/agents"

SESSION=""
PERSONA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wait)    WAIT="$2"; shift 2 ;;
    -p|--project) PROJ="$2"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -40 | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)
      if [[ -z "$SESSION" ]]; then
        SESSION="$1"
      elif [[ -z "$PERSONA" ]]; then
        PERSONA="$1"
      else
        echo "Unexpected argument: $1"; exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$SESSION" || -z "$PERSONA" ]]; then
  echo "Usage: spawn-agent.sh <session> <persona-name> [--wait SECONDS]"
  exit 1
fi

# ── Verify session exists ─────────────────────────────────────────────────────

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Error: tmux session '${SESSION}' does not exist."
  echo "Start the session first with: /y-team:start"
  exit 1
fi

# ── Block spawning team-lead (it's the orchestrator, not a spawnable agent) ──

if [[ "$PERSONA" == "team-lead" ]]; then
  echo "Error: team-lead is the main pane and cannot be spawned as an agent."
  echo "It boots automatically when you run /y-team:start."
  exit 1
fi

# ── Resolve persona file ──────────────────────────────────────────────────────

PERSONA_FILE="${AGENTS_DIR}/${PERSONA}.md"

if [[ ! -f "$PERSONA_FILE" ]]; then
  echo "Error: persona '${PERSONA}' not found at ${PERSONA_FILE}"
  echo "Available personas:"
  for f in "${AGENTS_DIR}"/*.md; do
    [[ -f "$f" ]] && echo "  • $(basename "$f" .md)"
  done
  exit 1
fi

# ── Verify persona is in the active roster (.claude/team.json) ───────────────

ROSTER_FILE="${PROJ}/.claude/team.json"
if [[ -f "$ROSTER_FILE" ]]; then
  if ! grep -q "\"${PERSONA}\"" "$ROSTER_FILE"; then
    echo "Error: persona '${PERSONA}' is not in this project's active roster."
    echo "Active roster: ${ROSTER_FILE}"
    echo "Add it via: /y-team:add ${PERSONA}"
    exit 1
  fi
fi

# ── Extract the persona's AGENTS block prompt ────────────────────────────────
# Each persona file contains a fenced code block under an "## AGENTS block entry"
# heading. The first non-empty line of that block is "PersonaLabel | I am the ...".

PROMPT_LINE="$(awk '
  /^## AGENTS block entry/ { inblock=1; next }
  inblock && /^```/ { if (started) { exit } else { started=1; next } }
  inblock && started && NF { print; exit }
' "$PERSONA_FILE")"

if [[ -z "$PROMPT_LINE" ]]; then
  echo "Error: persona '${PERSONA}' has no AGENTS block entry."
  exit 1
fi

AGENT_LABEL="$(echo "${PROMPT_LINE%%|*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
AGENT_PROMPT="$(echo "${PROMPT_LINE#*|}" | sed 's/^[[:space:]]*//')"
AGENT_PROMPT="${AGENT_PROMPT//\{\{PROJECT_NAME\}\}/$SESSION}"
AGENT_PROMPT="${AGENT_PROMPT//\{\{PLUGIN_ROOT\}\}/$CLAUDE_PLUGIN_ROOT}"
AGENT_PROMPT="${AGENT_PROMPT//\{\{PROJECT_DIR\}\}/$PROJ}"

echo "Spawning [${AGENT_LABEL}] (persona: ${PERSONA}) in session '${SESSION}'..."

# ── Resolve active window and pane layout ─────────────────────────────────────

WIN="$(tmux display-message -t "${SESSION}" -p '#I')"
PANE_IDS=( $(tmux list-panes -t "${SESSION}:${WIN}" -F '#{pane_id}') )
PANE_COUNT="${#PANE_IDS[@]}"
FIRST_PANE_ID="${PANE_IDS[1]}"   # zsh arrays are 1-based
LAST_PANE_ID="${PANE_IDS[$PANE_COUNT]}"

# ── Open new pane on the right, stack vertically ──────────────────────────────

if [[ "$PANE_COUNT" -eq 1 ]]; then
  NEW_PANE_ID="$(tmux split-window -t "${FIRST_PANE_ID}" -h -c "$PROJ" -P -F '#{pane_id}')"
else
  NEW_PANE_ID="$(tmux split-window -t "${LAST_PANE_ID}" -v -c "$PROJ" -P -F '#{pane_id}')"
fi

tmux select-pane   -t "${FIRST_PANE_ID}"
tmux select-layout -t "${SESSION}:${WIN}" main-vertical

# ── Pane border labels ────────────────────────────────────────────────────────

tmux set -t "${SESSION}:${WIN}" pane-border-status top
tmux set -t "${SESSION}:${WIN}" pane-border-format " #{@agent} "
tmux set -t "${SESSION}:${WIN}" allow-rename off

tmux set-option -pt "${NEW_PANE_ID}" @agent "(${AGENT_LABEL})"
tmux select-pane -t "${NEW_PANE_ID}" -T "(${AGENT_LABEL})"

# ── Launch claude ─────────────────────────────────────────────────────────────

tmux send-keys -t "${NEW_PANE_ID}" "$AGENT_CMD"
tmux send-keys -t "${NEW_PANE_ID}" "" Enter

echo "Waiting ${WAIT}s for claude to load..."
sleep "$WAIT"

# ── Start inbox watcher ───────────────────────────────────────────────────────

NEW_PANE_IDX="$(tmux display-message -t "${NEW_PANE_ID}" -p '#{pane_index}')"

WATCHER_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/inbox-watcher.js"
if [[ -f "$WATCHER_SCRIPT" ]]; then
  node "$WATCHER_SCRIPT" "$SESSION" "$NEW_PANE_ID" "$AGENT_LABEL" "$PROJ" 2000 \
    >> /tmp/inbox-watcher-${SESSION}.log 2>&1 &
  echo "  inbox watcher: [${AGENT_LABEL}] → ${NEW_PANE_ID} (pane ${NEW_PANE_IDX})"
else
  echo "  Warning: inbox-watcher.js not found at ${WATCHER_SCRIPT}"
fi

# ── Send role prompt ──────────────────────────────────────────────────────────

if [[ -n "$AGENT_PROMPT" ]]; then
  tmux send-keys -t "${NEW_PANE_ID}" "$AGENT_PROMPT"
  tmux send-keys -t "${NEW_PANE_ID}" "" Enter
fi

tmux select-pane -t "${FIRST_PANE_ID}"

echo "[${AGENT_LABEL}] spawned in pane ${NEW_PANE_IDX} (${NEW_PANE_ID})."
