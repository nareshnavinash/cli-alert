# shelldone v1.0.0 — Launch Posts & Articles

All promotional content for the shelldone launch. Each section is copy-paste ready.

GitHub: https://github.com/nareshnavinash/shelldone

---

## 1. Show HN Post

**Title:** Show HN: shelldone – Terminal notifications for long builds in pure bash (Slack, Discord, AI CLI hooks)

**URL:** https://github.com/nareshnavinash/shelldone

### First Comment (Author)

Hi HN, I'm Naresh. I built shelldone because I kept walking away during long builds and missing when they finished. I'd come back 20 minutes later to find my deploy completed 18 minutes ago.

I looked at existing tools. `noti` requires Go and doesn't auto-hook into your shell. `undistract-me` is Linux-only and unmaintained. Fish's `done` plugin is great but Fish-only. None could send a Slack message or notify me when Claude Code finishes a task.

shelldone is a different approach:

- **Pure bash, zero dependencies.** No Go, no Node, no Python runtime. Uses osascript on macOS, notify-send on Linux, BurntToast/WinRT on Windows. curl/wget only needed if you want external channels.
- **Auto-notify via shell hooks.** It taps into zsh's preexec/precmd and bash's DEBUG trap + PROMPT_COMMAND. Any command running longer than a configurable threshold (default 30s) triggers a notification automatically. No wrapper needed.
- **6 external channels.** Slack, Discord, Telegram, Email, WhatsApp (Twilio), and a generic webhook. Each with rate limiting and independent toggle controls.
- **AI CLI hooks.** Native integration with Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor. Each tool's hook system is different — shelldone reads the JSON event from stdin, extracts metadata, and sends a notification. `shelldone setup claude-hook` and you're done.
- **Smart focus detection.** On macOS it checks which app is frontmost via AppleScript; on Linux it walks the PID tree from xdotool. If you're staring at your terminal, it suppresses the notification.

Some things I'm happy with technically: pure-bash JSON escaping (no jq dependency), background sound playback with watchdog timers to prevent hangs, and marker-based RC file management for clean uninstall.

374 tests, CI on macOS and Linux. MIT licensed. Feedback welcome — especially on design, feature gaps, or better patterns for shell hook integration.

---

## 2. Reddit Posts

---

### r/commandline

**Title:** shelldone: auto-notify when long-running commands finish (desktop, Slack, Discord, and more)

**Body:**

I got tired of guessing when my builds and deploys finished, so I built shelldone — a terminal notification system that hooks into your shell and alerts you automatically.

**How it works:**

After installation, shelldone integrates with your shell via preexec/precmd (zsh) or DEBUG trap (bash). Any command running longer than a configurable threshold (default 30s) triggers a desktop notification, sound, and optional external alerts — without needing to wrap the command.

```bash
# Just run commands normally
make build-all    # 5 min build -> notification fires
npm install       # 2 min install -> notification fires
ls                # instant -> no notification
vim file.txt      # excluded by default -> no notification
```

You can also wrap explicitly: `alert make build`

**What sets it apart:**

- Pure bash, no compiled dependencies
- 6 external channels: Slack, Discord, Telegram, Email, WhatsApp, generic webhook
- Smart focus detection — won't bother you if you're already looking at the terminal
- Glob-based exclusions (`vim`, `ssh`, `npm*`, etc.)
- Mute, schedule quiet hours, toggle layers independently
- AI CLI hooks: Claude Code, Codex, Gemini, Copilot, Cursor

