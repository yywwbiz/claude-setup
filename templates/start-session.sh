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
# Team Lead decides which agents are needed and spawns them via scripts/spawn-agent.sh.
# You do not need to pass any agent labels. Just run this to open the project.
#
# Usage:
#   ./start-session.sh [OPTIONS]
#
# Options:
#   -s, --session NAME    tmux session name (default: basename of project dir)
#   -p, --project PATH    project directory (default: pwd)
#   -h, --help            show this help

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

PROJ="$(pwd)"
SESSION="$(basename "$PROJ")"
AGENT_CMD="claude --dangerously-skip-permissions"

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--session) SESSION="$2"; shift 2 ;;
    -p|--project) PROJ="$2"; SESSION="$(basename "$2")"; shift 2 ;;
    -h|--help)    grep '^#' "$0" | head -30 | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *)  echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Session setup ─────────────────────────────────────────────────────────────

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Session '${SESSION}' already exists — attaching."
  tmux attach-session -t "$SESSION"
  exit 0
fi

# Create session — pane 0 is the Team Lead (full window initially)
tmux new-session -d -s "$SESSION" -x 220 -y 60 -c "$PROJ"

# Enable mouse support (scroll, click, drag to resize panes)
tmux set-option -t "$SESSION" mouse on

# Show pane titles in the border above each pane
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #{pane_title} "

# Name the Team Lead pane
tmux select-pane -t "${SESSION}:0.0" -T "[Team Lead]"

# Source user tmux config (picks up theme, status bar, etc.) — non-fatal if absent
tmux source-file ~/.tmux.conf 2>/dev/null || true

# ── Launch claude in Team Lead pane ──────────────────────────────────────────

tmux send-keys -t "${SESSION}:0.0" "$AGENT_CMD" Enter

# ── Attach ────────────────────────────────────────────────────────────────────

echo ""
echo "Session '${SESSION}' ready. You are now in the Team Lead pane."
echo "Team Lead will spawn agents as needed via scripts/spawn-agent.sh"
echo "Mouse: enabled (scroll, click, drag to resize)"
echo "Detach: Ctrl+B D"
echo ""
tmux attach-session -t "$SESSION"
