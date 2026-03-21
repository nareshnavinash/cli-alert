# Architecture

This document describes shelldone's internal architecture, module structure, and data flows.

## Project Structure

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
├── test.sh                    # Test suite (452 tests)
├── Makefile                   # make install/uninstall/test
└── VERSION                    # Current version
```

## Design Principles

- **Multi-path resolution** - Works from source (`./lib/`) and installed (`/usr/lib/shelldone/`, `/usr/local/lib/shelldone/`)
- **Lazy loading** - External notification module loaded at init if a channel env var is set, or on-demand at notification time if configured later
- **Double-source guards** - All lib files check guard variables to prevent re-initialization
- **Marker-based uninstall** - RC file cleanup uses `# >>> shelldone >>>` / `# <<< shelldone <<<` markers
- **Timeout safety** - Background sound/TTS processes have watchdog timers to prevent hangs
- **Pure-bash JSON** - JSON escaping without `jq` dependency
- **Rate limiting** - Per-channel rate limits via shared stamp files in `/tmp/`
- **Fallback chain** - Platform notifier > warning > terminal bell + stderr message

## Notification Flow

End-to-end path from command completion to notification delivery:

```
Command completes (exit code captured)
         |
         v
+--[Entry Point]------------------------------------------+
|                                                          |
|  alert()            auto-notify hook       AI CLI hook   |
|  (manual wrap)      (preexec/precmd)       (JSON stdin)  |
|                                                          |
+-------------------+--------------------------------------+
                    |
                    v
          _shelldone_notify(title, message, exit_code)
                    |
                    v
          [SHELLDONE_ENABLED != true?]---yes---> return
                    |no
                    v
          [Load state.sh if needed]
                    |
                    v
          [_shelldone_is_muted?]---yes---> log to history, return
                    |no
                    v
          [_shelldone_is_quiet_hours?]---yes---> log to history, return
                    |no
                    v
          [Log to history file]
                    |
          +---------+---------+
          |                   |
          v                   v
  [External dispatch]   [Focus detection]
  (background, async)         |
          |             [terminal focused?]
          |                   |
          |             yes---+---no
          |              |        |
          |           return      v
          |                 [Platform notifier]
          |                       |
          |           +-----------+-----------+-----------+
          |           |           |           |           |
          |        darwin       linux        wsl       fallback
          |           |           |           |           |
          |      osascript   notify-send  BurntToast  bell+stderr
          |      + afplay    + paplay     + PS toast
          |      + say       + espeak     + PS speak
          |
          v
  [Load external-notify.sh if needed]
          |
  +-------+-------+-------+-------+-------+-------+
  |       |       |       |       |       |       |
 Slack  Discord Telegram Email WhatsApp Webhook  (skip)
  |       |       |       |       |       |
  +-------+-------+-------+-------+-------+
          |
          v
  [Per-channel flow]
          |
    [channel enabled?]---no---> skip
          |yes
    [rate limit check]---blocked---> skip
          |clear
    [build JSON payload]
          |
    [HTTP transport: curl > wget > /dev/tcp]
          |
    [POST to endpoint]
          |
    [update rate stamp file]
```

## Auto-Notify Hook Cycle

### Zsh (preexec / precmd)

```
User types command and presses Enter
         |
         v
  [preexec hook fires]
         |
         +---> SHELLDONE_AUTO != true? ---> return
         |
         +---> Store command name: first word of $1
         +---> Store full command: $1 (truncate to 50 chars)
         +---> Record start time: $EPOCHSECONDS
         |
         v
  [Command executes...]
         |
         v
  [precmd hook fires]
         |
         +---> Capture $? as last_exit
         +---> SHELLDONE_AUTO != true? ---> return
         +---> No command recorded? ---> return
         |
         v
  [Calculate elapsed = EPOCHSECONDS - start]
         |
         v
  [elapsed < SHELLDONE_THRESHOLD?]---yes---> return
         |no
         v
  [Command in SHELLDONE_EXCLUDE?]---yes---> return
  (glob matching with $~excluded)
         |no
         v
  [Check SHELLDONE_NOTIFY_ON filter]
  (all / failure / success)
         |pass
         v
  [Format duration + status icon]
         |
         v
  [Set _SHELLDONE_META_* env vars]
         |
         v
  [_shelldone_notify]
```

### Bash (DEBUG trap / PROMPT_COMMAND)

```
Shell initializes
         |
         v
  [PROMPT_COMMAND set to _shelldone_prompt_command]
         |
         v
  [One-shot trap installer runs at first prompt]
         |
         +---> Detect existing DEBUG trap
         +---> Chain: existing_trap + _shelldone_debug_trap
         |
         v
  [User types command]
         |
         v
  [DEBUG trap fires (_shelldone_debug_trap)]
         |
         +---> In PROMPT_COMMAND? ---> return (skip)
         +---> Already recording? ---> return (first cmd only)
         |
         +---> Store BASH_COMMAND name (first word)
         +---> Store full command (truncate to 50 chars)
         +---> Record start: $SECONDS
         |
         v
  [Command executes...]
         |
         v
  [PROMPT_COMMAND fires (_shelldone_prompt_command)]
         |
         +---> Capture $? as last_exit
         +---> Set _shelldone_in_prompt_command=1 (guard)
         +---> No command recorded? ---> reset, return
         |
         v
  [Same threshold/exclusion/filter/notify flow as zsh]
         |
         v
  [Reset _shelldone_in_prompt_command=0]
```

## AI Hook Integration