**Install:**

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh
```

Works on macOS, Linux, WSL, and Windows (Git Bash/MSYS2/Cygwin).

GitHub: https://github.com/nareshnavinash/shelldone

Feedback welcome — especially around edge cases with shell hooks or platform-specific notification quirks.

---

### r/bash

**Title:** Built a terminal notification system in pure bash — zero dependencies, shell hooks for auto-notify

**Body:**

I wanted a notification system for long-running commands that didn't pull in Go, Node, or Python. The result is shelldone — 100% bash, zero runtime dependencies.

**Technical highlights:**

- **Auto-notify via shell hooks.** Uses `preexec`/`precmd` in zsh and `DEBUG` trap + `PROMPT_COMMAND` in bash. Records the start time before each command, checks elapsed time after completion, and fires a notification if it exceeded the threshold.
- **Pure-bash JSON escaping.** For sending payloads to Slack/Discord/Telegram webhooks without requiring `jq`. Character-by-character escape for quotes, backslashes, newlines, tabs.
- **HTTP transport fallback chain.** Prefers `curl`, falls back to `wget`, then to raw `/dev/tcp` for plain HTTP endpoints.
- **Lazy loading with double-source guards.** External notification module only loads if a channel env var is set. Each lib file has a guard variable to prevent re-initialization if sourced multiple times.
- **Background sound with watchdog timers.** Sound playback runs in background with a configurable timeout to prevent hung processes.
- **Platform detection at source time.** Single `uname -s` check sets platform-specific defaults for sounds, notification tools, and TTS engines.

The whole thing runs on macOS (osascript + afplay + say), Linux (notify-send + paplay/aplay + espeak), WSL and Windows (BurntToast/WinRT via powershell.exe).

External channels (Slack, Discord, Telegram, Email, WhatsApp, webhook) only need `curl` or `wget`.

374 tests run in CI on both macOS and Linux. ShellCheck clean.

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh
```

GitHub: https://github.com/nareshnavinash/shelldone

Would love feedback from other bash devs — especially if you've dealt with the subtleties of DEBUG trap in bash vs. preexec in zsh, or if you see better patterns for the JSON escaping.

---

### r/devops

**Title:** shelldone — get Slack/Discord/Telegram alerts when your builds and deploys finish (pure bash, zero deps)

**Body:**

How often do you kick off a build or deploy and then switch context? I built shelldone to close that feedback loop.

**The pitch for DevOps workflows:**

- Run `alert ./deploy.sh production` — get a desktop notification + Slack message when it finishes, with exit code, duration, project name, git branch, and hostname.
- Or skip the wrapper entirely: shelldone auto-notifies for any command running longer than your threshold.
- 6 external channels: **Slack** (Block Kit formatted messages with color-coded status), **Discord**, **Telegram**, **Email**, **WhatsApp** (via Twilio), and **generic webhook** (JSON payload with title, message, exit code).
- Per-channel rate limiting, independent toggles, and quiet hours scheduling.

**Slack integration example:**

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
alert terraform apply -auto-approve
# -> Slack message with green/red sidebar, command, duration, exit code,
#    hostname, working directory, git branch, timestamp
```

**Webhook payload for custom integrations:**

```json
{
  "title": "deploy Complete",
  "message": "✓ ./deploy.sh production (2m 15s, exit 0)",
  "exit_code": 0
}
```

It also hooks into AI coding assistants (Claude Code, Codex, Gemini, Copilot, Cursor) — so if you're using AI tools for infrastructure code, you get notified when they finish too.

Pure bash, no compiled binaries, works on macOS/Linux/WSL/Windows. Install from source:

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh
```

GitHub: https://github.com/nareshnavinash/shelldone

---

### r/programming

**Title:** shelldone — cross-platform terminal notifications in pure bash (desktop, Slack, Discord, AI CLI hooks)

**Body:**

I released v1.0.0 of shelldone, a terminal notification system that alerts you when long-running commands finish. It works across macOS, Linux, WSL, and Windows, written entirely in bash with no runtime dependencies.

**Core design:**

shelldone hooks into your shell (zsh preexec/precmd or bash DEBUG trap) to automatically detect when commands exceed a time threshold and fire notifications. No wrapper required for auto-notify, but you can also use `alert <command>` for explicit notification.

**Notification channels:**

Desktop popups, sound alerts, text-to-speech, plus 6 external channels — Slack (with Block Kit formatted messages), Discord, Telegram, Email, WhatsApp, and generic webhooks. Each channel has independent rate limiting and can be toggled on/off.

**Architecture decisions:**

