# Commands Reference

Usage: `shelldone <command> [args...]`

## init

Output shell init code for eval in your RC file.

```bash
eval "$(shelldone init zsh)"    # for zsh
eval "$(shelldone init bash)"   # for bash
```

```
shelldone init [bash|zsh]
         |
         v
  [Shell specified?]---no---> [Auto-detect from parent PID]
         |yes                        |
         v                           +---> ps -p $PPID
         |                           +---> Fallback: $SHELL
         |<--------------------------+
         v
  [Resolve lib path]
         |
         v
  [Output init code to stdout:]
    export _SHELLDONE_LIB="<path>"
    source "<path>/shelldone.sh"
    source "<path>/auto-notify.<shell>"
```

## setup

Auto-configure shell integration and AI CLI hooks.

```bash
shelldone setup              # interactive wizard (if tty)
shelldone setup --quick      # non-interactive: shell init + AI hooks
shelldone setup --full       # interactive: all phases
shelldone setup ai-hooks     # install hooks for all detected AI CLIs
shelldone setup claude-hook  # install Claude Code hook only
```

```
shelldone setup [mode]
         |
         v
  [Specific AI hook?]---yes---> [_setup_<ai>_hook] ---> done
  (claude-hook, codex-hook, etc.)
         |no
         v
  [ai-hooks?]---yes---> [_setup_ai_hooks: detect + install all] ---> done
         |no
         v
  [--quick or all?]---yes---> [_setup_shell_init + _setup_ai_hooks] ---> done
         |no
         v
  [--full?]---yes---> [_setup_wizard "advanced"]
         |no
         v
  [TTY detected?]---no---> [_setup_shell_init + _setup_ai_hooks] ---> done
         |yes
         v
  [_setup_wizard ""]
         |
         +-- Phase 1: Welcome + mode selection
         |     (quick / advanced / reconfigure)
         |
         +-- Phase 2: Shell integration (skip for reconfigure)
         |     |
         |     +---> Detect .zshrc / .bashrc
         |     +---> Remove old cli-alert markers (migration)
         |     +---> Check if shelldone markers exist
         |     +---> If missing: append eval block between markers
         |
         +-- Phase 3: Preferences (advanced only)
         |     +---> Threshold (5s / 10s / 30s / 60s)
         |     +---> Filter (all / failure / success)
         |     +---> Voice on/off
         |     +---> Focus detection on/off
         |
         +-- Phase 4: External channels (advanced or reconfigure)
         |     +---> Interactive loop: add / reconfigure / remove / test
         |
         +-- Phase 5: AI hooks
         |     +---> Detect installed AI CLIs
         |     +---> Install hook per CLI config format:
         |           Claude: ~/.claude/settings.json (hooks.Stop)
         |           Codex:  ~/.codex/config.json
         |           Gemini: ~/.gemini/settings.json
         |           Copilot: ~/.github/hooks/*.json
         |           Cursor: ~/.cursor/hooks.json
         |           Aider: no hooks, print wrapper guidance
         |
         +-- Phase 6: Health check (doctor)
         +-- Phase 7: Summary (before/after diff)
```

## status

Show diagnostic info: platform, tools, config, integration, channels.

```bash
shelldone status             # compact view
shelldone status --full      # detailed view
```

```
shelldone status [--full]
         |
         v
  [Detect platform + tools]
         |
         v
  [Check shell integration]
         +---> Scan .zshrc for marker
         +---> Scan .bashrc for marker
         |
         v
  [Show notification tools]
         +---> macOS: osascript, terminal-notifier, afplay, say
         +---> Linux: notify-send, paplay/aplay, espeak
         +---> WSL/Win: powershell.exe, BurntToast
         |
         v
  [Show current config]
         +---> Threshold, filter, focus, voice, sounds
         |
         v
  [Show mute/schedule state]
         +---> Read state file for mute_until, quiet hours
         |
         v
  [Show external channels]
         +---> For each: configured? enabled? transport?
         |
         v
  [Show AI CLI hooks]
         +---> For each AI: installed? config file? toggled?
```

## test-notify

Send a test notification through all configured channels.

```bash
shelldone test-notify
```

```
shelldone test-notify
         |
         v
  [Source shelldone.sh in subshell]
         |
         v
  [Set SHELLDONE_FOCUS_DETECT=false]  (bypass focus detection)
         |
         v
  [_shelldone_notify "shelldone Test" "If you see this..." 0]
         |
         v
  [Desktop popup + sound + all configured external channels]
```

## sounds

List available system sounds for your platform.

```bash
shelldone sounds
```

```
shelldone sounds
         |
         v
  [Detect platform]
         |
    darwin: ls /System/Library/Sounds/*.aiff (strip extension)
    linux:  ls /usr/share/sounds/freedesktop/stereo/*.oga (strip extension)
    wsl/win: list known Windows sound names
```

## exclude

Manage auto-notify command exclusion list.

```bash
shelldone exclude list            # show current exclusions
shelldone exclude add docker      # print export line to add
shelldone exclude remove vim      # print updated export line
```

