#!/usr/bin/env zsh
# start-session.sh — opens a tmux session with Team Lead in pane 0
#
# Layout after start:
#   ┌───────────────────────────────┐
#   │         [Team Lead]           │
#   │   (you talk here)             │
#   │   (agents spawned by TL)      │
#   └───────────────────────────────┘
#
# Team Lead decides which agents are needed and spawns them via spawn-agent.sh.
# Usage:
#   start-session.sh [OPTIONS]
#
# Options:
#   -s, --session NAME    tmux session name (default: basename of project dir)
#   -p, --project PATH    project directory (default: pwd)
#   -h, --help            show this help

set -euo pipefail

PROJ="$(pwd)"
SESSION="$(basename "$PROJ")"
AGENT_CMD="claude --dangerously-skip-permissions"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--session) SESSION="$2"; shift 2 ;;
    -p|--project) PROJ="$2"; SESSION="$(basename "$2")"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -30 | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)  echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '${SESSION}' already exists — attaching."
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Create session — pane 0 is the Team Lead (full window initially)
tmux new-session -d -s "$SESSION" -x 220 -y 60 -c "$PROJ"

tmux set-option -t "$SESSION" mouse on
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #{pane_title} "

tmux select-pane -t "${SESSION}:0.0" -T "[Team Lead]"

tmux source-file ~/.tmux.conf 2>/dev/null || true

tmux send-keys -t "${SESSION}:0.0" "$AGENT_CMD" Enter

echo ""
echo "Session '${SESSION}' ready. You are now in the Team Lead pane."
echo "Team Lead will spawn agents as needed via the y-team plugin scripts."
echo "Mouse: enabled (scroll, click, drag to resize)"
echo "Detach: Ctrl+B D"
echo ""
tmux attach-session -t "$SESSION"
