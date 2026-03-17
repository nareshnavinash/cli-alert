# Community Submissions & Comparison Content for shelldone

> All entries below are copy-paste ready. Replace nothing -- just open the PR or paste the text.

---

## 1. awesome-cli-apps PR

**Repository:** https://github.com/agarrharr/awesome-cli-apps

**Category:** Productivity > Notifications

**PR Title:**

```
Add shelldone - terminal notification system for long-running commands
```

**Entry to add** (place under `## Productivity` or the most relevant notification/utilities subsection):

```markdown
- [shelldone](https://github.com/nareshnavinash/shelldone) - Terminal notifications for long-running commands with Slack, Discord, Telegram, and AI CLI hooks.
```

**PR Description:**

```markdown
## What is shelldone?

shelldone is a cross-platform terminal notification system that alerts you when
long-running commands finish. It supports macOS, Linux, WSL, and Windows (Git Bash).

**Key highlights:**

- Auto-notify for any command exceeding a configurable threshold (no wrapper needed)
- 6 external channels: Slack, Discord, Telegram, Email, WhatsApp, and generic webhooks
- AI CLI integration: hooks for Claude Code, Codex, Gemini, Copilot, and Cursor
- Pure bash with zero dependencies
- Sound alerts, text-to-speech, focus detection, mute/schedule/toggle controls
- 374 tests, MIT licensed

**Why it belongs on this list:**

Terminal notification tools are a core productivity category. shelldone is the most
feature-complete option available — it combines auto-notification, external channel
delivery, and AI CLI integration in a single zero-dependency package. It fills a gap
that existing tools like noti and undistract-me only partially cover.

- GitHub: https://github.com/nareshnavinash/shelldone
- License: MIT
- Version: 1.0.0
```

---

## 2. awesome-shell PR

**Repository:** https://github.com/alebcay/awesome-shell

**Category:** Command-Line Productivity (or Notifications if a subsection exists)

**PR Title:**

```
Add shelldone - cross-platform terminal notifications with external channels and AI CLI hooks
```

**Entry to add** (matching the existing `[tool](url) - Description` format):

```markdown
- [shelldone](https://github.com/nareshnavinash/shelldone) - Cross-platform terminal notification system for long-running commands. Auto-notify, desktop/sound/TTS alerts, 6 external channels (Slack, Discord, Telegram, Email, WhatsApp, webhook), and AI CLI hooks. Pure bash, zero dependencies.
```

**PR Description:**

```markdown
## Adding shelldone

shelldone is a pure bash terminal notification system that works on macOS, Linux,
WSL, and Windows (Git Bash). It auto-detects when commands run longer than a
configurable threshold and sends notifications through desktop popups, sound, TTS,
and external channels.

### Why add it?

- **Cross-platform**: macOS, Linux, WSL, Windows — same tool everywhere
- **Auto-notify**: no wrapper needed; integrates via shell hooks (preexec/precmd for zsh, DEBUG trap for bash)
- **External channels**: Slack, Discord, Telegram, Email, WhatsApp, and generic webhooks — get notified on your phone
- **AI CLI hooks**: native integration with Claude Code, Codex, Gemini, Copilot, and Cursor
- **Pure bash**: zero dependencies, no compilers, no runtimes
- **Well-tested**: 374 tests with CI on macOS and Linux
- **MIT licensed**

This fills a gap in the awesome-shell list — there is currently no comprehensive
terminal notification tool listed that covers external channels and AI CLI integration.

GitHub: https://github.com/nareshnavinash/shelldone
```

---

## 3. awesome-bash PR

**Repository:** https://github.com/awesome-lists/awesome-bash

**Category:** Utilities / Command-Line Productivity

**PR Title:**

```
Add shelldone - pure bash terminal notification system
```

