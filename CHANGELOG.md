# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-03-21

### Added

- `SHELLDONE_NESTED_SHELL=suppress` config - disables auto-notify in nested shells (`SHLVL > 1`), preventing duplicate alerts from subshells spawned by AI coding tools, IDEs, and other wrappers. Top-level shells, tmux panes, and new terminal tabs are unaffected (they reset `SHLVL` to 1).

### Fixed

- **Zsh compatibility**: Fixed 22 failing tests and their underlying library bugs when running under zsh:
  - `_shelldone_warn_once` - replaced bash-only `${!var}` indirect expansion with cross-shell `eval`
  - `_shelldone_json_escape` - fixed `${str:i:1}` substring syntax (`${str:$i:1}`)
  - `_shelldone_redact_url` - added `match[]` fallback for zsh regex captures
  - `_shelldone_parse_duration` - added `match[]`/`MATCH` fallback for zsh regex captures
  - `_shelldone_is_quiet_hours` - added `match[]` fallback for zsh regex captures
  - `auto-notify.zsh` glob exclusion - fixed pattern matching with `$~excluded` for proper glob support
  - `_tui_select` / `_tui_multiselect` - replaced bash-only `${!array[@]}` and 0-indexed `options[$i]` with cross-shell array access
- Test harness now sets `SHELLDONE_CONFIG=/dev/null` to prevent real config (e.g., Slack webhook) from leaking into test runs

## [1.3.1] - 2026-03-18

### Fixed

- Background job notifications no longer leak `[N] PID` / `done` messages in zsh (added `NO_MONITOR`/`NO_NOTIFY` setopt in `_shelldone_bg_timeout` and `_shelldone_notify_external`)

## [1.3.0] - 2026-03-18

### Added

- Interactive TUI for channel setup (`shelldone setup` launches menu-driven interface)
- `lib/tui.sh` - reusable TUI library for building interactive shell menus

### Fixed

- Hook scripts resolve library paths correctly in installed layout (`PREFIX/share/shelldone/hooks/` → `PREFIX/lib/shelldone/`)
- Prompt stdout leak during interactive setup

## [1.1.0] - 2026-03-17

### Added

- Enriched Discord embeds with structured fields (Command, Duration, Exit Code, Project), footer, and ISO 8601 timestamp
- Status emoji prefix (`✅`/`❌`) in Discord embed titles for color-blind accessibility
- Enriched Telegram messages with HTML formatting, structured fields, and context footer
- Enriched email body with key=value metadata (Command, Duration, Exit Code, Project, Host, Directory, Branch, Time)
- WhatsApp context line with project, hostname, and git branch
- Generic webhook payload now includes `hostname`, `command`, `duration`, `project`, `directory`, `git_branch`, `source`, `timestamp`, `success` fields
- AI hook exit code mapping: error stop reasons (`error`, `max_turns_reached`, `context_window_full`, `timeout`) now produce exit code 1 instead of always 0
- `alert-bg` now sets `_SHELLDONE_META_*` variables for enriched channel messages

### Changed

- Auto-notify captures full command with arguments (truncated to 50 chars) instead of just the basename - notification body now shows `✓ make deploy-production (2m 5s, exit 0)` instead of `✓ make (2m 5s, exit 0)`
- `alert-bg` title now includes job name: `Background: PID 1234 Complete` instead of `Background Job Complete`
- `alert-bg` unknown exit code path now passes exit code 2 with `⚠` icon instead of false-green exit code 0
- Duration formatting shows `<1s` instead of `0s` for sub-second commands
- Word-boundary-aware command truncation in `alert` (breaks at last space before limit)
- Timestamp format changed to locale-independent 24-hour format (`%Y-%m-%d %H:%M`)
- Telegram parse mode changed from Markdown to HTML for better formatting support
- Copilot hook message standardized from "Session complete" to "Task complete"

### Fixed

- AI hook error stop reasons no longer show false-green success indicators
- `alert-bg` no longer reports success for unknown exit codes

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
- Comprehensive test suite (374 tests)

[1.4.0]: https://github.com/nareshnavinash/shelldone/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/nareshnavinash/shelldone/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/nareshnavinash/shelldone/compare/v1.2.0...v1.3.0
[1.1.0]: https://github.com/nareshnavinash/shelldone/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/nareshnavinash/shelldone/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/nareshnavinash/shelldone/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nareshnavinash/shelldone/releases/tag/v0.1.0
