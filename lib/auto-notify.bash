#!/usr/bin/env bash
# auto-notify.bash — Automatic notification for long-running commands in Bash
# Source this file in your .bashrc AFTER cli-alert.sh

# Guard against double-sourcing
[[ -n "${_CLI_ALERT_AUTO_BASH_LOADED:-}" ]] && return 0
_CLI_ALERT_AUTO_BASH_LOADED=1

# Ensure core is loaded
if [[ -z "${_CLI_ALERT_LOADED:-}" ]]; then
  _cli_alert_lib_dir="${_CLI_ALERT_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  source "${_cli_alert_lib_dir}/cli-alert.sh"
  unset _cli_alert_lib_dir
fi

# ── Config ───────────────────────────────────────────────────────────────────

CLI_ALERT_AUTO="${CLI_ALERT_AUTO:-true}"
CLI_ALERT_THRESHOLD="${CLI_ALERT_THRESHOLD:-10}"
CLI_ALERT_EXCLUDE="${CLI_ALERT_EXCLUDE:-vim nvim vi nano less more man top htop ssh tmux screen fg bg alert-bg watch}"

# ── State variables ──────────────────────────────────────────────────────────

_cli_alert_cmd_name=""
_cli_alert_cmd_start=""
_cli_alert_in_prompt_command=0

# ── DEBUG trap: record command start ─────────────────────────────────────────

_cli_alert_debug_trap() {
  # Don't record when PROMPT_COMMAND is running
  [[ "$_cli_alert_in_prompt_command" -eq 1 ]] && return

  [[ "$CLI_ALERT_AUTO" != "true" ]] && return

  # Only record the first command (not subshells/pipes)
  if [[ -z "$_cli_alert_cmd_start" ]]; then
    _cli_alert_cmd_name="${BASH_COMMAND%% *}"
    _cli_alert_cmd_name="${_cli_alert_cmd_name##*/}"
    _cli_alert_cmd_start=$SECONDS
  fi
}

# ── PROMPT_COMMAND: check duration and notify ────────────────────────────────

_cli_alert_prompt_command() {
  local last_exit=$?

  _cli_alert_in_prompt_command=1

  if [[ "$CLI_ALERT_AUTO" == "true" ]] && \
     [[ -n "$_cli_alert_cmd_name" ]] && \
     [[ -n "$_cli_alert_cmd_start" ]]; then

    local elapsed=$(( SECONDS - _cli_alert_cmd_start ))

    local cmd_name="$_cli_alert_cmd_name"

    # Reset state
    _cli_alert_cmd_name=""
    _cli_alert_cmd_start=""

    if (( elapsed >= CLI_ALERT_THRESHOLD )); then
      # Check exclusion list
      local excluded skip=0
      for excluded in $CLI_ALERT_EXCLUDE; do
        if [[ "$cmd_name" == $excluded ]]; then  # shellcheck disable=SC2053
          skip=1
          break
        fi
      done

      if [[ $skip -eq 0 ]]; then
        # Check notification filter
        local notify_on="${CLI_ALERT_NOTIFY_ON:-all}"
        if [[ "$notify_on" == "failure" && "$last_exit" -eq 0 ]]; then
          skip=1
        elif [[ "$notify_on" == "success" && "$last_exit" -ne 0 ]]; then
          skip=1
        fi
      fi

      if [[ $skip -eq 0 ]]; then
        local duration
        duration=$(_cli_alert_format_duration "$elapsed")

        local status_icon
        status_icon="$(_cli_alert_status_icon "$last_exit")"

        # Set metadata for enriched Slack messages
        export _CLI_ALERT_META_CMD="$cmd_name"
        export _CLI_ALERT_META_DURATION="$duration"
        export _CLI_ALERT_META_SOURCE="shell"

        _cli_alert_notify \
          "${cmd_name} Complete" \
          "${status_icon} ${cmd_name} (${duration}, exit ${last_exit})" \
          "$last_exit"
      fi
    fi
  else
    # No command was run (empty prompt), just reset
    _cli_alert_cmd_name=""
    _cli_alert_cmd_start=""
  fi

  _cli_alert_in_prompt_command=0
}

# ── Register hooks ────────────────────────────────────────────────────────────

# DEBUG trap must be set at the top level, not inside a function (bash scopes
# DEBUG trap changes inside functions when a parent trap exists). Setting it
# directly inside `source` also fails — bash restores the caller's DEBUG trap
# after source completes. Use PROMPT_COMMAND to defer trap installation to
# the first prompt cycle (top-level context).
#
# To chain with an existing DEBUG trap, we detect it via a temp file during
# the one-shot PROMPT_COMMAND installer (sed extracts the command from
# `trap -p` output — shell parameter expansion has quoting issues inside eval).

_cli_alert_trap_installed=""

# Append to PROMPT_COMMAND without overwriting
if [[ -z "${PROMPT_COMMAND:-}" ]]; then
  PROMPT_COMMAND="_cli_alert_prompt_command"
elif [[ "$PROMPT_COMMAND" != *"_cli_alert_prompt_command"* ]]; then
  PROMPT_COMMAND="_cli_alert_prompt_command;${PROMPT_COMMAND}"
fi

# Prepend one-shot trap installer (inline eval, not a function)
_cli_alert_do_install_trap='
if [[ -z "$_cli_alert_trap_installed" ]]; then
  _cli_alert_trap_installed=1
  _catf="/tmp/.cli_alert_trap_$$"
  trap -p DEBUG > "$_catf" 2>/dev/null
  if [[ -s "$_catf" ]]; then
    _cli_alert_old_cmd=$(sed -n "s/^trap -- .\\(.*\\). DEBUG$/\\1/p" "$_catf")
    if [[ -n "$_cli_alert_old_cmd" && "$_cli_alert_old_cmd" != *_cli_alert_debug_trap* ]]; then
      trap "${_cli_alert_old_cmd}; _cli_alert_debug_trap" DEBUG
    else
      trap "_cli_alert_debug_trap" DEBUG
    fi
    unset _cli_alert_old_cmd
  else
    trap "_cli_alert_debug_trap" DEBUG
  fi
  rm -f "$_catf" 2>/dev/null
  unset _catf
fi
'
PROMPT_COMMAND="eval \"\$_cli_alert_do_install_trap\";${PROMPT_COMMAND}"