- Pure-bash JSON escaping instead of requiring jq
- HTTP transport fallback: curl -> wget -> /dev/tcp (plain HTTP only)
- Lazy module loading with source guards
- Background processes with watchdog timers for sound/TTS
- Config via environment variables + optional config file
- Marker-based shell RC file management for clean install/uninstall

**AI CLI integration:**

Native hooks for Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor. Each AI tool has a different hook mechanism — shelldone adapts to each, reading JSON events from stdin and dispatching notifications through the same channel infrastructure.

374 tests, CI on macOS + Linux, ShellCheck clean.

GitHub: https://github.com/nareshnavinash/shelldone

---

### r/ClaudeAI

**Title:** shelldone — get notified (desktop + Slack/Discord) when Claude Code finishes a task

**Body:**

If you use Claude Code and walk away while it works, you know the problem: you come back and the task finished minutes ago. shelldone fixes this.

**How it works with Claude Code:**

shelldone registers a native Stop hook in Claude Code's settings (`~/.claude/settings.json`). When Claude finishes its turn, it fires a JSON event to shelldone's hook script. shelldone reads the event, extracts the stop reason, and sends a notification through whatever channels you've configured.

**Setup:**

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh

# Install the Claude Code hook
shelldone setup claude-hook
```

That's it. Now every time Claude Code completes a task, you get:

- A desktop notification (macOS/Linux/Windows)
- A sound alert
- Optional: Slack, Discord, Telegram, Email, WhatsApp, or webhook notifications

**Adding Slack notifications for Claude completions:**

```bash
# Add to ~/.config/shelldone/config (persists for hook processes)
shelldone config edit
# Uncomment: export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/..."
```

The Slack message includes the AI name, stop reason, hostname, directory, git branch, and timestamp — formatted with Block Kit.

**Other AI CLIs supported:**

shelldone also has native hooks for Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor. `shelldone setup ai-hooks` installs all of them at once.

You can toggle individual AI notifications: `shelldone toggle claude off` / `shelldone toggle claude on`.

GitHub: https://github.com/nareshnavinash/shelldone

---

### r/LocalLLaMA

**Title:** shelldone — terminal notifications for AI CLI tools (Claude Code, Codex, Gemini, Copilot, Cursor)

**Body:**

If you run AI coding assistants from the terminal and switch context while they work, shelldone can notify you when they finish.

**Supported AI CLIs:**

| Tool | Hook Type | Setup Command |
|------|-----------|---------------|
| Claude Code | Native Stop hook | `shelldone setup claude-hook` |
| Codex CLI (OpenAI) | Experimental hook | `shelldone setup codex-hook` |
| Gemini CLI | Command hook | `shelldone setup gemini-hook` |
| GitHub Copilot CLI | Session hook | `shelldone setup copilot-hook` |
| Cursor | Stop hook | `shelldone setup cursor-hook` |
| Aider | Wrapper | `alert aider "fix the bug"` |

Each tool has a different hook mechanism. shelldone adapts to each one — reading JSON events, extracting metadata (stop reason, task status), and routing notifications.

**What you get:**

- Desktop notification with the AI tool name and task status
- Sound alert
- Optional external notifications: Slack, Discord, Telegram, Email, WhatsApp, webhook
- Per-AI toggle: `shelldone toggle claude off` to silence one tool without affecting others

**Install all hooks at once:**

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh
shelldone setup ai-hooks
```

It's pure bash, zero dependencies, works on macOS/Linux/WSL/Windows. Also auto-notifies for regular terminal commands that run longer than a configurable threshold, so it's useful beyond just AI tools.

GitHub: https://github.com/nareshnavinash/shelldone

---

## 3. Twitter/X Thread

**Tweet 1:**
You kick off a build, switch to Slack, come back 20 minutes later — the build finished 18 minutes ago.

I built shelldone to fix this. Terminal notifications for long-running commands. Pure bash, zero deps.

https://github.com/nareshnavinash/shelldone

**Tweet 2:**
What shelldone does:

- Auto-detects commands running longer than 30s
- Desktop notification + sound alert
- Slack, Discord, Telegram, Email, WhatsApp, webhook
- Mute, quiet hours, per-channel toggles
- macOS, Linux, WSL, Windows

