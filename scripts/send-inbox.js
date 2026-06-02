#!/usr/bin/env node
// send-inbox.js — append a message to an agent's inbox file
// The inbox-watcher running in the target agent's pane will pick this up and deliver it.
//
// Usage:
//   node send-inbox.js <agent-name> <message> [--from <sender>] [--summary <text>]
//
// Examples:
//   node send-inbox.js team-lead "Phase 1 tasks complete. Coverage >=95%." --from "Engineer Web"
//   node send-inbox.js qa "Phase 2 engineers done. Start verification." --from "Team Lead"

const fs = require("fs");
const path = require("path");
const os = require("os");

const INBOX_DIR = path.join(os.homedir(), ".claude", "teams", "default", "inboxes");

const args = process.argv.slice(2);
let agentName = null;
let messageText = null;
let from = "agent";
let summary = "";

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--from") { from = args[++i]; }
  else if (args[i] === "--summary") { summary = args[++i]; }
  else if (!agentName) { agentName = args[i]; }
  else if (!messageText) { messageText = args[i]; }
}

if (!agentName || !messageText) {
  console.error("Usage: node send-inbox.js <agent-name> <message> [--from <sender>] [--summary <text>]");
  process.exit(1);
}

fs.mkdirSync(INBOX_DIR, { recursive: true });
const inboxFile = path.join(INBOX_DIR, `${agentName}.json`);

let messages = [];
if (fs.existsSync(inboxFile)) {
  try { messages = JSON.parse(fs.readFileSync(inboxFile, "utf8")); } catch {}
}

messages.push({
  from,
  text: messageText,
  summary: summary || messageText.slice(0, 80),
  read: false,
  timestamp: new Date().toISOString(),
});

fs.writeFileSync(inboxFile, JSON.stringify(messages, null, 2));
console.log(`[send-inbox] → ${agentName}: ${messageText.slice(0, 70)}${messageText.length > 70 ? "…" : ""}`);
