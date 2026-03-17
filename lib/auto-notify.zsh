#!/usr/bin/env zsh
# auto-notify.zsh — Automatic notification for long-running commands in Zsh
# Source this file in your .zshrc AFTER shelldone.sh

# Guard against double-sourcing
[[ -n "${_SHELLDONE_AUTO_ZSH_LOADED:-}" ]] && return 0
_SHELLDONE_AUTO_ZSH_LOADED=1

# Ensure core is loaded
if [[ -z "${_SHELLDONE_LOADED:-}" ]]; then
  local script_dir="${_SHELLDONE_LIB:-${0:A:h}}"
  source "${script_dir}/shelldone.sh"
fi

# ── Config ───────────────────────────────────────────────────────────────────

SHELLDONE_AUTO="${SHELLDONE_AUTO:-true}"
SHELLDONE_THRESHOLD="${SHELLDONE_THRESHOLD:-10}"
SHELLDONE_EXCLUDE="${SHELLDONE_EXCLUDE:-vim nvim vi nano less more man top htop ssh tmux screen fg bg alert-bg watch}"

# ── State variables ──────────────────────────────────────────────────────────

typeset -g _shelldone_cmd_name=""
typeset -g _shelldone_cmd_full=""
typeset -g _shelldone_cmd_start=0

# ── Load epoch time ──────────────────────────────────────────────────────────

zmodload zsh/datetime 2>/dev/null

# ── Preexec: record command start ────────────────────────────────────────────

_shelldone_preexec() {
  [[ "$SHELLDONE_AUTO" != "true" ]] && return

  # Store command name (first word)
  _shelldone_cmd_name="${1%% *}"
  # Remove leading env vars, sudo, etc.
  _shelldone_cmd_name="${_shelldone_cmd_name##*/}"
  # Store full command (truncated to 50 chars)
  _shelldone_cmd_full="$1"
  if [[ ${#_shelldone_cmd_full} -gt 50 ]]; then
    _shelldone_cmd_full="${_shelldone_cmd_full:0:47}..."
  fi

  _shelldone_cmd_start=$EPOCHSECONDS
}

# ── Precmd: check duration and notify ────────────────────────────────────────

_shelldone_precmd() {
  local last_exit=$?

  [[ "$SHELLDONE_AUTO" != "true" ]] && return
  [[ -z "$_shelldone_cmd_name" ]] && return
  [[ "$_shelldone_cmd_start" -eq 0 ]] && return

  local elapsed=$(( EPOCHSECONDS - _shelldone_cmd_start ))

  # Reset state
  local cmd_name="$_shelldone_cmd_name"
  local cmd_full="${_shelldone_cmd_full:-$cmd_name}"
  _shelldone_cmd_name=""
  _shelldone_cmd_full=""
  _shelldone_cmd_start=0

  # Check threshold
  (( elapsed < SHELLDONE_THRESHOLD )) && return

  # Check exclusion list
  local excluded
  for excluded in ${=SHELLDONE_EXCLUDE}; do
    [[ "$cmd_name" == $excluded ]] && return  # shellcheck disable=SC2053
  done

  # Check notification filter
  local notify_on="${SHELLDONE_NOTIFY_ON:-all}"
  [[ "$notify_on" == "failure" && "$last_exit" -eq 0 ]] && return
  [[ "$notify_on" == "success" && "$last_exit" -ne 0 ]] && return

  # Format and notify
  local duration
  duration=$(_shelldone_format_duration "$elapsed")

  local status_icon
  status_icon="$(_shelldone_status_icon "$last_exit")"

  # Set metadata for enriched channel messages
  export _SHELLDONE_META_CMD="$cmd_full"
  export _SHELLDONE_META_DURATION="$duration"
  export _SHELLDONE_META_SOURCE="shell"

  _shelldone_notify \
    "${cmd_name} Complete" \
    "${status_icon} ${cmd_full} (${duration}, exit ${last_exit})" \
    "$last_exit"
}

# ── Register hooks (safe with other plugins) ─────────────────────────────────

autoload -Uz add-zsh-hook
add-zsh-hook preexec _shelldone_preexec
add-zsh-hook precmd _shelldone_precmd
