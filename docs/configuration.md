# Configuration

All settings are environment variables. Set them before the `eval` line in your shell config:

```bash
# Example .zshrc
export SHELLDONE_THRESHOLD=60
export SHELLDONE_SOUND_SUCCESS=Ping
export SHELLDONE_VOICE=true
eval "$(shelldone init zsh)"
```

Or persist them in the config file: `~/.config/shelldone/config`

```bash
shelldone config edit    # open in $EDITOR
shelldone config init    # print a template
```

## General Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_ENABLED` | `true` | Master on/off switch |
| `SHELLDONE_AUTO` | `true` | Auto-notify on/off |
| `SHELLDONE_THRESHOLD` | `10` | Seconds before auto-notify triggers |
| `SHELLDONE_DEBUG` | *(off)* | Set to `true` for debug output to stderr |

## Sound Settings

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

## Focus & Exclusion Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_FOCUS_DETECT` | `true` | Suppress notifications when terminal is focused |
| `SHELLDONE_TERMINALS` | `Terminal iTerm2 Alacritty kitty WezTerm Hyper` | Terminal app names for focus detection (macOS) |
| `SHELLDONE_EXCLUDE` | `vim nvim vi nano less more man top htop ssh tmux screen fg bg watch` | Space-separated commands/globs to skip |
| `SHELLDONE_NESTED_SHELL` | `notify` | Set to `suppress` to disable auto-notify in nested shells (`SHLVL > 1`). Prevents duplicate alerts from subshells spawned by coding tools, IDEs, etc. Top-level shells, tmux panes, and new terminal tabs are unaffected. |

## Notification Control Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_QUIET_HOURS` | *(off)* | Daily quiet hours (e.g., `22:00-08:00`, crosses midnight OK) |
| `SHELLDONE_HISTORY` | `true` | Log notifications to history file |

## External Notification Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_RATE_LIMIT` | `10` | Min seconds between notifications per channel |
| `SHELLDONE_WEBHOOK_TIMEOUT` | `5` | HTTP timeout in seconds |
| `SHELLDONE_EXTERNAL_DEBUG` | `false` | Log external notification attempts to stderr |

For channel-specific variables (Slack webhook URLs, Telegram tokens, etc.), see [External Channels](external-channels.md).

## Config File

Location: `${SHELLDONE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/shelldone/config}`

The config file is sourced as bash. Use `export` or `: "${VAR:=value}"` syntax:

```bash
# ~/.config/shelldone/config
export SHELLDONE_THRESHOLD=30
export SHELLDONE_SOUND_SUCCESS=Ping
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

## Configuration Hierarchy

```
Priority (highest to lowest):

  1. Environment variables (set before eval in shell RC)
  2. Config file (~/.config/shelldone/config)
  3. Hardcoded defaults (in shelldone.sh)
```

Environment variables always win. The config file is sourced before defaults are applied, so any value set there takes effect unless overridden by an explicit `export` in the shell.