No wrappers needed. Just run commands normally.

**Tweet 3:**
The AI CLI angle: shelldone hooks into Claude Code, Codex CLI, Gemini CLI, Copilot CLI, and Cursor.

When your AI assistant finishes a task, you get notified — desktop, Slack, Discord, whatever you've configured.

`shelldone setup ai-hooks`

**Tweet 4:**
Six external notification channels:

- Slack (Block Kit formatted, color-coded)
- Discord (embedded messages)
- Telegram (bot API)
- Email (sendmail/mail)
- WhatsApp (Twilio)
- Generic webhook (JSON payload)

Each with independent rate limiting and toggles.

**Tweet 5:**
The technical bits:

- Pure bash, no Go/Node/Python runtime
- JSON escaping without jq
- HTTP fallback: curl -> wget -> /dev/tcp
- Shell hooks: zsh preexec/precmd, bash DEBUG trap
- Focus detection: skips if you're looking at the terminal
- 374 tests, ShellCheck clean

**Tweet 6:**
Install in 30 seconds:

```
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone && ./install.sh
shelldone test-notify
```

Works with bash and zsh on macOS, Linux, WSL, and Windows.

**Tweet 7:**
shelldone is MIT licensed and open source. v1.0.0 just shipped.

If you've ever missed a finished build, give it a try. Feedback, issues, and PRs welcome.

https://github.com/nareshnavinash/shelldone

---

## 4. LinkedIn Post

I just released shelldone v1.0.0 — an open-source terminal notification system that alerts you when builds, deploys, and tests finish.

If you work in a terminal, you've been there. You kick off a long command, switch context, and come back to find it completed minutes ago. That idle time adds up.

shelldone hooks into your shell and automatically notifies you when commands exceed a time threshold. No wrappers needed — just run commands as you always do.

What makes it different:

- Cross-platform: macOS, Linux, WSL, Windows
- Six external channels: Slack, Discord, Telegram, Email, WhatsApp, webhooks
- AI CLI hooks: Claude Code, Codex CLI, Gemini CLI, Copilot CLI, Cursor
- Pure bash, zero runtime dependencies
- Notification control: mute, quiet hours, per-channel toggles

For teams, the Slack integration sends structured messages with command, duration, exit code, project, git branch, and hostname. It closes the feedback loop between starting a job and knowing it's done.

MIT licensed, 374 tests, CI on macOS and Linux.

https://github.com/nareshnavinash/shelldone

---

## 5. Mastodon/Fediverse Post

I built shelldone — a terminal notification system in pure bash that alerts you when long-running commands finish.

Desktop notifications, sounds, Slack, Discord, Telegram, Email, WhatsApp, webhooks. Auto-detects long commands via shell hooks. Hooks into AI CLIs (Claude Code, Codex, Gemini, Copilot, Cursor).

Zero deps, cross-platform, MIT licensed.

https://github.com/nareshnavinash/shelldone

#bash #terminal #cli #devops #opensource #productivity #shellscript

---

## 6. dev.to Article Draft

```
---
title: I built a terminal notification system in pure bash — here's how
published: false
description: shelldone sends desktop alerts, sounds, Slack, Discord, Telegram, and more when your builds finish. Zero dependencies, cross-platform, AI CLI hooks.
tags: bash, opensource, productivity, devops
---
```

We've all been there. You run `make build`, switch to Slack or your browser, and return to your terminal 20 minutes later only to discover the build finished 18 minutes ago. Or you start a deploy, step away for coffee, and come back to find it failed five seconds after you left.

The feedback loop between "command started" and "command finished" is broken the moment you lose sight of your terminal. I wanted to fix that.

### The existing landscape

I tried several tools before building my own. `noti` is decent but requires Go and doesn't auto-detect long commands. `undistract-me` auto-detects but is Linux-only, Ubuntu-specific, and hasn't been updated in years. Fish shell's `done` plugin is elegant but only works with Fish. None of them could send me a Slack message, and none of them knew about AI coding assistants.

### What shelldone does

