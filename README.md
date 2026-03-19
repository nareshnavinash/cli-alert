# shelldone

Cross-platform terminal notification system for long-running commands. Get desktop notifications, sounds, and external alerts (Slack, Discord, Telegram, and more) when your builds, deploys, and tests finish.

> Works with bash and zsh on macOS, Linux, WSL, and Windows. Notify via desktop popup, sound, voice, Slack, Discord, Telegram, Email, WhatsApp, or webhook. Integrates with AI CLIs: Claude Code, Codex, Gemini, Copilot, Cursor, and Aider.

[![CI](https://github.com/nareshnavinash/shelldone/actions/workflows/ci.yml/badge.svg)](https://github.com/nareshnavinash/shelldone/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.3.1-green.svg)](VERSION)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20Windows-lightgrey.svg)](#platform-support)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-89e051.svg)](#installation)
[![Tests](https://img.shields.io/badge/tests-438%20passing-brightgreen.svg)](#testing)

![shelldone demo](assets/demo.gif)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [External Notifications](#external-notifications)
- [Commands Reference](#commands-reference)
- [Architecture](#architecture)
- [Platform Support](#platform-support)
- [Troubleshooting](#troubleshooting)
- [Testing](#testing)
- [Alternatives](#alternatives)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Desktop notifications** on macOS, Linux, WSL, and Windows (Git Bash/MSYS2/Cygwin)
- **Auto-notify** for any command that runs longer than a configurable threshold (default: 10s)
- **Sound alerts** with customizable success/failure sounds (system sounds or custom file paths)
- **Text-to-speech** announcements (optional)
- **External notifications** via Slack, Discord, Telegram, Email, WhatsApp, or generic webhooks
- **AI CLI integration** — Claude Code, Codex CLI, Gemini CLI, Copilot CLI, Cursor (hook-based), plus Aider (wrapper)
- **Smart focus detection** — suppresses notifications when you're already looking at the terminal
- **Glob-based exclusions** — skip commands like `npm*`, `ssh`, `vim`, etc.
- **Notification control** — mute, toggle layers (sound/desktop/voice/channels), schedule quiet hours
- **Shell completions** for bash and zsh
- **Zero dependencies** — uses only built-in system tools (`curl`/`wget` optional for external channels)

## Quick Start

```bash
# Clone and install
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
./install.sh

# Verify your setup
shelldone status

# Send a test notification
shelldone test-notify

# Wrap any command
alert make build
```

After installation, commands running longer than 10 seconds automatically trigger notifications — no wrapper needed.

## Installation

### From Source (recommended)

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
./install.sh
```

The install script detects your platform, makes scripts executable, adds shell integration to your rc files, and sets up hooks for all detected AI CLIs.

### Make Install

```bash
make install                     # installs to /usr/local
make install PREFIX=~/.local     # installs to ~/.local
```

### Homebrew (macOS/Linux)

```bash
brew tap nareshnavinash/tap
brew install shelldone
```

### Debian/Ubuntu

```bash
# Add the GPG key and repository
curl -fsSL https://nareshnavinash.github.io/shelldone/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/shelldone-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/shelldone-archive-keyring.gpg] https://nareshnavinash.github.io/shelldone stable main" \
  | sudo tee /etc/apt/sources.list.d/shelldone.list
sudo apt update && sudo apt install shelldone
```

### Scoop (Windows)

```bash
scoop bucket add shelldone https://github.com/nareshnavinash/scoop-bucket
scoop install shelldone
```

### Chocolatey (Windows)

```bash
choco install shelldone
```

### Manual Setup

Add to your `.zshrc` or `.bashrc`:

```bash
eval "$(shelldone init zsh)"    # for zsh
eval "$(shelldone init bash)"   # for bash
```

Or auto-configure everything (rc files + AI CLI hooks):

```bash
shelldone setup
```

## Usage

### `alert <command>` — Explicit Notifications

Wrap any command to get notified when it completes:

```bash
alert make build
alert npm test
alert ./deploy.sh production
alert docker compose up --build
```

The notification shows the command name, exit status icon, elapsed time, and exit code. The original exit code is preserved:

```bash
alert false
echo $?   # prints 1
```

### Automatic Notifications

After shell integration, any command running longer than the threshold (default: 10 seconds) triggers a notification automatically. No `alert` wrapper needed.

```bash
# Just run your command normally
make build-all    # takes 5 minutes -> notification fires
npm install       # takes 2 minutes -> notification fires
ls                # instant -> no notification
vim file.txt      # excluded by default -> no notification
```

Auto-notify uses `preexec`/`precmd` hooks in zsh and `DEBUG` trap + `PROMPT_COMMAND` in bash.

### AI CLI Integration

shelldone can notify you when AI coding assistants finish their turn. It supports Claude Code, Codex CLI, Gemini CLI, GitHub Copilot CLI, and Cursor via native hook systems, plus Aider via the `alert` wrapper.

```bash
# Install hooks for all detected AI CLIs
shelldone setup ai-hooks

# Or install individually
shelldone setup claude-hook     # Claude Code (~/.claude/settings.json)
shelldone setup codex-hook      # Codex CLI (~/.codex/config.json)
shelldone setup gemini-hook     # Gemini CLI (~/.gemini/settings.json)
shelldone setup copilot-hook    # Copilot CLI (~/.github/hooks/)
shelldone setup cursor-hook     # Cursor (~/.cursor/hooks.json)
```

Each hook script reads a JSON event from stdin, extracts the relevant metadata, and triggers a notification. You can toggle notifications per AI CLI:

```bash
shelldone toggle claude off     # disable Claude notifications
shelldone toggle codex on       # re-enable Codex notifications
```

#### Aider

Aider does not support native hooks. Use the `alert` wrapper instead:

```bash
alert aider "fix the login bug"
```

### Exclusion Patterns

Commands matching exclusion patterns are silently skipped by auto-notify. Patterns support shell globs:

```bash
export SHELLDONE_EXCLUDE="vim nvim ssh npm* docker*"
```

Manage exclusions interactively:

```bash
shelldone exclude list            # show current exclusions
shelldone exclude add docker      # prints export line to add
shelldone exclude remove vim      # prints updated export line
```

Default exclusions: `vim nvim vi nano less more man top htop ssh tmux screen fg bg watch`

### Notification Control

Temporarily mute, toggle notification layers, or schedule quiet hours:

```bash
# Mute all notifications
shelldone mute           # indefinitely
shelldone mute 30m       # for 30 minutes
shelldone mute 2h        # for 2 hours
shelldone unmute          # resume

# Toggle individual layers
shelldone toggle sound off      # disable sound, keep desktop popups
shelldone toggle voice off      # disable TTS
shelldone toggle slack off      # disable Slack channel
shelldone toggle external off   # disable all external channels
shelldone toggle                # show all toggle states

# Schedule daily quiet hours (crosses midnight OK)
shelldone schedule 22:00-08:00
shelldone schedule off          # clear schedule
```

Supported layers: `desktop`, `sound`, `voice`, `slack`, `discord`, `telegram`, `email`, `whatsapp`, `webhook`, `external` (group toggle), `claude`, `codex`, `gemini`, `copilot`, `cursor` (AI CLIs).

Quiet hours can also be set via environment variable:

```bash
export SHELLDONE_QUIET_HOURS="22:00-08:00"
```

When muted or in quiet hours, notifications are suppressed but still logged to history.

## Configuration

All settings are environment variables. Set them before the `eval` line in your shell config:

```bash
# Example .zshrc
export SHELLDONE_THRESHOLD=60
export SHELLDONE_SOUND_SUCCESS=Ping
export SHELLDONE_VOICE=true
eval "$(shelldone init zsh)"
```

### General Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_ENABLED` | `true` | Master on/off switch |
| `SHELLDONE_AUTO` | `true` | Auto-notify on/off |
| `SHELLDONE_THRESHOLD` | `10` | Seconds before auto-notify triggers |
| `SHELLDONE_DEBUG` | *(off)* | Set to `true` for debug output to stderr |

### Sound Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_SOUND_SUCCESS` | `Glass` (macOS), `complete` (Linux), `Asterisk` (Windows) | Success sound name or file path |
| `SHELLDONE_SOUND_FAILURE` | `Sosumi` (macOS), `dialog-error` (Linux), `Hand` (Windows) | Failure sound name or file path |
| `SHELLDONE_SOUND_TIMEOUT` | `10` | Max seconds to wait for sound playback |
| `SHELLDONE_VOICE` | *(off)* | Set to `true` for TTS announcements |

Use a system sound name or a file path:

```bash
export SHELLDONE_SOUND_SUCCESS=Ping
export SHELLDONE_SOUND_FAILURE=/path/to/custom/error.aiff
```

List available sounds: `shelldone sounds`

### Focus & Exclusion Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_FOCUS_DETECT` | `true` | Suppress notifications when terminal is focused |
| `SHELLDONE_TERMINALS` | `Terminal iTerm2 Alacritty kitty WezTerm Hyper` | Terminal app names for focus detection (macOS) |
| `SHELLDONE_EXCLUDE` | `vim nvim vi nano less more man top htop ssh tmux screen fg bg watch` | Space-separated commands/globs to skip |

### Notification Control Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_QUIET_HOURS` | *(off)* | Daily quiet hours (e.g., `22:00-08:00`, crosses midnight OK) |
| `SHELLDONE_HISTORY` | `true` | Log notifications to history file |

## External Notifications

Get notified on Slack, Discord, Telegram, email, WhatsApp, or any webhook endpoint. External notifications fire even when the terminal is focused — ideal for monitoring from your phone or another device.

### Slack

1. Go to [api.slack.com/apps](https://api.slack.com/apps) > Create New App > From scratch
2. Enable **Incoming Webhooks** > Activate > **Add New Webhook to Workspace**
3. Select a channel and copy the webhook URL

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

Optional:

```bash
export SHELLDONE_SLACK_USERNAME="my-bot"     # default: shelldone
export SHELLDONE_SLACK_CHANNEL="#alerts"      # override channel
```

### Discord

1. Open Server Settings > Integrations > Webhooks > **New Webhook**
2. Select a channel, copy the webhook URL

```bash
export SHELLDONE_DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
```

Optional:

```bash
export SHELLDONE_DISCORD_USERNAME="my-bot"   # default: shelldone
```

### Telegram

1. Message [@BotFather](https://t.me/BotFather) > `/newbot` > copy the bot token
2. Send a message to your bot, then get your chat ID:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1
   ```

```bash
export SHELLDONE_TELEGRAM_TOKEN="123456:ABC-DEF..."
export SHELLDONE_TELEGRAM_CHAT_ID="your-chat-id"
```

### Email

Requires `sendmail` or `mail` command on the system.

```bash
export SHELLDONE_EMAIL_TO="you@example.com"
```

Optional:

```bash
export SHELLDONE_EMAIL_FROM="alerts@myhost.com"        # default: shelldone@<hostname>
export SHELLDONE_EMAIL_SUBJECT="[deploy] finished"     # default: [shelldone] <title>
```

### WhatsApp (via Twilio)

```bash
export SHELLDONE_WHATSAPP_API_URL="https://api.twilio.com/2010-04-01/Accounts/.../Messages.json"
export SHELLDONE_WHATSAPP_TOKEN="base64-encoded-sid:token"
export SHELLDONE_WHATSAPP_FROM="+14155238886"
export SHELLDONE_WHATSAPP_TO="+1234567890"
```

All four variables are required.

### Generic Webhook

```bash
export SHELLDONE_WEBHOOK_URL="https://your-endpoint.com/hook"
export SHELLDONE_WEBHOOK_HEADERS="Authorization: Bearer token123|X-Custom: value"  # optional, pipe-separated
```

The webhook receives a JSON payload:

```json
{
  "title": "make Complete",
  "message": "✓ make build (2m 15s, exit 0)",
  "exit_code": 0
}
```

### Persisting Channel Configuration (Important for AI CLI Hooks)

AI CLI hooks (Claude Code, Codex, Gemini, Copilot, Cursor) run as **separate processes** spawned by the AI tool — they do **not** inherit your shell's environment variables. If you only set a webhook via `export` in your terminal, `shelldone webhook test slack` will work from that shell, but hooks triggered by AI CLIs will not have the variable.

There are two ways to ensure hooks can access your channel configuration:

**Option 1: Config file (recommended)**

Add your webhook URLs to `~/.config/shelldone/config`. Hooks read this file on every invocation, regardless of environment:

```bash
shelldone config edit
# Uncomment and fill in the relevant lines:
# export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

**Option 2: Shell profile**

Add the `export` to your `.zshrc` or `.bashrc` **before** starting the AI CLI. The AI tool inherits the variable at launch and passes it to hooks:

```bash
# In .zshrc or .bashrc (BEFORE eval "$(shelldone init zsh)")
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

> **Why `export` alone doesn't work:** `export` sets a variable in the current shell and its future children. It cannot update already-running processes. If you export a webhook URL after starting Claude Code, Claude Code's process (and its hooks) won't see it. You'd need to restart the AI CLI for it to pick up the new variable.

### External Notification Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_RATE_LIMIT` | `10` | Min seconds between notifications per channel |
| `SHELLDONE_WEBHOOK_TIMEOUT` | `5` | HTTP timeout in seconds |
| `SHELLDONE_EXTERNAL_DEBUG` | `false` | Log external notification attempts to stderr |

### Testing & Verifying Channels

```bash
shelldone webhook status              # show transport, channels, rate limit
shelldone webhook test slack           # send a test message to Slack
shelldone webhook test discord         # test Discord
shelldone webhook test telegram        # test Telegram
shelldone webhook test email           # test Email
shelldone webhook test whatsapp        # test WhatsApp
shelldone webhook test webhook         # test generic webhook
```

The test command validates all required variables upfront, shows success/failure with the HTTP status code, and is not subject to rate limiting:

```
$ shelldone webhook test slack
Sending test to slack...
[shelldone] Test sent successfully! (HTTP 200)

$ shelldone webhook test slack   # with a bad URL
Sending test to slack...
[shelldone] Test FAILED. (HTTP 403)
[shelldone] Run with SHELLDONE_EXTERNAL_DEBUG=true for details.
```

> **Note:** Slack, Discord, Telegram, and WhatsApp require `curl` or `wget` (HTTPS). The generic webhook can use `/dev/tcp` for plain HTTP endpoints if neither is available.

## Commands Reference

| Command | Description |
|---|---|
| `shelldone init [bash\|zsh]` | Output shell init code (use with `eval`) |
| `shelldone setup [all\|ai-hooks\|<ai>-hook]` | Auto-configure rc files and/or AI CLI hooks |
| `shelldone uninstall` | Remove all shell integration and AI CLI hooks |
| `shelldone status` | Show diagnostic info — platform, tools, config, integration |
| `shelldone test-notify` | Send a test notification (desktop + all configured external channels) |
| `shelldone sounds` | List available system sounds for your platform |
| `shelldone exclude [list\|add\|remove]` | Manage auto-notify exclusion list |
| `shelldone webhook [status\|test <channel>]` | Manage and test external notification channels |
| `shelldone mute [duration]` | Mute all notifications (e.g., `30m`, `2h`, `1h30m`) |
| `shelldone unmute` | Resume notifications |
| `shelldone toggle [layer [on\|off]]` | Toggle notification layers (sound, desktop, voice, channels) |
| `shelldone schedule [HH:MM-HH:MM\|off]` | Set or clear daily quiet hours |
| `shelldone test` | Run the full verification test suite (438 tests) |
| `shelldone version [--verbose]` | Show version (add `--verbose` for platform details) |
| `shelldone help` | Show usage help |

## Architecture

### Project Structure

```
shelldone/
├── bin/shelldone              # Main CLI executable (dispatch + commands)
├── lib/
│   ├── shelldone.sh           # Core notification engine + alert() wrapper
│   ├── auto-notify.zsh        # Zsh preexec/precmd auto-notify hooks
│   ├── auto-notify.bash       # Bash DEBUG trap auto-notify hooks
│   ├── external-notify.sh     # External channels (Slack, Discord, etc.)
│   ├── state.sh               # Mute, toggle, and schedule state management
│   ├── ai-hook-common.sh      # Shared library for AI CLI hooks
│   └── tui.sh                 # Reusable TUI library for interactive menus
├── hooks/
│   ├── claude-done.sh         # Claude Code Stop hook
│   ├── codex-done.sh          # Codex CLI Stop hook
│   ├── gemini-done.sh         # Gemini CLI command hook
│   ├── copilot-done.sh        # Copilot CLI sessionEnd hook
│   └── cursor-done.sh         # Cursor stop hook
├── completions/
│   ├── shelldone.bash         # Bash completion
│   └── shelldone.zsh          # Zsh completion
├── Formula/shelldone.rb       # Homebrew formula
├── debian/                    # Debian packaging
├── packaging/
│   ├── chocolatey.nuspec      # Chocolatey manifest
│   └── scoop.json             # Scoop manifest
├── install.sh                 # Interactive installer
├── uninstall.sh               # Uninstaller
├── test.sh                    # Test suite (438 tests)
├── Makefile                   # make install/uninstall/test
└── VERSION                    # 1.3.1
```

### Design Principles

- **Multi-path resolution** — Works both from source (`./lib/`) and installed (`/usr/lib/shelldone/`, `/usr/local/lib/shelldone/`)
- **Lazy loading** — External notification module loaded at init if a channel env var is set, or on-demand at notification time if configured later
- **Double-source guards** — All lib files check guard variables to prevent re-initialization
- **Marker-based uninstall** — RC file cleanup uses `# >>> shelldone >>>` / `# <<< shelldone <<<` markers
- **Timeout safety** — Background sound/TTS processes have watchdog timers to prevent hangs
- **Pure-bash JSON** — JSON escaping without `jq` dependency
- **Rate limiting** — Per-channel rate limits via shared stamp files in `/tmp/`
- **Fallback chain** — Platform notifier > warning > terminal bell + stderr message

### Notification Flow

```
Command completes
  └─> alert() / auto-notify hook
        └─> _shelldone_notify()
              ├─> Mute / quiet hours check (suppress if active, still logs)
              ├─> External notifications (background, non-blocking)
              │     └─> Slack, Discord, Telegram, Email, WhatsApp, Webhook
              ├─> Focus detection (skip if terminal focused)
              └─> Platform notifier
                    ├─> macOS: osascript + afplay + say
                    ├─> Linux: notify-send + paplay/aplay + espeak
                    ├─> WSL: BurntToast/WinRT + powershell.exe
                    └─> Fallback: terminal bell + stderr
```

## Platform Support

| Feature | macOS | Linux | WSL | Windows (Git Bash) |
|---|---|---|---|---|
| Desktop notifications | osascript | notify-send | BurntToast / WinRT | BurntToast / WinRT |
| Sound | afplay | paplay / aplay / mpv | powershell.exe | powershell.exe |
| TTS | say | espeak / spd-say | powershell.exe | powershell.exe |
| Focus detection | AppleScript | xdotool | -- | -- |
| Auto-notify | zsh + bash | zsh + bash | zsh + bash | bash |
| External notifications | All channels | All channels | All channels | All channels |
| Fallback | terminal bell | terminal bell | terminal bell | terminal bell |

### Platform Dependencies

**macOS:** No additional dependencies (osascript, afplay, say are built-in).

**Linux:**
- Desktop notifications: `libnotify-bin` (`apt install libnotify-bin`)
- Sound: `pulseaudio-utils` (paplay) or `alsa-utils` (aplay)
- TTS: `espeak` or `speech-dispatcher` (spd-say)
- Focus detection: `xdotool`

**WSL/Windows:**
- [BurntToast](https://github.com/Windos/BurntToast) PowerShell module (recommended) or `wsl-notify-send`

**External channels:** `curl` or `wget` for HTTPS channels (Slack, Discord, Telegram, WhatsApp).

## Troubleshooting

### Quick Diagnosis

```bash
shelldone status
```

This shows your platform, available notification tools, current config, shell integration status, Claude Code hook status, and external channel configuration.

### Debug Mode

**Desktop notifications:**

```bash
export SHELLDONE_DEBUG=true
alert echo hello
```

Prints detailed debug output to stderr showing platform detection, notification routing, and sound playback.

**External notifications:**

```bash
export SHELLDONE_EXTERNAL_DEBUG=true
alert echo hello
```

Prints HTTP transport selection, POST targets (URLs redacted), and per-channel success/failure with HTTP status codes.

### Common Issues

**No notification appears:**
- Run `shelldone status` to check notification tools are available
- Run `shelldone test-notify` to send a test notification
- On macOS: check System Settings > Notifications for terminal app permissions
- On Linux: install `libnotify-bin` (`apt install libnotify-bin`)

**No sound plays:**
- Run `shelldone sounds` to see available sounds
- Check that the sound file exists: `ls /System/Library/Sounds/` (macOS)
- Try a custom path: `export SHELLDONE_SOUND_SUCCESS=/path/to/sound.aiff`

**Auto-notify not working:**
- Ensure `SHELLDONE_AUTO=true` (default)
- Check threshold: `SHELLDONE_THRESHOLD=10` means commands must run 10+ seconds
- Check exclusions: `shelldone exclude list`
- Ensure shell integration is loaded: `shelldone status` shows rc file status

**External notifications not arriving:**
- Run `shelldone webhook status` to verify channel config
- Test a specific channel: `shelldone webhook test slack`
- Enable debug output: `export SHELLDONE_EXTERNAL_DEBUG=true`
- Ensure `curl` or `wget` is installed (required for HTTPS channels)
- Check for HTTP errors: test output shows the HTTP status code on failure
- Verify rate limiting isn't blocking: default is 10 seconds between notifications per channel

**External notifications work from shell but not from AI CLI hooks:**
- AI hooks run as separate processes that don't inherit your shell's `export` variables
- Persist your webhook URL in the config file: `shelldone config edit` (uncomment the relevant line)
- Or add the `export` to `.zshrc`/`.bashrc` and **restart the AI CLI** so it inherits the variable
- See [Persisting Channel Configuration](#persisting-channel-configuration-important-for-ai-cli-hooks) for details

**AI CLI hooks not firing:**
- Run `shelldone status` to check hook installation for all AI CLIs
- Re-install a specific hook: `shelldone setup claude-hook` (or `codex-hook`, `gemini-hook`, etc.)
- Re-install all: `shelldone setup ai-hooks`
- Verify the AI CLI's settings file contains the hook entry
- Requires `python3` for installation (hooks use it for JSON parsing)
- Check per-AI toggle: `shelldone toggle` shows if a hook is toggled off

**Focus detection suppressing notifications:**
- Disable: `export SHELLDONE_FOCUS_DETECT=false`
- Or add your terminal to the detection list: `export SHELLDONE_TERMINALS="Terminal iTerm2 Alacritty MyTerminal"`
- Note: focus detection only works on macOS (AppleScript) and Linux (xdotool)

## Testing

shelldone includes a comprehensive test suite with 438 tests covering unit, integration, and end-to-end scenarios.

```bash
# Run from project root
bash test.sh

# Or via the CLI
shelldone test
```

### Test Categories

| Category | Tests | Coverage |
|---|---|---|
| Platform detection | 1 | Platform identification |
| CLI entry point | 5 | Binary, version, help, init |
| Core functions | 7 | Function existence checks |
| Duration formatting | 3 | Seconds, minutes, hours |
| Alert wrapper | 4 | Success, failure, exit code preservation |
| AppleScript sanitization | 3 | Quote/backslash escaping |
| Exit code validation | 3 | Non-numeric, empty, valid |
| Status icon | 4 | UTF-8 and ASCII variants |
| Notification delivery | 1 | Desktop notification send |
| Sound playback | 1 | Sound file existence |
| Claude Code hook | 2 | Script executable, JSON processing |
| AI Hook Common Library | 8 | Source guard, JSON extraction, functions |
| AI Hook Scripts | 12 | Codex, Gemini, Copilot, Cursor: executable, JSON, empty stdin |
| AI Hook Setup CLI | 8 | Setup subcommands, help text |
| AI Hook Setup Append Safety | 8 | Preserves existing hooks, idempotency, non-hook settings |
| AI Hook Toggle | 6 | Per-AI toggle on/off, state persistence |
| AI Hook Status | 4 | Status output includes AI section |
| CLI commands | 8 | status, test-notify, sounds, exclude, version |
| Dynamic title | 1 | alert() title generation |
| Warning function | 2 | Existence, deduplication |
| Focus detection | 2 | Existence, disable flag |
| Glob exclusion | 3 | Exact, glob match, no false positive |
| JSON escaping | 10 | Plain, quotes, backslashes, newlines, tabs, edge cases |
| Rate limiting | 8 | Cycle, no stamp, fresh, expired, skip, independent, custom |
| HTTP transport | 2 | Detection, unknown transport |
| External functions | 1 | All channel functions exist |
| URL redaction | 4 | Path strip, no path, non-HTTP |
| HTTP status capture | 16 | 2xx success, 3xx/4xx/5xx failure, network errors, headers |
| Channel validation | 17 | All channels: missing/present vars, unknown channel |
| Channel error handling | 18 | Success/failure returns, rate limit behavior per channel |
| Channel payloads | 10 | Colors, usernames, headers, JSON escaping, structure |
| Debug output | 3 | Failure messages, success messages, silent mode |
| URL parsing | 4 | HTTPS, HTTP, custom port, invalid scheme |
| CLI webhook test (E2E) | 15 | Validation errors, mock HTTP success/failure, rate limit bypass |
| Background dispatch | 3 | Channel routing, debug stderr, non-debug swallow |
| CLI webhook status (E2E) | 5 | Transport, rate limit, channels, timeout, bad action |

### CI

The project runs CI via GitHub Actions (`.github/workflows/ci.yml`):

1. **ShellCheck** — lints all shell scripts
2. **Test macOS** — runs test suite under both `bash` and `zsh`
3. **Test Linux** — installs dependencies, runs test suite
4. **Test Install** — full install/verify/uninstall roundtrip

## Uninstalling

```bash
# Via the CLI (recommended)
shelldone uninstall

# Or run the uninstall script
./uninstall.sh

# Or via make
make uninstall
```

This removes shell integration from `.zshrc` and `.bashrc`, and removes all AI CLI hooks (Claude, Codex, Gemini, Copilot, Cursor).

## Alternatives

| Feature | shelldone | undistract-me | noti | done (fish) |
|---|---|---|---|---|
| Auto-notify | Yes | Yes | Partial | Yes |
| macOS + Linux + WSL + Windows | Yes | No | Yes | No |
| External channels (6) | Yes | No | Partial | No |
| Zero dependencies | Yes | Yes | No (Go) | Yes |
| AI CLI integration (5 tools) | Yes | No | No | No |
| Sound + TTS | Yes | No | Partial | No |
| Mute / schedule / toggle | Yes | No | No | No |

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run the test suite: `bash test.sh` (all 438 tests must pass)
5. Run ShellCheck: `shellcheck bin/shelldone lib/*.sh hooks/*.sh`
6. Commit and push
7. Open a pull request

### Adding a New External Channel

1. Add the channel function `_shelldone_external_<name>()` in `lib/external-notify.sh`
2. Wrap the HTTP call in `if _shelldone_http_post ...; then ... else ... fi` pattern
3. Add validation to `_shelldone_validate_channel()`
4. Add dispatch line in `_shelldone_notify_external()`
5. Add status display in `cmd_webhook` status block (`bin/shelldone`)
6. Add tests (unit, integration, E2E) in `test.sh`
7. Document in README

## License

MIT License. Copyright (c) 2026 Naresh Sekar. See [LICENSE](LICENSE) for details.
