# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- `cli-alert status` diagnostic command
- `cli-alert webhook status` and `cli-alert webhook test <channel>` commands
- Shell completions for bash and zsh
- `install.sh` interactive installer with platform detection
- `uninstall.sh` and marker-based RC file cleanup
- `Makefile` with install/uninstall/test targets
- Homebrew formula (`Formula/cli-alert.rb`)
- Debian packaging (`debian/`)
- Scoop manifest (`packaging/scoop.json`)
- Chocolatey manifest (`packaging/chocolatey.nuspec`)
- GitHub Actions CI: ShellCheck, macOS (bash + zsh), Linux, install round-trip
- Comprehensive test suite (291 tests)

[0.1.0]: https://github.com/nareshnavinash/cli-alert/releases/tag/v0.1.0