```
AI CLI completes a task (e.g., Claude Code stops)
         |
         v
  [AI CLI invokes hook script via its config]
  (stdin receives JSON event)
         |
         v
  [Hook script (e.g., claude-done.sh)]
         |
         +---> Read JSON from stdin
         +---> Source ai-hook-common.sh
         |       |
         |       +---> Resolve lib path (source vs installed)
         |       +---> Source shelldone.sh + state.sh
         |
         +---> Extract fields via python3:
         |       stop_reason, title, message
         |
         +---> Map stop_reason to exit code:
         |       error/max_turns_reached/timeout -> 1
         |       end_turn/stop_sequence/""       -> 0
         |
         +---> Build notification message:
         |       "Task complete (end_turn)"
         |
         v
  [_shelldone_hook_notify(ai_name, message, exit_code)]
         |
         +---> Normalize AI name to key: "Claude Code" -> "claude-code"
         +---> Check per-AI toggle state ---off---> return silently
         |on
         +---> Set metadata:
         |       _SHELLDONE_META_SOURCE="ai-hook"
         |       _SHELLDONE_META_AI_NAME="Claude Code"
         |       _SHELLDONE_HOOK_CONTEXT=true (sync external)
         |
         v
  [_shelldone_notify] (normal flow, but external runs synchronously
                       because parent AI CLI may kill process tree)
```

## State Management

```
State file: ${XDG_STATE_HOME:-~/.local/state}/shelldone/state

Format (key=value, one per line):
+-----------------------------------+
| mute_until=1711036800             |
| quiet_start=22:00                 |
| quiet_end=08:00                   |
| sound=off                         |
| slack=off                         |
| claude-code=off                   |
+-----------------------------------+

Operations:
  _shelldone_state_read KEY        Read one key from state file
  _shelldone_state_write KEY VAL   Write key (atomic: tmp + mv)
  _shelldone_state_delete KEY      Remove key (atomic: tmp + mv)
  _shelldone_state_dump            Print entire state file

Checks:
  _shelldone_is_muted
       |
       +---> Read mute_until
       +---> "0" = indefinite mute ---> muted
       +---> mute_until > now ---> muted
       +---> mute_until <= now ---> expired, delete key, not muted

  _shelldone_channel_enabled CHANNEL
       |
       +---> Read channel key
       +---> Missing = on (default)
       +---> "off" = disabled

  _shelldone_is_quiet_hours
       |
       +---> Read quiet_start + quiet_end from state
       +---> Fallback: parse SHELLDONE_QUIET_HOURS env var
       +---> Convert HH:MM to minutes since midnight
       +---> Same-day range: start <= now < end
       +---> Cross-midnight: now >= start OR now < end
```

## Configuration Hierarchy

```
Priority (highest to lowest):

  1. Environment variables
     |  export SHELLDONE_THRESHOLD=60
     |  (set before eval "$(shelldone init)")
     |
     v
  2. Config file
     |  ~/.config/shelldone/config
     |  (sourced at load time, uses : "${VAR:=value}" defaults)
     |
     v
  3. Hardcoded defaults
        SHELLDONE_ENABLED=true
        SHELLDONE_THRESHOLD=10
        SHELLDONE_FOCUS_DETECT=true
        SHELLDONE_NOTIFY_ON=all
        SHELLDONE_HISTORY=true
        SHELLDONE_SOUND_SUCCESS=Glass (macOS) / complete (Linux) / Asterisk (Windows)
        SHELLDONE_SOUND_FAILURE=Sosumi (macOS) / dialog-error (Linux) / Hand (Windows)
```

## Module Loading

```
Shell startup (eval "$(shelldone init zsh)")
         |
         v
  [Source shelldone.sh]
         |
         +---> Guard: _SHELLDONE_LOADED
         +---> Migrate CLI_ALERT_* env vars
         +---> Load config file
         +---> Set defaults
         +---> Detect platform (darwin/linux/wsl/windows)
         +---> Set platform-specific sound defaults
         +---> Define core functions:
         |       _shelldone_notify, alert, alert-bg
         |       _shelldone_format_duration, _shelldone_status_icon
         |       Platform notifiers (darwin/linux/wsl/windows)
         |       Focus detection, history logging
         |
         +---> Lazy-load external-notify.sh if channel vars set
         |
         v
  [Source auto-notify.zsh (or .bash)]
         |
         +---> Guard: _SHELLDONE_AUTO_ZSH_LOADED
         +---> Check nested shell suppression
         +---> Register preexec/precmd hooks (zsh)
              or DEBUG trap + PROMPT_COMMAND (bash)
```

## Platform Support Matrix

| Feature | macOS | Linux | WSL | Windows (Git Bash) |
|---|---|---|---|---|
| Desktop notifications | osascript | notify-send | BurntToast / WinRT | BurntToast / WinRT |
| Sound | afplay | paplay / aplay / mpv | powershell.exe | powershell.exe |
| TTS | say | espeak / spd-say | powershell.exe | powershell.exe |
| Focus detection | AppleScript | xdotool | -- | -- |
| Auto-notify | zsh + bash | zsh + bash | zsh + bash | bash |
| External notifications | All channels | All channels | All channels | All channels |
| Fallback | terminal bell | terminal bell | terminal bell | terminal bell |

## Testing

shelldone includes 452 tests covering unit, integration, and end-to-end scenarios.

```bash
bash test.sh       # from project root
shelldone test     # via the CLI
```

CI runs via GitHub Actions (`.github/workflows/ci.yml`):
1. **ShellCheck** - lints all shell scripts
2. **Test macOS** - runs test suite under both `bash` and `zsh`
3. **Test Linux** - installs dependencies, runs test suite
4. **Test Install** - full install/verify/uninstall roundtrip
