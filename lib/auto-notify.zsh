#!/usr/bin/env zsh
# auto-notify.zsh — Automatic notification for long-running commands in Zsh
# Source this file in your .zshrc AFTER cli-alert.sh

# Guard against double-sourcing
[[ -n "${_CLI_ALERT_AUTO_ZSH_LOADED:-}" ]] && return 0
_CLI_ALERT_AUTO_ZSH_LOADED=1

# Ensure core is loaded
if [[ -z "${_CLI_ALERT_LOADED:-}" ]]; then
  local script_dir="${_CLI_ALERT_LIB:-${0:A:h}}"
  source "${script_dir}/cli-alert.sh"
fi

# ── Config ───────────────────────────────────────────────────────────────────

CLI_ALERT_AUTO="${CLI_ALERT_AUTO:-true}"
CLI_ALERT_THRESHOLD="${CLI_ALERT_THRESHOLD:-30}"
CLI_ALERT_EXCLUDE="${CLI_ALERT_EXCLUDE:-vim nvim vi nano less more man top htop ssh tmux screen fg bg alert-bg watch}"

# ── State variables ──────────────────────────────────────────────────────────

typeset -g _cli_alert_cmd_name=""
typeset -g _cli_alert_cmd_start=0

# ── Load epoch time ──────────────────────────────────────────────────────────

zmodload zsh/datetime 2>/dev/null

# ── Preexec: record command start ────────────────────────────────────────────

_cli_alert_preexec() {
  [[ "$CLI_ALERT_AUTO" != "true" ]] && return

  # Store command name (first word)
  _cli_alert_cmd_name="${1%% *}"
  # Remove leading env vars, sudo, etc.
  _cli_alert_cmd_name="${_cli_alert_cmd_name##*/}"

  _cli_alert_cmd_start=$EPOCHSECONDS
}

# ── Precmd: check duration and notify ────────────────────────────────────────

_cli_alert_precmd() {
  local last_exit=$?

  [[ "$CLI_ALERT_AUTO" != "true" ]] && return
  [[ -z "$_cli_alert_cmd_name" ]] && return
  [[ "$_cli_alert_cmd_start" -eq 0 ]] && return

  local elapsed=$(( EPOCHSECONDS - _cli_alert_cmd_start ))

  # Reset state
  local cmd_name="$_cli_alert_cmd_name"
  _cli_alert_cmd_name=""
  _cli_alert_cmd_start=0

  # Check threshold
  (( elapsed < CLI_ALERT_THRESHOLD )) && return

  # Check exclusion list
  local excluded
  for excluded in ${=CLI_ALERT_EXCLUDE}; do
    [[ "$cmd_name" == $excluded ]] && return  # shellcheck disable=SC2053
  done

  # Check notification filter
  local notify_on="${CLI_ALERT_NOTIFY_ON:-all}"
  [[ "$notify_on" == "failure" && "$last_exit" -eq 0 ]] && return
  [[ "$notify_on" == "success" && "$last_exit" -ne 0 ]] && return

  # Format and notify
  local duration
  duration=$(_cli_alert_format_duration "$elapsed")

  local status_icon
  status_icon="$(_cli_alert_status_icon "$last_exit")"

  _cli_alert_notify \
    "${cmd_name} Complete" \
    "${status_icon} ${cmd_name} (${duration}, exit ${last_exit})" \
    "$last_exit"
}

# ── Register hooks (safe with other plugins) ─────────────────────────────────

autoload -Uz add-zsh-hook
add-zsh-hook preexec _cli_alert_preexec
add-zsh-hook precmd _cli_alert_precmd
