#!/usr/bin/env zsh
# start-session.sh — boot Team Lead in pane 0 of a dedicated project tmux session
#
# Always creates a named project session with Team Lead in pane 0, regardless of
# whether the script is run from inside or outside an existing tmux session.
# When already inside tmux, switches the client to the project session instead of
# appending a window to the current session.
#
# Usage:
#   start-session.sh [OPTIONS]
#
# Options:
#   -s, --session NAME    session name (default: basename of project dir)
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
  TL_PROMPT="${TL_PROMPT#*| }"
  TL_PROMPT="${TL_PROMPT//\{\{PROJECT_NAME\}\}/$(basename "$PROJ")}"
fi

# ── Helper: boot Team Lead in a given pane ───────────────────────────────────

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
    node "$WATCHER_SCRIPT" "$session" "$pane_id" "team-lead" "$PROJ" 2000 \
      >> /tmp/inbox-watcher-${session}-team-lead.log 2>&1 &
    echo "  inbox watcher: [Team Lead] → ${pane_id}"
  fi

  if [[ -n "$TL_PROMPT" ]]; then
    tmux send-keys -t "$pane_id" "$TL_PROMPT" Enter
  fi
}

# ── If the project session already exists, just switch/attach to it ───────────

SESSION="$SESSION_NAME"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '${SESSION}' already exists."
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
  exit 0
fi

# ── Create the project session (detached) and boot Team Lead in pane 0 ────────

tmux new-session -d -s "$SESSION" -c "$PROJ"
tmux set-option -t "$SESSION" mouse on

WIN="$(tmux display-message -t "${SESSION}" -p '#{window_index}')"
PANE_ID="$(tmux display-message -t "${SESSION}:${WIN}" -p '#{pane_id}')"

tmux rename-window -t "${SESSION}:${WIN}" "Team Lead"
tmux source-file ~/.tmux.conf 2>/dev/null || true

start_team_lead "$SESSION" "$PANE_ID"

echo ""
echo "Session '${SESSION}' ready. Team Lead is in pane 0."
echo "Mouse: enabled (scroll, click, drag to resize)"
echo ""

if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
