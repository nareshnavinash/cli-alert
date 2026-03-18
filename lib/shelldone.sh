#!/usr/bin/env bash
# shelldone.sh — Core notification engine + `alert` wrapper (cross-platform)
# Source this file in your shell: eval "$(shelldone init bash)"

# Guard against double-sourcing
[[ -n "${_SHELLDONE_LOADED:-}" ]] && return 0
_SHELLDONE_LOADED=1

# ── Backward compatibility: migrate CLI_ALERT_* → SHELLDONE_* ────────────────

_shelldone_migrate_env() {
  local old new migrated=0 old_val new_val
  # List CLI_ALERT_* env vars portably (works in both bash and zsh)
  while IFS='=' read -r old _; do
    case "$old" in
      CLI_ALERT_*) ;;
      *) continue ;;
    esac
    new="SHELLDONE_${old#CLI_ALERT_}"
    eval "old_val=\"\${${old}:-}\""
    eval "new_val=\"\${${new}:-}\""
    if [[ -n "$old_val" ]] && [[ -z "$new_val" ]]; then
      eval "export $new=\"\$old_val\""
      migrated=1
      printf '\033[1;33m[shelldone]\033[0m migrated env var %s -> %s (update your config)\n' "$old" "$new" >&2
    fi
  done <<EOF
$(env 2>/dev/null)
EOF
  return 0
}
_shelldone_migrate_env

# ── Config file (loaded before defaults, so env vars set before init override) ──

_shelldone_load_config() {
  local config_file="${SHELLDONE_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/shelldone/config}"
  if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file" 2>/dev/null || true
  fi
}
_shelldone_load_config

# ── Config (override before sourcing) ────────────────────────────────────────

SHELLDONE_ENABLED="${SHELLDONE_ENABLED:-true}"
SHELLDONE_VOICE="${SHELLDONE_VOICE:-}"
SHELLDONE_FOCUS_DETECT="${SHELLDONE_FOCUS_DETECT:-true}"
SHELLDONE_NOTIFY_ON="${SHELLDONE_NOTIFY_ON:-all}"
SHELLDONE_HISTORY="${SHELLDONE_HISTORY:-true}"

# ── External notifications (lazy load) ─────────────────────────────────────

_shelldone_load_external() {
  [[ -n "${_SHELLDONE_EXTERNAL_LOADED:-}" ]] && return 0
  local ext="${_SHELLDONE_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/external-notify.sh"
  [[ -f "$ext" ]] && source "$ext"
}
# Auto-load if any channel is configured
if [[ -n "${SHELLDONE_SLACK_WEBHOOK:-}${SHELLDONE_DISCORD_WEBHOOK:-}${SHELLDONE_TELEGRAM_TOKEN:-}${SHELLDONE_EMAIL_TO:-}${SHELLDONE_WHATSAPP_TOKEN:-}${SHELLDONE_WEBHOOK_URL:-}" ]]; then
  _shelldone_load_external
fi

# ── Debug mode ───────────────────────────────────────────────────────────────

_shelldone_debug() {
  if [[ "${SHELLDONE_DEBUG:-}" == "true" ]]; then
    printf '[shelldone:debug] %s\n' "$*" >&2
  fi
}

# ── Warning (always prints, but at most once per key per session) ────────────

_shelldone_warn_once() {
  local key="$1"; shift
  local var="_SHELLDONE_WARNED_${key}"
  if [[ -z "${!var:-}" ]]; then
    eval "$var=1"
    printf '\033[1;33m[shelldone]\033[0m %s\n' "$*" >&2
  fi
}

# ── Platform detection (runs once) ───────────────────────────────────────────

_shelldone_detect_platform() {
  case "$(uname -s)" in
    Darwin)
      _SHELLDONE_PLATFORM="darwin"
      ;;
    Linux)
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        _SHELLDONE_PLATFORM="wsl"
      else
        _SHELLDONE_PLATFORM="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      _SHELLDONE_PLATFORM="windows"
      ;;
    *)
      _SHELLDONE_PLATFORM="unknown"
      ;;
  esac
  _shelldone_debug "platform detected: $_SHELLDONE_PLATFORM"
}

_shelldone_detect_platform

# ── Platform-specific defaults ───────────────────────────────────────────────