shelldone is a terminal notification system written entirely in bash. After installation, it hooks into your shell and automatically notifies you when any command takes longer than a configurable threshold (default: 30 seconds). No need to remember a wrapper — just run commands the way you always have:

```bash
make build-all    # 5 min build -> desktop notification + sound
npm install       # 2 min install -> notification fires
ls                # instant -> nothing happens
vim file.txt      # excluded by default -> nothing happens
```

You can also wrap commands explicitly when you want notification regardless of duration:

```bash
alert ./deploy.sh production
alert docker compose up --build
```

### How auto-notify works

The auto-notify mechanism is probably the most interesting technical piece. In zsh, shelldone uses `preexec` and `precmd` hooks — `preexec` fires before every command and records the timestamp and command name, `precmd` fires after the command completes and checks whether the elapsed time exceeded the threshold.

In bash, it's trickier. Bash doesn't have native preexec/precmd, so shelldone uses the `DEBUG` trap to capture the command before execution and `PROMPT_COMMAND` to check the result after. This requires careful handling to avoid interfering with existing traps and prompt commands.

Both paths feed into the same notification engine, which handles platform detection, focus checking, and channel dispatch.

### Focus detection

One of the early annoyances was getting a notification while I was actively staring at my terminal — the command finished, I saw it, and then a notification popped up telling me what I already knew.

shelldone's focus detection suppresses notifications when your terminal is the frontmost application. On macOS, it queries the frontmost app via AppleScript. On Linux, it uses `xdotool` to get the active window PID and walks the process tree to check if your shell owns it. If you're already looking at the terminal, the notification is silently skipped.

### External notification channels

Desktop notifications are useful when you're at your computer. But what if you walked to the kitchen? shelldone supports six external channels:

- **Slack** — sends Block Kit formatted messages with color-coded status, command, duration, exit code, project, git branch, hostname, and timestamp
- **Discord** — embedded messages with color sidebar
- **Telegram** — via the Bot API
- **Email** — using sendmail or mail
- **WhatsApp** — via Twilio's API
- **Generic webhook** — JSON payload to any endpoint

```bash
# Configure Slack
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"

# Now every notification also goes to Slack
alert terraform apply
```

External notifications fire even when the terminal is focused — they're designed for when you're away from your machine entirely. Each channel has independent rate limiting and can be toggled on or off without removing the configuration.

### Pure bash, zero dependencies

I made a deliberate choice to avoid compiled dependencies. shelldone uses only tools that come pre-installed on each platform: `osascript` and `afplay` on macOS, `notify-send` and `paplay` on Linux, `powershell.exe` on Windows/WSL.

The only optional dependency is `curl` or `wget` — needed if you want external channels (Slack, Discord, etc.). For HTTP transport, shelldone tries curl first, falls back to wget, and can even use bash's `/dev/tcp` for plain HTTP endpoints.

JSON payloads are built with a custom escaping function — character-by-character handling of quotes, backslashes, newlines, and tabs. It's not fast, but it's correct and it means zero dependency on `jq`.

### AI CLI integration

This is the feature I'm most excited about. If you use AI coding assistants from the terminal — Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, or Cursor — shelldone can hook into their native event systems and notify you when they finish a task.

```bash
# Install hooks for all detected AI CLIs
shelldone setup ai-hooks

# Or individually
shelldone setup claude-hook
shelldone setup codex-hook
```

Each AI tool has a different hook mechanism. Claude Code uses Stop hooks registered in `~/.claude/settings.json`. Codex CLI uses experimental hooks in `~/.codex/config.json`. Gemini, Copilot, and Cursor each have their own approach. shelldone provides a hook script for each that reads the JSON event from stdin, extracts relevant metadata (stop reason, task status), and dispatches through the same notification infrastructure.

You can toggle notifications per AI tool: `shelldone toggle claude off` disables Claude notifications without affecting anything else.

### Notification control

shelldone gives you fine-grained control over when and how you get notified:

```bash
shelldone mute 30m           # silence everything for 30 minutes
shelldone schedule 22:00-08:00   # quiet hours (crosses midnight)
shelldone toggle sound off       # disable sound, keep desktop + channels
shelldone toggle slack off       # disable Slack, keep everything else
```

