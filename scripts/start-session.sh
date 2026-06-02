#!/usr/bin/env zsh
# start-session.sh — start Team Lead in a tmux window
#
# If already inside tmux: opens a new "Team Lead" window in the current session.
# If not in tmux: creates a new named session and attaches to it.
#
# Usage:
#   start-session.sh [OPTIONS]
#
# Options:
#   -s, --session NAME    session name when creating a new one (default: basename of project dir)
#   -p, --project PATH    project directory (default: pwd)
#   -h, --help            show this help

set -euo pipefail

PROJ="$(pwd)"
SESSION_NAME="$(basename "$PROJ")"
AGENT_CMD="claude --dangerously-skip-permissions"

if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--session) SESSION_NAME="$2"; shift 2 ;;
    -p|--project) PROJ="$2"; SESSION_NAME="$(basename "$2")"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -30 | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)  echo "Unknown argument: $1"; exit 1 ;;
  esac
done

WATCHER_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/inbox-watcher.js"
TL_PERSONA_FILE="${CLAUDE_PLUGIN_ROOT}/agents/team-lead.md"

# ── Extract Team Lead boot prompt from persona file ───────────────────────────

TL_PROMPT=""
if [[ -f "$TL_PERSONA_FILE" ]]; then
  TL_PROMPT="$(awk '
    /^## AGENTS block entry/ { inblock=1; next }
    inblock && /^```/ { if (started) { exit } else { started=1; next } }
    inblock && started && NF { print; exit }
  ' "$TL_PERSONA_FILE")"
  # Strip the "Team Lead | " label prefix, leaving just the prompt text
  TL_PROMPT="${TL_PROMPT#*| }"
  # Substitute project name
  TL_PROMPT="${TL_PROMPT//\{\{PROJECT_NAME\}\}/$(basename "$PROJ")}"
fi

# ── Helper: start Team Lead in a given pane ───────────────────────────────────

start_team_lead() {
  local session="$1" pane_id="$2"

  tmux set-option -t "$session" pane-border-status top
  tmux set-option -t "$session" pane-border-format " #{@agent} "
  tmux set-option -t "$session" allow-rename off
  tmux set-option -pt "$pane_id" @agent "[Team Lead]"

  tmux send-keys -t "$pane_id" "$AGENT_CMD" Enter

  local wait_secs=5
  echo "Waiting ${wait_secs}s for claude to load..."
  sleep "$wait_secs"

  if [[ -f "$WATCHER_SCRIPT" ]]; then
    node "$WATCHER_SCRIPT" "$session" "$pane_id" "team-lead" 2000 \
      >> /tmp/inbox-watcher-${session}-team-lead.log 2>&1 &
    echo "  inbox watcher: [Team Lead] → ${pane_id}"
  fi

  if [[ -n "$TL_PROMPT" ]]; then
    tmux send-keys -t "$pane_id" "$TL_PROMPT" Enter
  fi
}

# ── Already inside tmux: open a new window in the current session ─────────────

if [[ -n "${TMUX:-}" ]]; then
  SESSION="$(tmux display-message -p '#S')"

  # If a Team Lead window already exists, just switch to it
  if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx 'Team Lead'; then
    echo "Team Lead window already exists in '${SESSION}' — switching."
    tmux select-window -t "${SESSION}:Team Lead"
    exit 0
  fi

  WIN="$(tmux new-window -t "${SESSION}:" -n "Team Lead" -c "$PROJ" -P -F '#{window_index}')"
  PANE_ID="$(tmux display-message -t "${SESSION}:${WIN}" -p '#{pane_id}')"

  start_team_lead "$SESSION" "$PANE_ID"
  tmux select-window -t "${SESSION}:${WIN}"

  echo ""
  echo "Team Lead window ready in session '${SESSION}'."
  echo "Detach: Ctrl+B D"
  exit 0
fi

# ── Not in tmux: create a new named session and attach ────────────────────────

SESSION="$SESSION_NAME"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '${SESSION}' already exists — attaching."
  tmux attach-session -t "$SESSION"
  exit 0
fi

tmux new-session -d -s "$SESSION" -c "$PROJ"
tmux set-option -t "$SESSION" mouse on

# Use the actual first window index (respects user's base-index setting)
WIN="$(tmux display-message -t "${SESSION}" -p '#{window_index}')"
PANE_ID="$(tmux display-message -t "${SESSION}:${WIN}" -p '#{pane_id}')"

# Rename the window
tmux rename-window -t "${SESSION}:${WIN}" "Team Lead"

tmux source-file ~/.tmux.conf 2>/dev/null || true

start_team_lead "$SESSION" "$PANE_ID"

echo ""
echo "Session '${SESSION}' ready."
echo "Mouse: enabled (scroll, click, drag to resize)"
echo "Detach: Ctrl+B D"
echo ""
tmux attach-session -t "$SESSION"
