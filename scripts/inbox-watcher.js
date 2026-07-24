#!/usr/bin/env node
// inbox-watcher.js — polls a Claude Code agent inbox and feeds unread messages into a tmux pane
//
// Usage: node inbox-watcher.js <session> <pane> <agent_name> <project_dir> [poll_interval_ms]
//
// Resolves the inbox file by trying several name variants of agent_name.
// Marks messages as read after sending them to the tmux pane.
// Inbox lives at <project_dir>/.claude/y-team-inbox/ — project-local, never global.

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// PANE_TARGET is a tmux pane ID (e.g. %5) — avoids hard-coding window/pane indices.
const [, , SESSION, PANE_TARGET, AGENT_NAME, PROJECT_DIR, INTERVAL_MS = "2000"] = process.argv;

if (!SESSION || !PANE_TARGET || !AGENT_NAME || !PROJECT_DIR) {
  console.error("Usage: node inbox-watcher.js <session> <pane-id> <agent_name> <project_dir> [poll_ms]");
  process.exit(1);
}

const INBOX_DIR = path.join(PROJECT_DIR, ".claude", "y-team-inbox");
const INTERVAL = parseInt(INTERVAL_MS, 10);

// ── Resolve inbox file ────────────────────────────────────────────────────────

function findInbox(name) {
  const first = name.split(" ")[0];
  const candidates = [
    `${name}.json`,
    `${name.replace(" Agent", "")}.json`,
    `${first}.json`,
    `${name.toLowerCase()}.json`,
    `${first.toLowerCase()}.json`,
    `${name.replace(/ /g, "-")}.json`,
  ].map((f) => path.join(INBOX_DIR, f));

  return candidates.find((f) => fs.existsSync(f)) || null;
}

// ── Send text into tmux pane ──────────────────────────────────────────────────

function sendToPane(text) {
  // tmux send-keys doesn't handle newlines well — send line by line
  const lines = text.split("\n");
  for (const line of lines) {
    spawnSync("tmux", ["send-keys", "-t", PANE_TARGET, line, ""], {
      stdio: "inherit",
    });
  }
  // Final Enter to submit
  spawnSync("tmux", ["send-keys", "-t", PANE_TARGET, "", "Enter"], {
    stdio: "inherit",
  });
}

// ── Poll loop ─────────────────────────────────────────────────────────────────

let inboxFile = null;
let waitedMs = 0;
const MAX_WAIT_MS = 60000;

console.log(`[inbox-watcher] Watching inbox for "${AGENT_NAME}" → ${PANE_TARGET} (project: ${PROJECT_DIR})`);

const poll = setInterval(() => {
  // Resolve inbox file if not found yet
  if (!inboxFile) {
    inboxFile = findInbox(AGENT_NAME);
    if (!inboxFile) {
      waitedMs += INTERVAL;
      if (waitedMs >= MAX_WAIT_MS) {
        // Create empty inbox so agent can receive future messages
        inboxFile = path.join(INBOX_DIR, `${AGENT_NAME}.json`);
        fs.mkdirSync(INBOX_DIR, { recursive: true });
        fs.writeFileSync(inboxFile, "[]");
        console.log(`[inbox-watcher] Created inbox: ${inboxFile}`);
      }
      return;
    }
    console.log(`[inbox-watcher] Found inbox: ${inboxFile}`);
  }

  // Read inbox
  let messages;
  try {
    messages = JSON.parse(fs.readFileSync(inboxFile, "utf8"));
  } catch {
    return; // malformed or empty — skip
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

  // Persist read state
  try {
    fs.writeFileSync(inboxFile, JSON.stringify(messages, null, 2));
  } catch (e) {
    console.error(`[inbox-watcher] Failed to write inbox: ${e.message}`);
  }
}, INTERVAL);

// Keep process alive
process.on("SIGTERM", () => { clearInterval(poll); process.exit(0); });
process.on("SIGINT",  () => { clearInterval(poll); process.exit(0); });