case "$_SHELLDONE_PLATFORM" in
  darwin)
    SHELLDONE_SOUND_SUCCESS="${SHELLDONE_SOUND_SUCCESS:-Glass}"
    SHELLDONE_SOUND_FAILURE="${SHELLDONE_SOUND_FAILURE:-Sosumi}"
    ;;
  linux)
    SHELLDONE_SOUND_SUCCESS="${SHELLDONE_SOUND_SUCCESS:-complete}"
    SHELLDONE_SOUND_FAILURE="${SHELLDONE_SOUND_FAILURE:-dialog-error}"
    ;;
  wsl|windows)
    SHELLDONE_SOUND_SUCCESS="${SHELLDONE_SOUND_SUCCESS:-Asterisk}"
    SHELLDONE_SOUND_FAILURE="${SHELLDONE_SOUND_FAILURE:-Hand}"
    ;;
esac

# ── Security: sanitize strings for AppleScript interpolation ─────────────────

_shelldone_sanitize_applescript() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  printf '%s' "$str"
}

# ── Helper: background process with timeout ──────────────────────────────────

_shelldone_bg_timeout() {
  local max_secs="${SHELLDONE_SOUND_TIMEOUT:-10}"
  (
    "$@" &
    local child=$!
    ( sleep "$max_secs" && kill "$child" 2>/dev/null ) &
    local watchdog=$!
    wait "$child" 2>/dev/null
    kill "$watchdog" 2>/dev/null
  ) 2>/dev/null &
}

# ── Helper: Unicode-safe status icon ─────────────────────────────────────────

_shelldone_status_icon() {
  local exit_code="$1"
  local has_utf8=0
  case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
    *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) has_utf8=1 ;;
  esac
  if [[ "$exit_code" -eq 0 ]]; then
    if [[ "$has_utf8" -eq 1 ]]; then printf '✓'; else printf '[OK]'; fi
  else
    if [[ "$has_utf8" -eq 1 ]]; then printf '✗'; else printf '[FAIL]'; fi
  fi
}

# ── Helper: format duration ──────────────────────────────────────────────────

_shelldone_format_duration() {
  local seconds="$1"
  if (( seconds == 0 )); then
    printf '<1s'
  elif (( seconds < 60 )); then
    printf '%ds' "$seconds"
  elif (( seconds < 3600 )); then
    printf '%dm %ds' $((seconds / 60)) $((seconds % 60))
  else
    printf '%dh %dm %ds' $((seconds / 3600)) $(((seconds % 3600) / 60)) $((seconds % 60))
  fi
}

# ── Activate auto-detection (macOS terminal → bundle ID for click-to-activate) ─

_shelldone_resolve_activate() {
  if [[ -n "${SHELLDONE_ACTIVATE:-}" ]]; then
    printf '%s' "$SHELLDONE_ACTIVATE"; return
  fi
  case "${TERM_PROGRAM:-}" in
    vscode)         printf 'com.microsoft.VSCode' ;;
    Apple_Terminal)  printf 'com.apple.Terminal' ;;
    iTerm.app)      printf 'com.googlecode.iterm2' ;;
    Hyper)          printf 'co.zeit.hyper' ;;
    WarpTerminal)   printf 'dev.warp.Warp-Stable' ;;
    Alacritty)      printf 'org.alacritty' ;;
    *)              printf 'com.apple.Terminal' ;;
  esac
}

# ── Workspace resolution (VS Code window targeting) ─────────────────────────

_shelldone_resolve_workspace() {
  if [[ -n "${SHELLDONE_WORKSPACE:-}" ]]; then
    printf '%s' "$SHELLDONE_WORKSPACE"; return
  fi
  if command -v git &>/dev/null; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) && [[ -n "$root" ]] && printf '%s' "$root" && return
  fi
  printf '%s' "$PWD"
}

# ── Platform notification functions ──────────────────────────────────────────

