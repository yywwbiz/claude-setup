#!/usr/bin/env node
// inbox-watcher.js — polls a Claude Code agent inbox and feeds unread messages into a tmux pane
//
// Usage: node inbox-watcher.js <session> <pane> <agent_name> <project_dir> [poll_interval_ms]
//
// Inbox filename is always the normalized agent name (lowercase, spaces→hyphens).
// The inbox file is created immediately on startup so send-inbox.js always has somewhere to write.
// Inbox lives at <project_dir>/.claude/y-team/inbox/ — project-local, never global.

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const [, , SESSION, PANE_TARGET, AGENT_NAME, PROJECT_DIR, INTERVAL_MS = "2000"] = process.argv;

if (!SESSION || !PANE_TARGET || !AGENT_NAME || !PROJECT_DIR) {
  console.error("Usage: node inbox-watcher.js <session> <pane-id> <agent_name> <project_dir> [poll_ms]");
  process.exit(1);
}

// Canonical inbox name — must match the normalization in send-inbox.js
function normalizeAgentName(name) {
  return name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
}

const INBOX_DIR = path.join(PROJECT_DIR, ".claude", "y-team", "inbox");
const INBOX_FILE = path.join(INBOX_DIR, `${normalizeAgentName(AGENT_NAME)}.json`);
const INTERVAL = parseInt(INTERVAL_MS, 10);

// Create inbox immediately so send-inbox.js always has a file to append to
fs.mkdirSync(INBOX_DIR, { recursive: true });
if (!fs.existsSync(INBOX_FILE)) {
  fs.writeFileSync(INBOX_FILE, "[]");
}

console.log(`[inbox-watcher] Watching ${INBOX_FILE} → pane ${PANE_TARGET}`);

// ── Send text into tmux pane ──────────────────────────────────────────────────
// Uses load-buffer + paste-buffer (atomic) instead of send-keys to avoid
// Claude Code mis-detecting long lines as pastes and corrupting them into
// [Pasted text #N] placeholders with a garbled tail fragment.
// Named buffers prevent collisions when multiple watchers deliver simultaneously.

function sendToPane(text) {
  const lines = text.split("\n");
  for (const line of lines) {
    const bufName = `y-team-${process.pid}-${Date.now()}`;
    spawnSync("tmux", ["load-buffer", "-b", bufName, "-"], {
      input: line,
      stdio: ["pipe", "inherit", "inherit"],
    });
    spawnSync("tmux", ["paste-buffer", "-b", bufName, "-t", PANE_TARGET]);
    spawnSync("tmux", ["delete-buffer", "-b", bufName]);
  }
  // Enter is a key, not text — send-keys is correct here
  spawnSync("tmux", ["send-keys", "-t", PANE_TARGET, "", "Enter"], { stdio: "inherit" });
}

// ── Poll loop ─────────────────────────────────────────────────────────────────

const poll = setInterval(() => {
  let messages;
  try {
    messages = JSON.parse(fs.readFileSync(INBOX_FILE, "utf8"));
  } catch {
    return; // malformed — skip this tick
  }

  const unread = messages.filter((m) => !m.read);
  if (unread.length === 0) return;

  console.log(`[inbox-watcher] ${unread.length} unread message(s) for "${AGENT_NAME}"`);

  for (const msg of unread) {
    console.log(`[inbox-watcher] Delivering from "${msg.from}": ${msg.summary || "(no summary)"}`);
    sendToPane(msg.text);
    msg.read = true;
    // Small pause between messages so agent can start processing
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }

  try {
    fs.writeFileSync(INBOX_FILE, JSON.stringify(messages, null, 2));
  } catch (e) {
    console.error(`[inbox-watcher] Failed to write inbox: ${e.message}`);
  }
}, INTERVAL);

process.on("SIGTERM", () => { clearInterval(poll); process.exit(0); });
process.on("SIGINT",  () => { clearInterval(poll); process.exit(0); });
