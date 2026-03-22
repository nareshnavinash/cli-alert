# shelldone

Cross-platform terminal notification system for long-running commands. Get desktop notifications, sounds, and external alerts (Slack, Discord, Telegram, and more) when your builds, deploys, and tests finish.

> Works with bash and zsh on macOS, Linux, WSL, and Windows. Notify via desktop popup, sound, voice, Slack, Discord, Telegram, Email, WhatsApp, or webhook. Integrates with AI CLIs: Claude Code, Codex, Gemini, Copilot, Cursor, and Aider.

[![CI](https://github.com/nareshnavinash/shelldone/actions/workflows/ci.yml/badge.svg)](https://github.com/nareshnavinash/shelldone/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.4.0-green.svg)](VERSION)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20WSL%20%7C%20Windows-lightgrey.svg)](#platform-support)
[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-89e051.svg)](#installation)
[![Tests](https://img.shields.io/badge/tests-452%20passing-brightgreen.svg)](#testing)
[![GitHub stars](https://img.shields.io/github/stars/nareshnavinash/shelldone?style=flat&color=green)](https://github.com/nareshnavinash/shelldone/stargazers)

![shelldone demo](assets/demo.gif)

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [External Notifications](#external-notifications)
- [Commands Reference](#commands-reference)
- [Platform Support](#platform-support)
- [Alternatives](#alternatives)
- [Contributing](#contributing)
- [License](#license)

## Documentation

| Document | Description |
|---|---|
| [Commands Reference](docs/commands.md) | Every CLI command with detailed ASCII flowcharts |
| [Architecture](docs/architecture.md) | System design, notification flow, module loading, state management |
| [External Channels](docs/external-channels.md) | Setup guides for Slack, Discord, Telegram, Email, WhatsApp, webhooks |
| [Configuration](docs/configuration.md) | Full environment variable reference and config file format |
| [Troubleshooting](docs/troubleshooting.md) | Debug mode, common issues, and fixes |

## Features

- **Desktop notifications** on macOS, Linux, WSL, and Windows (Git Bash/MSYS2/Cygwin)
- **Auto-notify** for any command that runs longer than a configurable threshold (default: 10s)
- **Sound alerts** with customizable success/failure sounds (system sounds or custom file paths)
- **Text-to-speech** announcements (optional)
- **External notifications** via Slack, Discord, Telegram, Email, WhatsApp, or generic webhooks
- **AI CLI integration** - Claude Code, Codex CLI, Gemini CLI, Copilot CLI, Cursor (hook-based), plus Aider (wrapper)
- **Smart focus detection** - suppresses notifications when you're already looking at the terminal
- **Glob-based exclusions** - skip commands like `npm*`, `ssh`, `vim`, etc.
- **Notification control** - mute, toggle layers (sound/desktop/voice/channels), schedule quiet hours
- **Shell completions** for bash and zsh
- **Zero dependencies** - uses only built-in system tools (`curl`/`wget` optional for external channels)

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

After installation, commands running longer than 10 seconds automatically trigger notifications - no wrapper needed.

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

Coming soon - submitted for review.

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

### Setup

Run the interactive setup wizard to configure everything at once:

```bash
shelldone setup              # interactive wizard (auto-detects shell, configures RC files, installs AI hooks)
shelldone setup --full       # advanced mode (also configures notification preferences and external channels)
shelldone setup --quick      # non-interactive (shell init + AI hooks, sensible defaults)
```

The wizard walks through:
1. **Shell integration** - detects `.zshrc`/`.bashrc` and adds the `eval` block
2. **Notification preferences** (advanced) - threshold, filter, voice, focus detection
3. **External channels** (advanced) - add/test Slack, Discord, Telegram, etc.
4. **AI CLI hooks** - detects installed AI CLIs and installs hooks
5. **Health check** - verifies everything is working

You can also set up individual components:

```bash
shelldone setup ai-hooks      # install hooks for all detected AI CLIs
shelldone setup claude-hook   # Claude Code only
shelldone setup codex-hook    # Codex CLI only
shelldone setup gemini-hook   # Gemini CLI only
shelldone setup copilot-hook  # Copilot CLI only
shelldone setup cursor-hook   # Cursor only
```

### `alert <command>` - Explicit Notifications

Wrap any command to get notified when it completes:

```bash
alert make build
alert npm test
alert ./deploy.sh production
```

The notification shows the command name, exit status icon, elapsed time, and exit code. The original exit code is preserved.

### Automatic Notifications

After shell integration, any command running longer than the threshold (default: 10 seconds) triggers a notification automatically. No `alert` wrapper needed.

```bash
make build-all    # takes 5 minutes -> notification fires
ls                # instant -> no notification
vim file.txt      # excluded by default -> no notification
```

### AI CLI Integration

shelldone can notify you when AI coding assistants finish their turn via native hook systems:

```bash
shelldone setup ai-hooks          # install hooks for all detected AI CLIs
shelldone setup claude-hook       # or install individually
shelldone toggle claude off       # toggle per AI CLI
```

Supports Claude Code, Codex CLI, Gemini CLI, Copilot CLI, and Cursor. Aider uses the `alert` wrapper: `alert aider "fix the bug"`.

### Notification Control

```bash
shelldone mute 30m               # mute for 30 minutes
shelldone unmute                  # resume
shelldone toggle sound off        # disable sound, keep desktop popups
shelldone toggle external off     # disable all external channels
shelldone schedule 22:00-08:00    # set quiet hours
```

Supported layers: `desktop`, `sound`, `voice`, `slack`, `discord`, `telegram`, `email`, `whatsapp`, `webhook`, `external` (group), `claude`, `codex`, `gemini`, `copilot`, `cursor`.

## Configuration

All settings are environment variables. Set them before the `eval` line in your shell config:

```bash
export SHELLDONE_THRESHOLD=60
export SHELLDONE_SOUND_SUCCESS=Ping
export SHELLDONE_VOICE=true
eval "$(shelldone init zsh)"
```

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_ENABLED` | `true` | Master on/off switch |
| `SHELLDONE_AUTO` | `true` | Auto-notify on/off |
| `SHELLDONE_THRESHOLD` | `10` | Seconds before auto-notify triggers |
| `SHELLDONE_SOUND_SUCCESS` | `Glass` / `complete` / `Asterisk` | Success sound (macOS / Linux / Windows) |
| `SHELLDONE_SOUND_FAILURE` | `Sosumi` / `dialog-error` / `Hand` | Failure sound (macOS / Linux / Windows) |
| `SHELLDONE_VOICE` | *(off)* | Set to `true` for TTS |
| `SHELLDONE_FOCUS_DETECT` | `true` | Suppress when terminal is focused |
| `SHELLDONE_EXCLUDE` | `vim nvim vi nano less ...` | Space-separated commands/globs to skip |
| `SHELLDONE_QUIET_HOURS` | *(off)* | Daily quiet hours (e.g., `22:00-08:00`) |

Full reference with all variables: **[docs/configuration.md](docs/configuration.md)**

## External Notifications

Send alerts to Slack, Discord, Telegram, Email, WhatsApp, or any webhook. External notifications fire even when the terminal is focused.

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
shelldone webhook test slack     # verify it works
```

Setup guides for all 6 channels: **[docs/external-channels.md](docs/external-channels.md)**

## Commands Reference

| Command | Description |
|---|---|
| `shelldone init [bash\|zsh]` | Output shell init code (use with `eval`) |
| `shelldone setup [all\|ai-hooks\|<ai>-hook]` | Auto-configure rc files and/or AI CLI hooks |
| `shelldone uninstall` | Remove all shell integration and AI CLI hooks |
| `shelldone status` | Show diagnostic info: platform, tools, config, integration |
| `shelldone test-notify` | Send a test notification to all configured channels |
| `shelldone sounds` | List available system sounds for your platform |
| `shelldone exclude [list\|add\|remove]` | Manage auto-notify exclusion list |
| `shelldone webhook [status\|test <channel>]` | Manage and test external notification channels |
| `shelldone mute [duration]` | Mute all notifications (e.g., `30m`, `2h`, `1h30m`) |
| `shelldone unmute` | Resume notifications |
| `shelldone toggle [layer [on\|off]]` | Toggle notification layers (sound, desktop, voice, channels) |
| `shelldone schedule [HH:MM-HH:MM\|off]` | Set or clear daily quiet hours |
| `shelldone test` | Run the full verification test suite (452 tests) |
| `shelldone version [--verbose]` | Show version (add `--verbose` for platform details) |
| `shelldone help` | Show usage help |

Detailed flowcharts for every command: **[docs/commands.md](docs/commands.md)**

## Platform Support

| Feature | macOS | Linux | WSL | Windows (Git Bash) |
|---|---|---|---|---|
| Desktop notifications | osascript | notify-send | BurntToast / WinRT | BurntToast / WinRT |
| Sound | afplay | paplay / aplay / mpv | powershell.exe | powershell.exe |
| TTS | say | espeak / spd-say | powershell.exe | powershell.exe |
| Focus detection | AppleScript | xdotool | -- | -- |
| Auto-notify | zsh + bash | zsh + bash | zsh + bash | bash |
| External notifications | All channels | All channels | All channels | All channels |

**macOS:** No additional dependencies (osascript, afplay, say are built-in).
**Linux:** `libnotify-bin` for desktop, `pulseaudio-utils`/`alsa-utils` for sound, `espeak` for TTS, `xdotool` for focus.
**WSL/Windows:** [BurntToast](https://github.com/Windos/BurntToast) PowerShell module (recommended) or `wsl-notify-send`.
**External channels:** `curl` or `wget` for HTTPS channels.

> **Tested on macOS** with bash and zsh, extensively validated with Claude Code, Gemini CLI, and Codex CLI. Slack is the only external channel tested end-to-end; other channels (Discord, Telegram, Email, WhatsApp, webhook) follow the same HTTP dispatch pattern and should work correctly. Since bash and zsh behave consistently across operating systems, shelldone should work identically on Linux, WSL, and Windows. It's [MIT licensed](LICENSE) - fork it, fix it, and send a PR.

## Uninstalling

```bash
shelldone uninstall     # interactive confirmation
./uninstall.sh          # or run the uninstall script
make uninstall          # or via make
```

## Troubleshooting

Run `shelldone status` for quick diagnosis. For debug output: `SHELLDONE_DEBUG=true alert echo hello`.

Full troubleshooting guide: **[docs/troubleshooting.md](docs/troubleshooting.md)**

## Testing

shelldone includes 452 tests covering unit, integration, and end-to-end scenarios.

```bash
bash test.sh          # from project root
shelldone test        # via the CLI
```

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

> *"I'm not needy. I simply believe every completed process deserves recognition."* -- shelldone

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run the test suite: `bash test.sh` (all 452 tests must pass)
5. Run ShellCheck: `shellcheck bin/shelldone lib/*.sh hooks/*.sh`
6. Commit and push
7. Open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## License

MIT License. Copyright (c) 2026 Naresh Sekar. See [LICENSE](LICENSE) for details.