### Testing

The project has 374 tests covering unit, integration, and end-to-end scenarios. Tests run in CI on both macOS and Linux via GitHub Actions. ShellCheck lints all scripts.

### Getting started

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
./install.sh

# Verify
shelldone status
shelldone test-notify
```

The installer detects your platform, sets up shell integration in your rc files, and installs hooks for any AI CLIs it finds.

### What's next

I'm working on Homebrew and Debian packaging to make installation simpler. The generic webhook channel makes it easy to integrate with any service that accepts JSON — PagerDuty, Opsgenie, custom dashboards, whatever your team uses.

shelldone is MIT licensed and contributions are welcome. If you've run into edge cases with shell hooks, notification systems, or platform quirks, I'd love to hear about them.

GitHub: [https://github.com/nareshnavinash/shelldone](https://github.com/nareshnavinash/shelldone)

---

## 7. Hashnode/Medium Article Draft

**Title:** Never miss a finished build again

**Subtitle:** How I built shelldone — a terminal notification system that works everywhere

---

There's a small but persistent gap in the developer workflow that costs everyone time: the moment between kicking off a long-running command and finding out it finished.

You start a build. You switch to your browser. You get pulled into a Slack thread. Ten minutes later you check your terminal — the build finished nine minutes ago. Sometimes it failed, and you've been waiting on nothing.

This gap compounds. Every time you context-switch away from a terminal, you're gambling on when to switch back. Check too early and the command is still running. Check too late and you've wasted idle time. The longer the command, the wider the gap.

I wanted something that would simply tap me on the shoulder when a command finished. So I built shelldone.

### What it does

shelldone is a terminal notification system. After a one-time install, it hooks into your shell and watches for commands that take longer than a configurable threshold — 30 seconds by default. When one finishes, it sends you a notification.

The notification can be a desktop popup, a sound alert, a text-to-speech announcement, or a message on Slack, Discord, Telegram, Email, WhatsApp, or a generic webhook. You choose which channels to enable. Most people start with desktop notifications and add Slack or Discord once they see the value.

It works on macOS, Linux, WSL, and Windows. No wrapper needed for most commands — just run them the way you always have. shelldone detects long-running commands automatically.

### Why not just use an existing tool?

I looked at several. Most notification tools are platform-specific (Linux only, macOS only), require a compiled runtime (Go, Python), or only support desktop notifications without any external channel support. None of them handled the increasingly common case of AI coding assistants.

The tool I wanted needed to:
1. Work on every platform I use
2. Detect long commands automatically (no wrappers to remember)
3. Send notifications to Slack so I'd see them on my phone
4. Notify me when AI CLI tools like Claude Code finish a task
5. Not require me to install Go, Node, or Python

### The pure bash decision

shelldone is written entirely in bash. It uses the notification tools already on your system — `osascript` on macOS, `notify-send` on Linux, PowerShell on Windows. The only optional dependency is `curl` or `wget`, needed for sending messages to Slack, Discord, and other external services.

This means installation is cloning a repo and running a script. No build step, no package manager dependency, no runtime version issues.

### AI CLI integration

This might be the most useful feature for developers using AI coding assistants. shelldone has native hook integration with Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor. When these tools finish a task, shelldone sends a notification through all your configured channels.

```bash
shelldone setup ai-hooks
```

One command installs hooks for every AI CLI it detects on your system. Now when Claude Code finishes generating that migration file or Codex completes a refactor, you know immediately — even if you're in another app, on your phone, or away from your desk.

### Staying in control

Getting too many notifications is almost as bad as getting none. shelldone has several mechanisms to keep noise down:

- **Focus detection** — if you're already looking at the terminal, the notification is suppressed
- **Exclusion patterns** — editors, pagers, and interactive tools like `vim`, `ssh`, and `top` are excluded by default
- **Mute and quiet hours** — `shelldone mute 1h` or `shelldone schedule 22:00-08:00`
- **Per-channel toggles** — disable sound but keep desktop popups, or turn off Slack but keep Telegram

### Getting started

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
./install.sh
```