_shelldone_notify_darwin() {
  local title="$1" message="$2" exit_code="$3"
  _shelldone_debug "darwin notifier: title='$title' exit=$exit_code"

  if ! _shelldone_channel_enabled "desktop" 2>/dev/null; then
    _shelldone_debug "desktop channel toggled off"
  elif command -v terminal-notifier &>/dev/null; then
    local tn_args=(-title "$title" -message "$message")

    # Click action: for VS Code, open the workspace URL to target the correct window.
    # For other terminals, activate the app by bundle ID.
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
      local workspace
      workspace="$(_shelldone_resolve_workspace)"
      tn_args+=(-open "vscode://file${workspace}")
      _shelldone_debug "open workspace on click: vscode://file${workspace}"
    else
      local activate
      activate="$(_shelldone_resolve_activate)"
      tn_args+=(-activate "$activate")
      _shelldone_debug "activate on click: $activate"
    fi

    if ! terminal-notifier "${tn_args[@]}" 2>/dev/null; then
      _shelldone_warn_once DARWIN_TN "terminal-notifier failed — run 'shelldone status' to diagnose"
    fi
  else
    # Fallback: osascript (no custom icon, no click-to-activate)
    local safe_title safe_message
    safe_title="$(_shelldone_sanitize_applescript "$title")"
    safe_message="$(_shelldone_sanitize_applescript "$message")"
    if ! osascript -e "display notification \"$safe_message\" with title \"$safe_title\"" 2>/dev/null; then
      _shelldone_warn_once DARWIN_OSASCRIPT "osascript notification failed — run 'shelldone status' to diagnose"
    fi
  fi

  # Sound (background with timeout)
  if _shelldone_channel_enabled "sound" 2>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$SHELLDONE_SOUND_SUCCESS"
    else
      sound="$SHELLDONE_SOUND_FAILURE"
    fi
    _shelldone_debug "sound: $sound"
    local sound_file
    if [[ "$sound" == */* ]]; then
      sound_file="$sound"
    else
      sound_file="/System/Library/Sounds/${sound}.aiff"
    fi
    if [[ -f "$sound_file" ]]; then
      _shelldone_bg_timeout afplay "$sound_file"
    else
      _shelldone_warn_once SOUND "sound file not found: $sound_file — try 'shelldone sounds'"
    fi
  fi

  # TTS (optional, with timeout)
  if [[ "$SHELLDONE_VOICE" == "true" ]] && _shelldone_channel_enabled "voice" 2>/dev/null; then
    _shelldone_bg_timeout say "$message"
  fi
}

_shelldone_notify_linux() {
  local title="$1" message="$2" exit_code="$3"
  _shelldone_debug "linux notifier: title='$title' exit=$exit_code"

  # Notification
  if ! _shelldone_channel_enabled "desktop" 2>/dev/null; then
    _shelldone_debug "desktop channel toggled off"
  elif command -v notify-send &>/dev/null; then
    # Try custom shelldone icon, fall back to system theme icons
    local icon
    local lib_dir="${_SHELLDONE_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    local custom_icon="${lib_dir}/../assets/linux/shelldone.png"
    if [[ -f "$custom_icon" ]]; then
      icon="$(cd "$(dirname "$custom_icon")" && pwd)/shelldone.png"
    elif [[ "$exit_code" -eq 0 ]]; then
      icon="dialog-information"
    else
      icon="dialog-error"
    fi
    notify-send --icon="$icon" "$title" "$message" 2>/dev/null
  else
    _shelldone_warn_once LINUX_NOTIFY "notify-send not found (install libnotify-bin for desktop notifications)"
    _shelldone_fallback "$title" "$message"
    return
  fi

  # Sound (background with timeout, try paplay → aplay → mpv)
  if _shelldone_channel_enabled "sound" 2>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$SHELLDONE_SOUND_SUCCESS"
    else
      sound="$SHELLDONE_SOUND_FAILURE"
    fi
    _shelldone_debug "sound: $sound"

    local sound_file
    if [[ "$sound" == */* ]]; then
      sound_file="$sound"
    else
      sound_file="/usr/share/sounds/freedesktop/stereo/${sound}.oga"
    fi
    if [[ -f "$sound_file" ]]; then
      if command -v paplay &>/dev/null; then
        _shelldone_bg_timeout paplay "$sound_file"
      elif command -v aplay &>/dev/null; then
        _shelldone_bg_timeout aplay "$sound_file"
      elif command -v mpv &>/dev/null; then
        _shelldone_bg_timeout mpv --no-terminal "$sound_file"
      fi
    fi
  fi

  # TTS (optional, with timeout)
  if [[ "$SHELLDONE_VOICE" == "true" ]] && _shelldone_channel_enabled "voice" 2>/dev/null; then
    if command -v espeak &>/dev/null; then
      _shelldone_bg_timeout espeak "$message"
    elif command -v spd-say &>/dev/null; then
      _shelldone_bg_timeout spd-say "$message"
    fi
  fi
}

