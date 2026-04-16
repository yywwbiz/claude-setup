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

# ── Resolve active window and first pane (by unique pane ID, not positional index) ───

WIN="$(tmux display-message -t "${SESSION}" -p '#I')"
# Get unique pane IDs (%N) for this window — order = creation order
PANE_IDS=( $(tmux list-panes -t "${SESSION}:${WIN}" -F '#{pane_id}') )
PANE_COUNT="${#PANE_IDS[@]}"
FIRST_PANE_ID="${PANE_IDS[1]}"   # zsh arrays are 1-based
LAST_PANE_ID="${PANE_IDS[$PANE_COUNT]}"

# ── Open new pane on the right, stack vertically ──────────────────────────────

if [[ "$PANE_COUNT" -eq 1 ]]; then
  # Only Team Lead exists — split horizontally to create the right column
  NEW_PANE_ID="$(tmux split-window -t "${FIRST_PANE_ID}" -h -c "$PROJ" -P -F '#{pane_id}')"
else
  # Right column already exists — split the last right-column pane vertically
  NEW_PANE_ID="$(tmux split-window -t "${LAST_PANE_ID}" -v -c "$PROJ" -P -F '#{pane_id}')"
fi

# Rebalance: Team Lead fills left column, agents stack on the right
tmux select-pane   -t "${FIRST_PANE_ID}"
tmux select-layout -t "${SESSION}:${WIN}" main-vertical

# ── Pane border labels ────────────────────────────────────────────────────────
# Claude Code overwrites pane_title via OSC escape codes, so we use a custom
# @agent user variable that only tmux can set, and display it in the border.
# Enable border status + format once (idempotent — safe to call on every spawn).

tmux set -t "${SESSION}:${WIN}" pane-border-status top
tmux set -t "${SESSION}:${WIN}" pane-border-format " #{@agent} "
tmux set -t "${SESSION}:${WIN}" allow-rename off

# Stamp the new pane with its agent label (survives Claude's title rewrites)
tmux set-option -pt "${NEW_PANE_ID}" @agent "(${AGENT_LABEL})"

# Also set -T for any tools that read pane_title directly
tmux select-pane -t "${NEW_PANE_ID}" -T "(${AGENT_LABEL})"

# ── Launch claude ─────────────────────────────────────────────────────────────

tmux send-keys -t "${NEW_PANE_ID}" "$AGENT_CMD"
tmux send-keys -t "${NEW_PANE_ID}" "" Enter

echo "Waiting ${WAIT}s for claude to load..."
sleep "$WAIT"

# ── Start inbox watcher ───────────────────────────────────────────────────────

# Resolve positional pane index for inbox-watcher (it uses session:win.pane syntax)
NEW_PANE_IDX="$(tmux display-message -t "${NEW_PANE_ID}" -p '#{pane_index}')"

WATCHER_SCRIPT="$(dirname "$0")/inbox-watcher.js"
if [[ -f "$WATCHER_SCRIPT" ]]; then
  node "$WATCHER_SCRIPT" "$SESSION" "$NEW_PANE_IDX" "$AGENT_LABEL" 2000 \
    >> /tmp/inbox-watcher-${SESSION}.log 2>&1 &
  echo "  inbox watcher: [${AGENT_LABEL}] → pane ${NEW_PANE_IDX}"
else
  echo "  Warning: inbox-watcher.js not found — agent-to-agent messaging will not auto-deliver"
fi

# ── Send role prompt ──────────────────────────────────────────────────────────

if [[ -n "$AGENT_PROMPT" ]]; then
  tmux send-keys -t "${NEW_PANE_ID}" "$AGENT_PROMPT"
  tmux send-keys -t "${NEW_PANE_ID}" "" Enter
fi

# Return focus to Team Lead
tmux select-pane -t "${FIRST_PANE_ID}"

echo "[${AGENT_LABEL}] spawned in pane ${NEW_PANE_IDX} (${NEW_PANE_ID})."
