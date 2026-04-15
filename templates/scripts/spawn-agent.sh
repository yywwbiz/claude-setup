#!/usr/bin/env zsh
# spawn-agent.sh — called by Team Lead (via Bash tool) to open a new agent pane
#
# Opens a new pane in the live tmux session, sets its title, launches claude,
# sends the role prompt from CLAUDE.md, and starts the inbox watcher.
#
# Usage:
#   ./scripts/spawn-agent.sh <session> <agent-label> [--wait SECONDS] [--project PATH]
#
# Arguments:
#   session       tmux session name (the existing session Team Lead lives in)
#   agent-label   label to match against AGENTS block in CLAUDE.md (case-insensitive, partial ok)
#
# Options:
#   -w, --wait SECONDS    seconds to wait for claude to load (default: 5)
#   -p, --project PATH    project directory where CLAUDE.md lives (default: pwd)
#   -h, --help            show this help
#
# Examples:
#   ./scripts/spawn-agent.sh myproject architect
#   ./scripts/spawn-agent.sh myproject "eng web" --wait 8

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

WAIT=5
PROJ="$(pwd)"
AGENT_CMD="claude --dangerously-skip-permissions"

# ── Argument parsing ──────────────────────────────────────────────────────────

SESSION=""
REQUESTED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wait)    WAIT="$2"; shift 2 ;;
    -p|--project) PROJ="$2"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -30 | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)
      if [[ -z "$SESSION" ]]; then
        SESSION="$1"
      elif [[ -z "$REQUESTED" ]]; then
        REQUESTED="$1"
      else
        echo "Unexpected argument: $1"; exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$SESSION" || -z "$REQUESTED" ]]; then
  echo "Usage: ./scripts/spawn-agent.sh <session> <agent-label> [--wait SECONDS]"
  exit 1
fi

# ── Verify session exists ─────────────────────────────────────────────────────

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Error: tmux session '${SESSION}' does not exist."
  echo "Start the session first with: ./start-session.sh"
  exit 1
fi

# ── Parse AGENTS roster from CLAUDE.md ───────────────────────────────────────

CLAUDE_MD="${PROJ}/CLAUDE.md"
[[ ! -f "$CLAUDE_MD" ]] && { echo "Error: CLAUDE.md not found at ${CLAUDE_MD}"; exit 1; }

ROSTER=()
while IFS= read -r line; do
  ROSTER+=("$line")
done < <(
  awk '/^# AGENTS/,/^```/' "$CLAUDE_MD" \
  | grep -v '^#' \
  | grep -v '^```' \
  | grep '|' \
  | sed 's/^[[:space:]]*//' \
  | grep -v '^$'
)

[[ ${#ROSTER[@]} -eq 0 ]] && { echo "Error: no agents found in CLAUDE.md AGENTS block."; exit 1; }

# ── Match requested label against roster ──────────────────────────────────────

MATCHED_ENTRY=""

for entry in "${ROSTER[@]}"; do
  roster_label="$(echo "${entry%%|*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  if echo "$roster_label" | grep -qi "$REQUESTED"; then
    MATCHED_ENTRY="$entry"
    break
  fi
done

if [[ -z "$MATCHED_ENTRY" ]]; then
  echo "Error: no agent matching '${REQUESTED}' found in CLAUDE.md roster."
  echo "Available agents:"
  for entry in "${ROSTER[@]}"; do
    echo "  • $(echo "${entry%%|*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  done
  exit 1
fi

AGENT_LABEL="$(echo "${MATCHED_ENTRY%%|*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
AGENT_PROMPT="$(echo "${MATCHED_ENTRY#*|}" | sed 's/^[[:space:]]*//')"

echo "Spawning [${AGENT_LABEL}] in session '${SESSION}'..."

# ── Open new pane on the right, stack vertically ──────────────────────────────

# Count existing panes to determine where to split
PANE_COUNT="$(tmux list-panes -t "${SESSION}:0" | wc -l | tr -d ' ')"

if [[ "$PANE_COUNT" -eq 1 ]]; then
  # Only Team Lead exists — split horizontally to create the right column
  tmux split-window -t "${SESSION}:0.0" -h -c "$PROJ"
  NEW_PANE=1
else
  # Right column already exists — split the last right-column pane vertically
  LAST_PANE=$(( PANE_COUNT - 1 ))
  tmux split-window -t "${SESSION}:0.${LAST_PANE}" -v -c "$PROJ"
  NEW_PANE="$PANE_COUNT"
fi

# Rebalance: Team Lead fills left column, agents stack on the right
tmux select-pane   -t "${SESSION}:0.0"
tmux select-layout -t "${SESSION}:0" main-vertical

# ── Set pane title ────────────────────────────────────────────────────────────

tmux select-pane -t "${SESSION}:0.${NEW_PANE}" -T "[${AGENT_LABEL}]"

# ── Launch claude ─────────────────────────────────────────────────────────────

tmux send-keys -t "${SESSION}:0.${NEW_PANE}" "$AGENT_CMD" Enter

echo "Waiting ${WAIT}s for claude to load..."
sleep "$WAIT"

# ── Start inbox watcher ───────────────────────────────────────────────────────

WATCHER_SCRIPT="$(dirname "$0")/inbox-watcher.js"
if [[ -f "$WATCHER_SCRIPT" ]]; then
  node "$WATCHER_SCRIPT" "$SESSION" "$NEW_PANE" "$AGENT_LABEL" 2000 \
    >> /tmp/inbox-watcher-${SESSION}.log 2>&1 &
  echo "  inbox watcher: [${AGENT_LABEL}] → pane ${NEW_PANE}"
else
  echo "  ⚠️  inbox-watcher.js not found — agent-to-agent messaging will not auto-deliver"
fi

# ── Send role prompt ──────────────────────────────────────────────────────────

if [[ -n "$AGENT_PROMPT" ]]; then
  tmux send-keys -t "${SESSION}:0.${NEW_PANE}" "$AGENT_PROMPT" Enter
fi

# Return focus to Team Lead
tmux select-pane -t "${SESSION}:0.0"

echo "[${AGENT_LABEL}] spawned in pane ${NEW_PANE}."
