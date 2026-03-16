#!/usr/bin/env bash
# cli-alert.sh — Core notification engine + `alert` wrapper (cross-platform)
# Source this file in your shell: eval "$(cli-alert init bash)"

# Guard against double-sourcing
[[ -n "${_CLI_ALERT_LOADED:-}" ]] && return 0
_CLI_ALERT_LOADED=1

# ── Config file (loaded before defaults, so env vars set before init override) ──

_cli_alert_load_config() {
  local config_file="${CLI_ALERT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/cli-alert/config}"
  if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file" 2>/dev/null || true
  fi
}
_cli_alert_load_config

# ── Config (override before sourcing) ────────────────────────────────────────

CLI_ALERT_ENABLED="${CLI_ALERT_ENABLED:-true}"
CLI_ALERT_VOICE="${CLI_ALERT_VOICE:-}"
CLI_ALERT_FOCUS_DETECT="${CLI_ALERT_FOCUS_DETECT:-true}"
CLI_ALERT_NOTIFY_ON="${CLI_ALERT_NOTIFY_ON:-all}"
CLI_ALERT_HISTORY="${CLI_ALERT_HISTORY:-true}"

# ── External notifications (lazy load) ─────────────────────────────────────

_cli_alert_load_external() {
  [[ -n "${_CLI_ALERT_EXTERNAL_LOADED:-}" ]] && return 0
  local ext="${_CLI_ALERT_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/external-notify.sh"
  [[ -f "$ext" ]] && source "$ext"
}
# Auto-load if any channel is configured
if [[ -n "${CLI_ALERT_SLACK_WEBHOOK:-}${CLI_ALERT_DISCORD_WEBHOOK:-}${CLI_ALERT_TELEGRAM_TOKEN:-}${CLI_ALERT_EMAIL_TO:-}${CLI_ALERT_WHATSAPP_TOKEN:-}${CLI_ALERT_WEBHOOK_URL:-}" ]]; then
  _cli_alert_load_external
fi

# ── Debug mode ───────────────────────────────────────────────────────────────

_cli_alert_debug() {
  if [[ "${CLI_ALERT_DEBUG:-}" == "true" ]]; then
    printf '[cli-alert:debug] %s\n' "$*" >&2
  fi
}

# ── Warning (always prints, but at most once per key per session) ────────────

_cli_alert_warn_once() {
  local key="$1"; shift
  local var="_CLI_ALERT_WARNED_${key}"
  if [[ -z "${!var:-}" ]]; then
    eval "$var=1"
    printf '\033[1;33m[cli-alert]\033[0m %s\n' "$*" >&2
  fi
}

# ── Platform detection (runs once) ───────────────────────────────────────────

_cli_alert_detect_platform() {
  case "$(uname -s)" in
    Darwin)
      _CLI_ALERT_PLATFORM="darwin"
      ;;
    Linux)
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        _CLI_ALERT_PLATFORM="wsl"
      else
        _CLI_ALERT_PLATFORM="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      _CLI_ALERT_PLATFORM="windows"
      ;;
    *)
      _CLI_ALERT_PLATFORM="unknown"
      ;;
  esac
  _cli_alert_debug "platform detected: $_CLI_ALERT_PLATFORM"
}

_cli_alert_detect_platform

# ── Platform-specific defaults ───────────────────────────────────────────────

case "$_CLI_ALERT_PLATFORM" in
  darwin)
    CLI_ALERT_SOUND_SUCCESS="${CLI_ALERT_SOUND_SUCCESS:-Glass}"
    CLI_ALERT_SOUND_FAILURE="${CLI_ALERT_SOUND_FAILURE:-Sosumi}"
    ;;
  linux)
    CLI_ALERT_SOUND_SUCCESS="${CLI_ALERT_SOUND_SUCCESS:-complete}"
    CLI_ALERT_SOUND_FAILURE="${CLI_ALERT_SOUND_FAILURE:-dialog-error}"
    ;;
  wsl|windows)
    CLI_ALERT_SOUND_SUCCESS="${CLI_ALERT_SOUND_SUCCESS:-Asterisk}"
    CLI_ALERT_SOUND_FAILURE="${CLI_ALERT_SOUND_FAILURE:-Hand}"
    ;;