_shelldone_notify_wsl() {
  local title="$1" message="$2" exit_code="$3"
  _shelldone_debug "wsl notifier: title='$title' exit=$exit_code"

  # Notification: try BurntToast → wsl-notify-send → WinRT toast
  # Pass values via environment variables to avoid PowerShell injection
  if ! _shelldone_channel_enabled "desktop" 2>/dev/null; then
    _shelldone_debug "desktop channel toggled off"
  elif powershell.exe -Command "Get-Module -ListAvailable -Name BurntToast" &>/dev/null 2>&1; then
    SHELLDONE_PS_TITLE="$title" SHELLDONE_PS_MSG="$message" \
      powershell.exe -Command 'Import-Module BurntToast; New-BurntToastNotification -Text $env:SHELLDONE_PS_TITLE, $env:SHELLDONE_PS_MSG' 2>/dev/null
  elif command -v wsl-notify-send &>/dev/null; then
    wsl-notify-send --category "$title" "$message" 2>/dev/null
  elif command -v powershell.exe &>/dev/null; then
    SHELLDONE_PS_TITLE="$title" SHELLDONE_PS_MSG="$message" \
      powershell.exe -Command '
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $textNodes = $template.GetElementsByTagName("text")
        $textNodes.Item(0).AppendChild($template.CreateTextNode($env:SHELLDONE_PS_TITLE)) > $null
        $textNodes.Item(1).AppendChild($template.CreateTextNode($env:SHELLDONE_PS_MSG)) > $null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("shelldone").Show($toast)
      ' 2>/dev/null
  else
    _shelldone_warn_once WSL_NOTIFY "no Windows notification tool found — run 'shelldone status' to diagnose"
    _shelldone_fallback "$title" "$message"
    return
  fi

  # Sound (background with timeout, via env var)
  if _shelldone_channel_enabled "sound" 2>/dev/null && command -v powershell.exe &>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$SHELLDONE_SOUND_SUCCESS"
    else
      sound="$SHELLDONE_SOUND_FAILURE"
    fi
    _shelldone_debug "sound: $sound"
    if [[ "$sound" == */* ]]; then
      SHELLDONE_PS_SOUND="$sound" \
        _shelldone_bg_timeout powershell.exe -Command '(New-Object Media.SoundPlayer ($env:SHELLDONE_PS_SOUND)).PlaySync()'
    else
      SHELLDONE_PS_SOUND="$sound" \
        _shelldone_bg_timeout powershell.exe -Command '(New-Object Media.SoundPlayer ("C:\Windows\Media\Windows " + $env:SHELLDONE_PS_SOUND + ".wav")).PlaySync()'
    fi
  fi

  # TTS (optional, via env var, with timeout)
  if [[ "$SHELLDONE_VOICE" == "true" ]] && _shelldone_channel_enabled "voice" 2>/dev/null && command -v powershell.exe &>/dev/null; then
    SHELLDONE_PS_MSG="$message" \
      _shelldone_bg_timeout powershell.exe -Command 'Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak($env:SHELLDONE_PS_MSG)'
  fi
}

_shelldone_notify_windows() {
  # Git Bash / MSYS2 / Cygwin — same approach as WSL but without wsl-notify-send
  _shelldone_notify_wsl "$@"
}

# ── Fallback (terminal bell + stderr) ────────────────────────────────────────

_shelldone_fallback() {
  local title="$1" message="$2"
  # Terminal bell
  printf '\a' >/dev/tty 2>/dev/null || printf '\a'
  # Colored stderr message
  printf '\033[1;33m[shelldone]\033[0m %s: %s\n' "$title" "$message" >&2
}

# ── Terminal focus detection ──────────────────────────────────────────────────

_shelldone_terminal_focused_darwin() {
  local frontmost
  frontmost=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null) || return 1
  local terminals="${SHELLDONE_TERMINALS:-Terminal iTerm2 Alacritty kitty WezTerm Hyper}"
  local term
  for term in $terminals; do
    [[ "$frontmost" == "$term" ]] && return 0
  done
  return 1
}

_shelldone_terminal_focused_linux() {
  command -v xdotool &>/dev/null || return 1
  local win_pid
  win_pid=$(xdotool getactivewindow getwindowpid 2>/dev/null) || return 1
  # Walk PID ancestry to check if our shell owns the focused window
  local check_pid="$win_pid"
  while [[ "$check_pid" -gt 1 ]] 2>/dev/null; do
    [[ "$check_pid" == "$$" ]] && return 0
    check_pid=$(ps -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ') || break
  done
  return 1
}

_shelldone_terminal_focused() {
  [[ "$SHELLDONE_FOCUS_DETECT" != "true" ]] && return 1
  case "$_SHELLDONE_PLATFORM" in
    darwin)  _shelldone_terminal_focused_darwin ;;
    linux)   _shelldone_terminal_focused_linux ;;
    *)       return 1 ;;  # WSL/Windows: can't detect reliably
  esac
}

# ── Notification history log ──────────────────────────────────────────────────

_shelldone_log_history() {
  local title="$1" message="$2" exit_code="$3"

  [[ "${SHELLDONE_HISTORY:-true}" != "true" ]] && return 0

  local log_dir="${SHELLDONE_HISTORY_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/shelldone}"
  local log_file="${log_dir}/history.log"

  if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir" 2>/dev/null || return 0
  fi

  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  local channels="desktop"
  [[ -n "${SHELLDONE_SLACK_WEBHOOK:-}" ]]   && channels+=",slack"
  [[ -n "${SHELLDONE_DISCORD_WEBHOOK:-}" ]] && channels+=",discord"
  [[ -n "${SHELLDONE_TELEGRAM_TOKEN:-}" ]]  && channels+=",telegram"
  [[ -n "${SHELLDONE_EMAIL_TO:-}" ]]        && channels+=",email"
  [[ -n "${SHELLDONE_WHATSAPP_TOKEN:-}" ]]  && channels+=",whatsapp"
  [[ -n "${SHELLDONE_WEBHOOK_URL:-}" ]]     && channels+=",webhook"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$timestamp" "$title" "$message" "$exit_code" "$channels" \
    >> "$log_file" 2>/dev/null
}

# ── Main notification dispatcher ─────────────────────────────────────────────

_shelldone_notify() {
  local title="$1" message="$2" exit_code="${3:-0}"

  # Validate exit code is numeric
  [[ "$exit_code" =~ ^[0-9]+$ ]] || exit_code=1

  [[ "$SHELLDONE_ENABLED" != "true" ]] && return 0

  # Lazy-load state module
  if [[ -z "${_SHELLDONE_STATE_LOADED:-}" ]]; then
    local _state_lib="${_SHELLDONE_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/state.sh"
    [[ -f "$_state_lib" ]] && source "$_state_lib"
  fi

  # Mute / quiet hours check (full suppression — still logs to history)
  if _shelldone_is_muted 2>/dev/null || _shelldone_is_quiet_hours 2>/dev/null; then
    _shelldone_debug "suppressed by mute or quiet hours"
    _shelldone_log_history "$title" "$message" "$exit_code"
    return 0
  fi

  # Log to history
  _shelldone_log_history "$title" "$message" "$exit_code"

  # External notifications (fire regardless of focus, non-blocking)
  # Lazy-load external module if a channel was configured after shell init
  if ! declare -f _shelldone_notify_external &>/dev/null; then
    if [[ -n "${SHELLDONE_SLACK_WEBHOOK:-}${SHELLDONE_DISCORD_WEBHOOK:-}${SHELLDONE_TELEGRAM_TOKEN:-}${SHELLDONE_EMAIL_TO:-}${SHELLDONE_WHATSAPP_TOKEN:-}${SHELLDONE_WEBHOOK_URL:-}" ]]; then
      _shelldone_load_external
    fi
  fi
  if declare -f _shelldone_notify_external &>/dev/null; then
    _shelldone_notify_external "$title" "$message" "$exit_code"
  fi

  if _shelldone_terminal_focused; then
    _shelldone_debug "terminal focused, suppressing notification"
    return 0
  fi

  _shelldone_debug "notify: title='$title' exit=$exit_code platform=$_SHELLDONE_PLATFORM"

  case "$_SHELLDONE_PLATFORM" in
    darwin)  _shelldone_notify_darwin  "$title" "$message" "$exit_code" ;;
    linux)   _shelldone_notify_linux   "$title" "$message" "$exit_code" ;;
    wsl)     _shelldone_notify_wsl     "$title" "$message" "$exit_code" ;;
    windows) _shelldone_notify_windows "$title" "$message" "$exit_code" ;;
    *)       _shelldone_fallback       "$title" "$message" ;;
  esac

  # Clean up metadata to prevent stale vars leaking across notifications
  if declare -f _shelldone_clear_metadata &>/dev/null; then
    _shelldone_clear_metadata
  fi
}

# ── `alert` wrapper command ──────────────────────────────────────────────────

alert() {
  # Parse flags
  local notify_on="${SHELLDONE_NOTIFY_ON:-all}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on-failure) notify_on="failure"; shift ;;
      --on-success) notify_on="success"; shift ;;
      --)           shift; break ;;
      *)            break ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    echo "Usage: alert [--on-failure|--on-success] [--] <command> [args...]" >&2
    return 1
  fi

  local cmd_display="$*"
  # Truncate display name for notification (word-boundary aware)
  if [[ ${#cmd_display} -gt 50 ]]; then
    local truncated="${cmd_display:0:47}"
    # Try to break at a word boundary (last space before position 47)
    if [[ "$truncated" == *" "* ]]; then
      truncated="${truncated% *}"
    fi
    cmd_display="${truncated}..."
  fi

  local start_seconds=$SECONDS

  # Run the command
  "$@"
  local exit_code=$?

  local elapsed=$((SECONDS - start_seconds))
  local duration
  duration=$(_shelldone_format_duration "$elapsed")

  # Check notification filter
  if [[ "$notify_on" == "failure" && "$exit_code" -eq 0 ]]; then
    return $exit_code
  fi
  if [[ "$notify_on" == "success" && "$exit_code" -ne 0 ]]; then
    return $exit_code
  fi

  local status_icon
  status_icon="$(_shelldone_status_icon "$exit_code")"

  local cmd_base="${1##*/}"

  # Set metadata for enriched Slack messages
  export _SHELLDONE_META_CMD="$cmd_display"
  export _SHELLDONE_META_DURATION="$duration"
  export _SHELLDONE_META_SOURCE="shell"

  _shelldone_notify \
    "${cmd_base} Complete" \
    "${status_icon} ${cmd_display} (${duration}, exit ${exit_code})"  \
    "$exit_code"

  return $exit_code
}

# ── `alert-bg` background job tracker ────────────────────────────────────────

alert-bg() {
  local target="${1:-}"
  local pid=""
  local job_name=""

  if [[ -z "$target" ]]; then
    # No argument: monitor last background job ($!)
    pid="${!:-}"
    if [[ -z "$pid" ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
      echo "alert-bg: no background job found. Usage: alert-bg [PID|%jobspec]" >&2
      return 1
    fi
    job_name="PID $pid"
  elif [[ "$target" == %* ]]; then
    # Job spec (e.g., %1)
    pid=$(jobs -p "$target" 2>/dev/null) || {
      echo "alert-bg: no such job '$target'" >&2
      return 1
    }
    if [[ -z "$pid" ]]; then
      echo "alert-bg: cannot resolve job '$target'" >&2
      return 1
    fi
    job_name="job $target (PID $pid)"
  elif [[ "$target" =~ ^[0-9]+$ ]]; then
    # Explicit PID
    pid="$target"
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "alert-bg: PID $pid is not running" >&2
      return 1
    fi
    job_name="PID $pid"
  else
    echo "Usage: alert-bg [PID|%jobspec]" >&2
    return 1
  fi

  local start_seconds=$SECONDS

  # Wait for the process
  local exit_code
  if wait "$pid" 2>/dev/null; then
    exit_code=0
  else
    exit_code=$?
  fi

  # wait returns 127 for non-child PIDs — fall back to polling
  if [[ $exit_code -eq 127 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      sleep 1
    done
    exit_code="unknown"
  fi

  local elapsed=$((SECONDS - start_seconds))
  local duration
  duration=$(_shelldone_format_duration "$elapsed")

  # Set metadata for enriched channel messages
  export _SHELLDONE_META_CMD="$job_name"
  export _SHELLDONE_META_DURATION="$duration"
  export _SHELLDONE_META_SOURCE="shell"

  local bg_title="Background: ${job_name} Complete"

  if [[ "$exit_code" == "unknown" ]]; then
    local has_utf8=0
    case "${LC_ALL:-}${LC_CTYPE:-}${LANG:-}" in
      *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) has_utf8=1 ;;
    esac
    local unknown_icon
    if [[ "$has_utf8" -eq 1 ]]; then unknown_icon="⚠"; else unknown_icon="[??]"; fi
    _shelldone_notify \
      "$bg_title" \
      "${unknown_icon} ${job_name} (${duration}, exit unknown)" \
      2
  else
    local status_icon
    status_icon="$(_shelldone_status_icon "$exit_code")"
    _shelldone_notify \
      "$bg_title" \
      "${status_icon} ${job_name} (${duration}, exit ${exit_code})" \
      "$exit_code"
  fi
}