```
shelldone exclude [action] [pattern]
         |
         v
  [list]---> Print current SHELLDONE_EXCLUDE patterns
         |
  [add <pattern>]---> Append to list, print new export line
         |
  [remove <pattern>]---> Remove from list, print updated export line
```

## webhook

Manage and test external notification channels.

```bash
shelldone webhook status              # show channel config
shelldone webhook test slack           # send test message
```

```
shelldone webhook [action] [channel]
         |
         v
  [status]
         +---> Show HTTP transport (curl/wget/tcp)
         +---> Show rate limit setting
         +---> Show timeout setting
         +---> For each channel: configured? vars set?
         |
  [test <channel>]
         +---> Validate required vars for channel
         +---> If missing: print error with var names
         +---> Build test payload
         +---> POST via HTTP transport (bypass rate limit)
         +---> Print HTTP status code (200=success, 4xx/5xx=failure)
```

## mute / unmute

Temporarily suppress all notifications.

```bash
shelldone mute           # indefinitely
shelldone mute 30m       # for 30 minutes
shelldone mute 2h        # for 2 hours
shelldone unmute          # resume
```

```
shelldone mute [duration]
         |
         v
  [Duration given?]---no---> [state_write mute_until=0]
         |yes                  (indefinite mute)
         v
  [_shelldone_parse_duration]
         |  "30m" -> 1800
         |  "2h"  -> 7200
         |  "1h30m" -> 5400
         v
  [state_write mute_until=(now + seconds)]
         |
         v
  State file: ~/.local/state/shelldone/state


shelldone unmute
         |
         v
  [state_delete mute_until]
```

## toggle

Toggle notification layers on/off.

```bash
shelldone toggle                # show all states
shelldone toggle sound off      # disable sound
shelldone toggle slack off      # disable Slack
shelldone toggle external off   # disable all external channels
shelldone toggle claude off     # disable Claude notifications
```

Supported layers: `desktop`, `sound`, `voice`, `slack`, `discord`, `telegram`, `email`, `whatsapp`, `webhook`, `external` (group), `claude`, `codex`, `gemini`, `copilot`, `cursor`

```
shelldone toggle [layer [on|off]]
         |
         v
  [No args?]---yes---> [Show all toggle states from state file]
         |no
         v
  [Layer = "external"?]---yes---> [Toggle all 6 channels at once]
         |no
         v
  [Explicit on/off given?]
         |
    on:  [state_delete <layer>]  (remove = default on)
    off: [state_write <layer>=off]
    neither: [read current, flip it]
```

## schedule

Set or clear daily quiet hours.

```bash
shelldone schedule 22:00-08:00   # set quiet hours
shelldone schedule off           # clear schedule
shelldone schedule               # show current
```

```
shelldone schedule [range|off]
         |
         v
  [No args?]---yes---> [Show current from state or env var]
         |
  ["off"?]---yes---> [state_delete quiet_start + quiet_end]
         |
  [HH:MM-HH:MM?]
         +---> Validate format (regex)
         +---> Validate hours (0-23) and minutes (0-59)
         +---> state_write quiet_start=HH:MM
         +---> state_write quiet_end=HH:MM
```

## config

Manage the configuration file.

```bash
shelldone config show            # display config file
shelldone config set KEY VALUE   # update a setting
shelldone config get KEY         # show value + source
shelldone config list            # all settings with sources
shelldone config edit            # open in $EDITOR
shelldone config init            # print template
```

```
shelldone config [action] [args]
         |
         v
  [show]---> cat ~/.config/shelldone/config
  [set KEY VAL]---> write/update key in config file
  [get KEY]---> check env, config, default; print value + source
  [list]---> print all known settings with current values
  [edit]---> $EDITOR ~/.config/shelldone/config
  [init]---> print commented template to stdout
```

## uninstall

Remove all shell integration and AI CLI hooks.

```bash
shelldone uninstall          # interactive confirmation
shelldone uninstall --yes    # skip confirmation
```

```
shelldone uninstall [--yes]
         |
         v
  [--yes flag?]---no---> [Prompt for confirmation]
         |yes
         v
  [Remove from .zshrc]
         +---> Delete lines between shelldone markers
         +---> Also delete old cli-alert markers
         |
  [Remove from .bashrc]
         +---> Same marker deletion
         |
  [Remove AI CLI hooks]
         +---> Claude: remove entries from ~/.claude/settings.json
         +---> Codex:  remove entries from ~/.codex/config.json
         +---> Gemini: remove entries from ~/.gemini/settings.json
         +---> Copilot: delete ~/.github/hooks/shelldone-*.json
         +---> Cursor: remove entries from ~/.cursor/hooks.json
```

## version

```bash
shelldone version              # e.g., "1.4.0"
shelldone version --verbose    # version + platform + shell + install path
```

## help

```bash
shelldone help     # show usage summary
```

## test

```bash
shelldone test     # run full test suite (452 tests)
```