esac

# ── Security: sanitize strings for AppleScript interpolation ─────────────────

_cli_alert_sanitize_applescript() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  printf '%s' "$str"
}

# ── Helper: background process with timeout ──────────────────────────────────

_cli_alert_bg_timeout() {
  local max_secs="${CLI_ALERT_SOUND_TIMEOUT:-10}"
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

_cli_alert_status_icon() {
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

_cli_alert_format_duration() {
  local seconds="$1"
  if (( seconds < 60 )); then
    printf '%ds' "$seconds"
  elif (( seconds < 3600 )); then
    printf '%dm %ds' $((seconds / 60)) $((seconds % 60))
  else
    printf '%dh %dm %ds' $((seconds / 3600)) $(((seconds % 3600) / 60)) $((seconds % 60))
  fi
}

# ── Activate auto-detection (macOS terminal → bundle ID for click-to-activate) ─

_cli_alert_resolve_activate() {
  if [[ -n "${CLI_ALERT_ACTIVATE:-}" ]]; then
    printf '%s' "$CLI_ALERT_ACTIVATE"; return
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

_cli_alert_resolve_workspace() {
  if [[ -n "${CLI_ALERT_WORKSPACE:-}" ]]; then
    printf '%s' "$CLI_ALERT_WORKSPACE"; return
  fi
  if command -v git &>/dev/null; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null) && [[ -n "$root" ]] && printf '%s' "$root" && return
  fi
  printf '%s' "$PWD"
}

# ── Platform notification functions ──────────────────────────────────────────

_cli_alert_notify_darwin() {
  local title="$1" message="$2" exit_code="$3"
  _cli_alert_debug "darwin notifier: title='$title' exit=$exit_code"

  if ! _cli_alert_channel_enabled "desktop" 2>/dev/null; then
    _cli_alert_debug "desktop channel toggled off"
  elif command -v terminal-notifier &>/dev/null; then
    local tn_args=(-title "$title" -message "$message")

    # Click action: for VS Code, open the workspace URL to target the correct window.
    # For other terminals, activate the app by bundle ID.
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
      local workspace
      workspace="$(_cli_alert_resolve_workspace)"
      tn_args+=(-open "vscode://file${workspace}")
      _cli_alert_debug "open workspace on click: vscode://file${workspace}"
    else
      local activate
      activate="$(_cli_alert_resolve_activate)"
      tn_args+=(-activate "$activate")
      _cli_alert_debug "activate on click: $activate"
    fi

    if ! terminal-notifier "${tn_args[@]}" 2>/dev/null; then
      _cli_alert_warn_once DARWIN_TN "terminal-notifier failed — run 'cli-alert status' to diagnose"
    fi
  else
    # Fallback: osascript (no custom icon, no click-to-activate)
    local safe_title safe_message
    safe_title="$(_cli_alert_sanitize_applescript "$title")"
    safe_message="$(_cli_alert_sanitize_applescript "$message")"
    if ! osascript -e "display notification \"$safe_message\" with title \"$safe_title\"" 2>/dev/null; then
      _cli_alert_warn_once DARWIN_OSASCRIPT "osascript notification failed — run 'cli-alert status' to diagnose"
    fi
  fi

  # Sound (background with timeout)
  if _cli_alert_channel_enabled "sound" 2>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$CLI_ALERT_SOUND_SUCCESS"
    else
      sound="$CLI_ALERT_SOUND_FAILURE"
    fi
    _cli_alert_debug "sound: $sound"
    local sound_file
    if [[ "$sound" == */* ]]; then
      sound_file="$sound"
    else
      sound_file="/System/Library/Sounds/${sound}.aiff"
    fi
    if [[ -f "$sound_file" ]]; then
      _cli_alert_bg_timeout afplay "$sound_file"
    else
      _cli_alert_warn_once SOUND "sound file not found: $sound_file — try 'cli-alert sounds'"
    fi
  fi

  # TTS (optional, with timeout)
  if [[ "$CLI_ALERT_VOICE" == "true" ]] && _cli_alert_channel_enabled "voice" 2>/dev/null; then
    _cli_alert_bg_timeout say "$message"
  fi
}

_cli_alert_notify_linux() {
  local title="$1" message="$2" exit_code="$3"
  _cli_alert_debug "linux notifier: title='$title' exit=$exit_code"

  # Notification
  if ! _cli_alert_channel_enabled "desktop" 2>/dev/null; then
    _cli_alert_debug "desktop channel toggled off"
  elif command -v notify-send &>/dev/null; then
    # Try custom cli-alert icon, fall back to system theme icons
    local icon
    local lib_dir="${_CLI_ALERT_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    local custom_icon="${lib_dir}/../assets/linux/cli-alert.png"
    if [[ -f "$custom_icon" ]]; then
      icon="$(cd "$(dirname "$custom_icon")" && pwd)/cli-alert.png"
    elif [[ "$exit_code" -eq 0 ]]; then
      icon="dialog-information"
    else
      icon="dialog-error"
    fi
    notify-send --icon="$icon" "$title" "$message" 2>/dev/null
  else
    _cli_alert_warn_once LINUX_NOTIFY "notify-send not found (install libnotify-bin for desktop notifications)"
    _cli_alert_fallback "$title" "$message"
    return
  fi

  # Sound (background with timeout, try paplay → aplay → mpv)
  if _cli_alert_channel_enabled "sound" 2>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$CLI_ALERT_SOUND_SUCCESS"
    else
      sound="$CLI_ALERT_SOUND_FAILURE"
    fi
    _cli_alert_debug "sound: $sound"

    local sound_file
    if [[ "$sound" == */* ]]; then
      sound_file="$sound"
    else
      sound_file="/usr/share/sounds/freedesktop/stereo/${sound}.oga"
    fi
    if [[ -f "$sound_file" ]]; then
      if command -v paplay &>/dev/null; then
        _cli_alert_bg_timeout paplay "$sound_file"
      elif command -v aplay &>/dev/null; then
        _cli_alert_bg_timeout aplay "$sound_file"
      elif command -v mpv &>/dev/null; then
        _cli_alert_bg_timeout mpv --no-terminal "$sound_file"
      fi
    fi
  fi

  # TTS (optional, with timeout)
  if [[ "$CLI_ALERT_VOICE" == "true" ]] && _cli_alert_channel_enabled "voice" 2>/dev/null; then
    if command -v espeak &>/dev/null; then
      _cli_alert_bg_timeout espeak "$message"
    elif command -v spd-say &>/dev/null; then
      _cli_alert_bg_timeout spd-say "$message"
    fi
  fi
}

_cli_alert_notify_wsl() {
  local title="$1" message="$2" exit_code="$3"
  _cli_alert_debug "wsl notifier: title='$title' exit=$exit_code"

  # Notification: try BurntToast → wsl-notify-send → WinRT toast
  # Pass values via environment variables to avoid PowerShell injection
  if ! _cli_alert_channel_enabled "desktop" 2>/dev/null; then
    _cli_alert_debug "desktop channel toggled off"
  elif powershell.exe -Command "Get-Module -ListAvailable -Name BurntToast" &>/dev/null 2>&1; then
    CLI_ALERT_PS_TITLE="$title" CLI_ALERT_PS_MSG="$message" \
      powershell.exe -Command 'Import-Module BurntToast; New-BurntToastNotification -Text $env:CLI_ALERT_PS_TITLE, $env:CLI_ALERT_PS_MSG' 2>/dev/null
  elif command -v wsl-notify-send &>/dev/null; then
    wsl-notify-send --category "$title" "$message" 2>/dev/null
  elif command -v powershell.exe &>/dev/null; then
    CLI_ALERT_PS_TITLE="$title" CLI_ALERT_PS_MSG="$message" \
      powershell.exe -Command '
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $textNodes = $template.GetElementsByTagName("text")
        $textNodes.Item(0).AppendChild($template.CreateTextNode($env:CLI_ALERT_PS_TITLE)) > $null
        $textNodes.Item(1).AppendChild($template.CreateTextNode($env:CLI_ALERT_PS_MSG)) > $null
        $toast = [Windows.UI.Notifications.ToastNotification]::new($template)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("cli-alert").Show($toast)
      ' 2>/dev/null
  else
    _cli_alert_warn_once WSL_NOTIFY "no Windows notification tool found — run 'cli-alert status' to diagnose"
    _cli_alert_fallback "$title" "$message"
    return
  fi

  # Sound (background with timeout, via env var)
  if _cli_alert_channel_enabled "sound" 2>/dev/null && command -v powershell.exe &>/dev/null; then
    local sound
    if [[ "$exit_code" -eq 0 ]]; then
      sound="$CLI_ALERT_SOUND_SUCCESS"
    else
      sound="$CLI_ALERT_SOUND_FAILURE"
    fi
    _cli_alert_debug "sound: $sound"
    if [[ "$sound" == */* ]]; then
      CLI_ALERT_PS_SOUND="$sound" \
        _cli_alert_bg_timeout powershell.exe -Command '(New-Object Media.SoundPlayer ($env:CLI_ALERT_PS_SOUND)).PlaySync()'
    else
      CLI_ALERT_PS_SOUND="$sound" \
        _cli_alert_bg_timeout powershell.exe -Command '(New-Object Media.SoundPlayer ("C:\Windows\Media\Windows " + $env:CLI_ALERT_PS_SOUND + ".wav")).PlaySync()'
    fi
  fi

  # TTS (optional, via env var, with timeout)
  if [[ "$CLI_ALERT_VOICE" == "true" ]] && _cli_alert_channel_enabled "voice" 2>/dev/null && command -v powershell.exe &>/dev/null; then
    CLI_ALERT_PS_MSG="$message" \
      _cli_alert_bg_timeout powershell.exe -Command 'Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak($env:CLI_ALERT_PS_MSG)'
  fi
}

_cli_alert_notify_windows() {
  # Git Bash / MSYS2 / Cygwin — same approach as WSL but without wsl-notify-send
  _cli_alert_notify_wsl "$@"
}

# ── Fallback (terminal bell + stderr) ────────────────────────────────────────

_cli_alert_fallback() {
  local title="$1" message="$2"
  # Terminal bell
  printf '\a' >/dev/tty 2>/dev/null || printf '\a'
  # Colored stderr message
  printf '\033[1;33m[cli-alert]\033[0m %s: %s\n' "$title" "$message" >&2
}

# ── Terminal focus detection ──────────────────────────────────────────────────

_cli_alert_terminal_focused_darwin() {
  local frontmost
  frontmost=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null) || return 1
  local terminals="${CLI_ALERT_TERMINALS:-Terminal iTerm2 Alacritty kitty WezTerm Hyper}"
  local term
  for term in $terminals; do
    [[ "$frontmost" == "$term" ]] && return 0
  done
  return 1
}

_cli_alert_terminal_focused_linux() {
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

_cli_alert_terminal_focused() {
  [[ "$CLI_ALERT_FOCUS_DETECT" != "true" ]] && return 1
  case "$_CLI_ALERT_PLATFORM" in
    darwin)  _cli_alert_terminal_focused_darwin ;;
    linux)   _cli_alert_terminal_focused_linux ;;
    *)       return 1 ;;  # WSL/Windows: can't detect reliably
  esac
}

# ── Notification history log ──────────────────────────────────────────────────

_cli_alert_log_history() {
  local title="$1" message="$2" exit_code="$3"

  [[ "${CLI_ALERT_HISTORY:-true}" != "true" ]] && return 0

  local log_dir="${CLI_ALERT_HISTORY_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/cli-alert}"
  local log_file="${log_dir}/history.log"

  if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir" 2>/dev/null || return 0
  fi

  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  local channels="desktop"
  [[ -n "${CLI_ALERT_SLACK_WEBHOOK:-}" ]]   && channels+=",slack"
  [[ -n "${CLI_ALERT_DISCORD_WEBHOOK:-}" ]] && channels+=",discord"
  [[ -n "${CLI_ALERT_TELEGRAM_TOKEN:-}" ]]  && channels+=",telegram"
  [[ -n "${CLI_ALERT_EMAIL_TO:-}" ]]        && channels+=",email"
  [[ -n "${CLI_ALERT_WHATSAPP_TOKEN:-}" ]]  && channels+=",whatsapp"
  [[ -n "${CLI_ALERT_WEBHOOK_URL:-}" ]]     && channels+=",webhook"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$timestamp" "$title" "$message" "$exit_code" "$channels" \
    >> "$log_file" 2>/dev/null
}

# ── Main notification dispatcher ─────────────────────────────────────────────

_cli_alert_notify() {
  local title="$1" message="$2" exit_code="${3:-0}"

  # Validate exit code is numeric
  [[ "$exit_code" =~ ^[0-9]+$ ]] || exit_code=1

  [[ "$CLI_ALERT_ENABLED" != "true" ]] && return 0

  # Lazy-load state module
  if [[ -z "${_CLI_ALERT_STATE_LOADED:-}" ]]; then
    local _state_lib="${_CLI_ALERT_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/state.sh"
    [[ -f "$_state_lib" ]] && source "$_state_lib"
  fi

  # Mute / quiet hours check (full suppression — still logs to history)
  if _cli_alert_is_muted 2>/dev/null || _cli_alert_is_quiet_hours 2>/dev/null; then
    _cli_alert_debug "suppressed by mute or quiet hours"
    _cli_alert_log_history "$title" "$message" "$exit_code"
    return 0
  fi

  # Log to history
  _cli_alert_log_history "$title" "$message" "$exit_code"

  # External notifications (fire regardless of focus, non-blocking)
  if declare -f _cli_alert_notify_external &>/dev/null; then
    _cli_alert_notify_external "$title" "$message" "$exit_code"
  fi

  if _cli_alert_terminal_focused; then
    _cli_alert_debug "terminal focused, suppressing notification"
    return 0
  fi

  _cli_alert_debug "notify: title='$title' exit=$exit_code platform=$_CLI_ALERT_PLATFORM"

  case "$_CLI_ALERT_PLATFORM" in
    darwin)  _cli_alert_notify_darwin  "$title" "$message" "$exit_code" ;;
    linux)   _cli_alert_notify_linux   "$title" "$message" "$exit_code" ;;
    wsl)     _cli_alert_notify_wsl     "$title" "$message" "$exit_code" ;;
    windows) _cli_alert_notify_windows "$title" "$message" "$exit_code" ;;
    *)       _cli_alert_fallback       "$title" "$message" ;;
  esac
}

# ── `alert` wrapper command ──────────────────────────────────────────────────

alert() {
  # Parse flags
  local notify_on="${CLI_ALERT_NOTIFY_ON:-all}"
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
  # Truncate display name for notification
  if [[ ${#cmd_display} -gt 50 ]]; then
    cmd_display="${cmd_display:0:47}..."
  fi

  local start_seconds=$SECONDS

  # Run the command
  "$@"
  local exit_code=$?

  local elapsed=$((SECONDS - start_seconds))
  local duration
  duration=$(_cli_alert_format_duration "$elapsed")

  # Check notification filter
  if [[ "$notify_on" == "failure" && "$exit_code" -eq 0 ]]; then
    return $exit_code
  fi
  if [[ "$notify_on" == "success" && "$exit_code" -ne 0 ]]; then
    return $exit_code
  fi

  local status_icon
  status_icon="$(_cli_alert_status_icon "$exit_code")"

  local cmd_base="${1##*/}"
  _cli_alert_notify \
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
  duration=$(_cli_alert_format_duration "$elapsed")

  if [[ "$exit_code" == "unknown" ]]; then
    _cli_alert_notify \
      "Background Job Complete" \
      "? ${job_name} (${duration}, exit unknown)" \
      0
  else
    local status_icon
    status_icon="$(_cli_alert_status_icon "$exit_code")"
    _cli_alert_notify \
      "Background Job Complete" \
      "${status_icon} ${job_name} (${duration}, exit ${exit_code})" \
      "$exit_code"
  fi
}