The installer handles everything: platform detection, shell integration, and AI CLI hook setup. Run `shelldone test-notify` to verify it works.

shelldone is open source under the MIT license. It has 374 tests and runs CI on macOS and Linux. Contributions, feedback, and bug reports are welcome.

GitHub: [https://github.com/nareshnavinash/shelldone](https://github.com/nareshnavinash/shelldone)

---

## 8. Claude Code Integration Guide Draft

**Title:** Get notified when Claude Code finishes with shelldone

---

If you use Claude Code, you've probably experienced this: you give Claude a task, switch to another window, and come back to find it finished minutes ago. The idle time between completion and your awareness adds up.

shelldone fixes this by hooking into Claude Code's native Stop hook system. When Claude finishes, shelldone sends a notification — desktop popup, sound, Slack, Discord, or whatever channels you've configured.

### How the integration works

Claude Code supports hooks that run at specific lifecycle events. shelldone registers a Stop hook — a script that Claude Code calls every time it finishes its turn. Claude passes a JSON event to the hook via stdin, which includes the stop reason (e.g., "end_turn", "max_tokens").

shelldone's hook script (`hooks/claude-done.sh`) reads this JSON, extracts the stop reason, and dispatches a notification through shelldone's standard notification infrastructure. That means you get the same channel support (desktop, Slack, Discord, Telegram, Email, WhatsApp, webhook) and the same controls (mute, toggles, quiet hours) as regular command notifications.

### Setup

**Step 1: Install shelldone**

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
./install.sh
```

**Step 2: Install the Claude Code hook**

```bash
shelldone setup claude-hook
```

This adds shelldone's hook script to `~/.claude/settings.json`. You can verify it worked:

```bash
shelldone status
```

Look for the "AI CLI Hooks" section — it should show Claude Code as configured.

**Step 3: Test it**

Start Claude Code and give it a task. When it finishes, you should see a desktop notification with "Claude Code — Task complete" and the stop reason.

### Adding Slack or Discord notifications

Desktop notifications are great when you're at your computer. But if you step away, you'll want notifications on your phone or in a team channel.

**Option 1: Config file (recommended for hooks)**

```bash
shelldone config edit
```

Uncomment and fill in the webhook URL:

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

Save the file. The config file is read by hook scripts on every invocation, so no restart needed for new Claude Code sessions.

**Option 2: Environment variable**

Add to your `.zshrc` or `.bashrc` before starting Claude Code:

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

Note: if you set this after Claude Code is already running, Claude's process won't see it. You'd need to restart Claude Code to pick up new environment variables.

The Slack message from an AI hook includes the AI tool name, stop reason, hostname, working directory, git branch, and timestamp — all formatted with Slack's Block Kit.

### Discord, Telegram, and other channels

The same approach works for any channel. Set the appropriate environment variable in your config file:

```bash
# Discord
export SHELLDONE_DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."

# Telegram
export SHELLDONE_TELEGRAM_TOKEN="123456:ABC-DEF..."
export SHELLDONE_TELEGRAM_CHAT_ID="your-chat-id"
```

### Toggling Claude notifications

If you want to temporarily disable Claude Code notifications without removing the hook:

```bash
shelldone toggle claude off    # silence Claude notifications
shelldone toggle claude on     # re-enable
```

This only affects Claude Code — other AI CLI notifications and regular command notifications continue as configured.

### Other AI CLIs

shelldone has the same native hook integration for four other AI CLI tools:

```bash
shelldone setup codex-hook      # Codex CLI (OpenAI)
shelldone setup gemini-hook     # Gemini CLI
shelldone setup copilot-hook    # GitHub Copilot CLI
shelldone setup cursor-hook     # Cursor

# Or install all at once
shelldone setup ai-hooks
```

For Aider, which doesn't support native hooks, use the `alert` wrapper:

```bash
alert aider "fix the login bug"
```

With shelldone configured, your workflow becomes: give Claude a task, switch to whatever needs your attention, and get notified the moment it finishes. No polling, no guessing.

GitHub: [https://github.com/nareshnavinash/shelldone](https://github.com/nareshnavinash/shelldone)
