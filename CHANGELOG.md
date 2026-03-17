# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-17

### Changed

- **BREAKING**: Rebranded from `cli-alert` to `shelldone`
- Command name changed: `cli-alert` → `shelldone`
- All environment variables renamed: `CLI_ALERT_*` → `SHELLDONE_*`
- Config directory moved: `~/.config/cli-alert/` → `~/.config/shelldone/`
- State directory moved: `~/.local/state/cli-alert/` → `~/.local/state/shelldone/`
- History directory moved: `~/.local/share/cli-alert/` → `~/.local/share/shelldone/`
- Shell function prefix changed: `_cli_alert_*` → `_shelldone_*`

### Added

- Backward compatibility shim: auto-migrates `CLI_ALERT_*` env vars to `SHELLDONE_*` with warnings
- `shelldone setup` detects and replaces old `# >>> cli-alert >>>` blocks in shell rc files
- `shelldone uninstall` also cleans up old `# >>> cli-alert >>>` blocks
- Config directory migration from `~/.config/cli-alert/` to `~/.config/shelldone/`

## [0.2.0] - 2026-03-16

### Added

- Multi-AI CLI hook support: Codex CLI, Gemini CLI, GitHub Copilot CLI, Cursor
- Per-AI toggle system (`shelldone toggle claude off`, `shelldone toggle codex off`, etc.)
- Auto-detect and install all AI hooks (`shelldone setup ai-hooks`)
- Shared hook library (`lib/ai-hook-common.sh`) with JSON extraction and toggle-aware notification
- Individual setup commands: `shelldone setup codex-hook`, `gemini-hook`, `copilot-hook`, `cursor-hook`
- AI CLI hooks section in `shelldone status` and `shelldone toggle` output
- Aider detection with wrapper guidance in status output
- Uninstall now removes all AI CLI hooks (Claude, Codex, Gemini, Copilot, Cursor)
- ~40 new tests covering AI hook library, hook scripts, setup CLI, toggle, and status

### Changed

- `shelldone setup` (and `shelldone setup all`) now installs hooks for all detected AI CLIs, not just Claude
- Shell completions expanded with new setup and toggle options
- Homebrew formula installs all hook scripts and shared library
- Makefile installs new hook scripts and `ai-hook-common.sh`

## [0.1.0] - 2026-03-15

### Added

- Cross-platform desktop notifications (macOS, Linux, WSL, Windows via Git Bash/MSYS2/Cygwin)
- `alert <command>` wrapper with exit code preservation
- Auto-notify via shell hooks (zsh preexec/precmd, bash DEBUG trap) for commands exceeding configurable threshold
- Sound alerts with per-platform defaults and custom file path support
- Text-to-speech announcements (macOS `say`, Linux `espeak`/`spd-say`, Windows `powershell.exe`)
- Smart focus detection to suppress notifications when the terminal is in the foreground
- Glob-based command exclusion patterns
- External notification channels: Slack, Discord, Telegram, Email, WhatsApp, generic webhook
- Per-channel rate limiting with configurable interval
- HTTP transport auto-detection (`curl` > `wget` > `/dev/tcp` fallback for plain HTTP)
- Claude Code Stop hook integration (`hooks/claude-done.sh`)
- Mute / unmute with optional duration (e.g., `30m`, `2h`)
- Per-layer toggle (desktop, sound, voice, individual channels, `external` group)
- Daily quiet-hours schedule with cross-midnight support
- Notification history logging
- `shelldone status` diagnostic command
- `shelldone webhook status` and `shelldone webhook test <channel>` commands
- Shell completions for bash and zsh
- `install.sh` interactive installer with platform detection
- `uninstall.sh` and marker-based RC file cleanup
- `Makefile` with install/uninstall/test targets
- Homebrew formula (`Formula/shelldone.rb`)
- Debian packaging (`debian/`)
- Scoop manifest (`packaging/scoop.json`)
- Chocolatey manifest (`packaging/chocolatey.nuspec`)
- GitHub Actions CI: ShellCheck, macOS (bash + zsh), Linux, install round-trip
- Comprehensive test suite (291 tests)

[1.0.0]: https://github.com/nareshnavinash/shelldone/releases/tag/v1.0.0
[0.2.0]: https://github.com/nareshnavinash/shelldone/releases/tag/v0.2.0
[0.1.0]: https://github.com/nareshnavinash/shelldone/releases/tag/v0.1.0