**Entry to add** (matching the list's format):

```markdown
- [shelldone](https://github.com/nareshnavinash/shelldone) - Cross-platform terminal notification system for long-running commands. Auto-notify via shell hooks, desktop/sound/TTS alerts, 6 external channels (Slack, Discord, Telegram, Email, WhatsApp, webhook), AI CLI integration, and notification controls (mute, toggle, schedule). Pure bash, zero dependencies, 374 tests.
```

**PR Description:**

```markdown
## Adding shelldone

shelldone is a **pure bash** terminal notification system — no Go, no Python, no
Node.js, no compiled binaries. It uses only built-in system tools and optional
curl/wget for external channels.

### Why it fits awesome-bash

This project is written entirely in bash and demonstrates advanced bash patterns:

- Shell hooks (zsh preexec/precmd, bash DEBUG trap + PROMPT_COMMAND)
- Pure-bash JSON escaping and construction (no jq dependency)
- HTTP transport via curl, wget, or /dev/tcp fallback
- Cross-platform detection and adapter pattern
- Rate limiting with stamp files
- Background process management with watchdog timers

### Features

- Auto-notify for commands exceeding a configurable threshold
- Desktop notifications, sound alerts, and text-to-speech
- 6 external channels: Slack, Discord, Telegram, Email, WhatsApp, webhook
- AI CLI hooks: Claude Code, Codex, Gemini, Copilot, Cursor
- Mute, toggle, schedule, glob exclusions, focus detection
- Works on macOS, Linux, WSL, and Windows (Git Bash)
- 374 tests, CI with ShellCheck
- MIT licensed

GitHub: https://github.com/nareshnavinash/shelldone
```

---

## 4. terminals-are-sexy PR

**Repository:** https://github.com/k4m4/terminals-are-sexy

**Category:** Tools and Plugins (or the most relevant section)

**PR Title:**

```
Add shelldone - terminal notifications with external channels and AI hooks
```

**Entry to add** (matching the list's `[tool](url) - Description` format):

```markdown
- [shelldone](https://github.com/nareshnavinash/shelldone) - Cross-platform terminal notification system for long-running commands. Sends desktop, sound, Slack, Discord, Telegram, Email, WhatsApp, and webhook alerts. Hooks into AI CLIs (Claude Code, Codex, Gemini, Copilot, Cursor). Pure bash, zero dependencies.
```

**PR Description:**

```markdown
## Adding shelldone

shelldone is a terminal notification system that tells you when long-running
commands finish — wherever you are. Desktop popup, sound, voice, Slack ping,
Discord message, Telegram alert, email, or WhatsApp notification.

### What makes it terminal-sexy

- **Works everywhere**: macOS, Linux, WSL, Windows (Git Bash) — bash and zsh
- **Auto-notify**: no wrapper needed. Commands exceeding a threshold (default 30s) trigger notifications automatically
- **6 external channels**: Slack, Discord, Telegram, Email, WhatsApp, generic webhook
- **AI CLI integration**: hooks for Claude Code, Codex CLI, Gemini CLI, Copilot CLI, and Cursor
- **Notification controls**: mute with timer, per-layer toggle, quiet hours schedule
- **Pure bash**: zero runtime dependencies
- **374 tests**, CI, MIT licensed

### Use case

You run `make build-all`, switch to Slack, and 5 minutes later your phone buzzes
with a Slack notification: "make build-all complete (5m 12s, exit 0)". No tab
switching, no polling, no missed builds.

GitHub: https://github.com/nareshnavinash/shelldone
```

---

## 5. Comparison Blog Post

### Best Terminal Notification Tools in 2026: shelldone vs noti vs undistract-me vs done

If you spend your days in the terminal, you know the routine. You kick off a build, a test suite, or a deploy. You switch to Slack, check email, or grab coffee. Five minutes later you are back at the terminal wondering how long ago that command finished. Maybe it failed. Maybe it has been sitting there for three minutes waiting for you to notice.

Terminal notification tools solve this by alerting you the moment a long-running command completes. But which one should you use? In this guide, we compare four popular options: **shelldone**, **noti**, **undistract-me**, and **done** (the fish plugin).

#### Quick Comparison

| Feature | shelldone | noti | undistract-me | done (fish) |
|---|---|---|---|---|
| Auto-notify | Yes | No | Yes | Yes |
| Platforms | macOS, Linux, WSL, Windows | macOS, Linux | Ubuntu/Debian | macOS, Linux |
| Shell support | bash + zsh | Any (wraps commands) | bash + zsh | fish only |
| External channels | 6 (Slack, Discord, Telegram, Email, WhatsApp, webhook) | 3 (Slack, HipChat, Pushbullet) | None | None |
| AI CLI integration | 5 tools (Claude Code, Codex, Gemini, Copilot, Cursor) | None | None | None |
| Sound + TTS | Yes (both) | Sound only | No | No |
| Focus detection | Yes | No | Yes | Yes |
| Mute / toggle / schedule | Yes | No | No | No |
| Dependencies | None (pure bash) | Go runtime | Python | fish shell |
| License | MIT | MIT | GPL-3.0 | MIT |

#### shelldone

[shelldone](https://github.com/nareshnavinash/shelldone) is the newest and most feature-complete tool in this space. It is a pure bash notification system that works on macOS, Linux, WSL, and Windows (Git Bash) with zero dependencies.

Its standout feature is breadth. You get auto-notify for long-running commands, desktop popups, configurable sounds, text-to-speech, and six external notification channels: Slack, Discord, Telegram, Email, WhatsApp, and generic webhooks. That means you can walk away from your laptop entirely and still get a Slack ping or a WhatsApp message when your deploy finishes.

shelldone also integrates natively with AI coding assistants. It ships hooks for Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor, so you get notified when an AI agent finishes its task. This is a category that did not exist when tools like noti were built, and shelldone is the first notification tool to address it.

On the control side, shelldone offers mute with timed duration, per-layer toggles (you can disable sound but keep Slack, or mute desktop but keep Telegram), quiet hours scheduling, and glob-based command exclusions. It has 374 tests and CI on both macOS and Linux.

**Strengths:** Most features of any tool in this category. Cross-platform. Zero dependencies. AI CLI hooks. Six external channels. Extensive notification controls.

**Considerations:** Newest tool, so community size is still growing. Requires git clone install (package managers coming soon).

#### noti

[noti](https://github.com/variadico/noti) is a Go binary that triggers notifications when a command finishes. You prefix your command with `noti`, and it sends a desktop notification on completion. It supports Slack, HipChat (now deprecated), and Pushbullet for external delivery. Distributed as a compiled Go binary, installation is straightforward where Go packages are available.

**Strengths:** Simple interface. Single-file Go binary. Mature codebase (since 2015).

**Considerations:** No auto-notify — you must prefix every command. HipChat is obsolete. No Discord, Telegram, Email, or WhatsApp. No AI CLI integration. No TTS or notification controls.

#### undistract-me

[undistract-me](https://github.com/jml/undistract-me) is the pioneer of auto-notify in the terminal. Built for Ubuntu, it hooks into bash and zsh to notify you when long-running commands complete. Install it, and commands exceeding 10 seconds trigger a desktop notification. No configuration needed.

**Strengths:** Simplicity is its greatest asset. Install and forget. Available via `apt install undistract-me`.

**Considerations:** Desktop only — no external channels, sound, or TTS. Ubuntu/Debian only. No AI CLI integration. Development largely inactive.

#### done (fish plugin)

[done](https://github.com/franciscolourenco/done) is a fish shell plugin with auto-notify, focus detection, and a configurable threshold. It integrates seamlessly with the fish event system and works on macOS and Linux.

**Strengths:** Tight fish integration. Focus detection. Clean, minimal design.

**Considerations:** Fish shell only. Desktop notifications only. No external channels, sound, TTS, AI CLI integration, or notification controls.

#### Verdict

Each tool has its place. **undistract-me** is a one-line apt install for Ubuntu users who want simplicity. **done** is the natural choice for fish shell users. **noti** is a mature single-binary wrapper.

But if you want a tool that does it all — auto-notify, external channels, AI CLI hooks, sound, TTS, notification controls, and cross-platform support with zero dependencies — **shelldone** is the clear winner. It covers every feature the other three offer and adds capabilities none of them have.

For teams on Slack or Discord, the external channel support alone justifies adoption. For developers using AI coding assistants, the native hook system is unique. And the fact that it is pure bash with 374 tests means you can read and trust every line.

**Recommendation:** Start with shelldone. Two minutes to install, works out of the box, and scales up to Slack/Discord/Telegram when you need it.

---

## 6. Product Hunt Listing Draft

**Tagline** (55 chars):

```
Terminal notifications for devs. Slack, AI hooks, more.
```

**Description** (256 chars):

```
shelldone alerts you when terminal commands finish. Desktop popups, sound, Slack, Discord, Telegram, Email, WhatsApp. Auto-notify for long-running tasks. Hooks for AI CLIs (Claude Code, Codex, Gemini). Pure bash, zero deps, cross-platform. MIT licensed.
```

**Topics:**

```
Developer Tools, Open Source, Productivity, CLI, DevOps
```

**Maker Comment:**

```
Hi Product Hunt! I'm Naresh, and I built shelldone because I was tired of
babysitting terminal commands.

The problem is universal: you run a build, a deploy, or a test suite, switch to
something else, and then forget to check back. The command finished three minutes
ago. Or it failed, and you didn't know.

I tried existing tools. undistract-me works on Ubuntu but is desktop-only.
noti requires you to remember to prefix every command. Neither supports
Slack, Discord, or the AI coding assistants I use daily.

So I built shelldone. It is a pure bash notification system that works on macOS,
Linux, WSL, and Windows. The killer features:

- Auto-notify: no wrapper needed. Any command exceeding a threshold triggers a
  notification automatically.
- 6 external channels: Slack, Discord, Telegram, Email, WhatsApp, and webhooks.
  Walk away from your laptop and still get pinged.
- AI CLI hooks: Claude Code, Codex, Gemini, Copilot, and Cursor. When an AI
  agent finishes its task, you know immediately.
- Zero dependencies. Pure bash. No Go, no Python, no Node. Just shell scripts
  and the tools already on your system.

It has 374 tests and CI on macOS and Linux. It is MIT licensed and fully open
source.

I would love your feedback. What channels would you add? What integrations
matter to your workflow? Let me know in the comments.
```

---

## 7. AlternativeTo Listing Draft

**Description:**

```
shelldone is a cross-platform terminal notification system that alerts you when
long-running commands finish. It works on macOS, Linux, WSL, and Windows (Git Bash)
with bash and zsh. shelldone sends desktop popups, plays sounds, speaks results
aloud via TTS, and delivers notifications to six external channels — so you never
have to babysit a terminal again.
```

**Key Features:**

```
- Auto-notify for commands exceeding a configurable time threshold (no wrapper needed)
- Desktop notifications on macOS, Linux, WSL, and Windows
- Sound alerts with customizable success/failure sounds
- Text-to-speech (TTS) announcements
- Slack notifications via incoming webhooks
- Discord notifications via webhooks
- Telegram notifications via Bot API
- Email notifications via sendmail/mail
- WhatsApp notifications via Twilio API
- Generic webhook support for custom integrations
- AI CLI integration: hooks for Claude Code, Codex, Gemini, Copilot, and Cursor
- Smart focus detection (suppresses alerts when you are looking at the terminal)
- Mute with timed duration, per-layer toggle, quiet hours schedule
- Glob-based command exclusion patterns
- Pure bash with zero runtime dependencies
- 374 tests with CI on macOS and Linux
- MIT licensed, open source
```

**Tags:**

```
Terminal, Notifications, CLI, Bash, Shell, Developer Tools, Productivity,
Slack, Discord, Telegram, macOS, Linux, Windows, WSL, Open Source,
DevOps, AI, Cross-Platform, Command Line
```

**Alternative To:**

```
noti, undistract-me, done (fish plugin), ntfy, pushover-cli
```
