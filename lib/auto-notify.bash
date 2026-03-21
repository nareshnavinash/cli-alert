#!/usr/bin/env bash
# auto-notify.bash - Automatic notification for long-running commands in Bash
# Source this file in your .bashrc AFTER shelldone.sh

# Guard against double-sourcing
[[ -n "${_SHELLDONE_AUTO_BASH_LOADED:-}" ]] && return 0
_SHELLDONE_AUTO_BASH_LOADED=1

# Ensure core is loaded
if [[ -z "${_SHELLDONE_LOADED:-}" ]]; then
  _shelldone_lib_dir="${_SHELLDONE_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  source "${_shelldone_lib_dir}/shelldone.sh"
  unset _shelldone_lib_dir
fi

# ── Config ───────────────────────────────────────────────────────────────────

SHELLDONE_AUTO="${SHELLDONE_AUTO:-true}"
SHELLDONE_THRESHOLD="${SHELLDONE_THRESHOLD:-10}"
SHELLDONE_EXCLUDE="${SHELLDONE_EXCLUDE:-vim nvim vi nano less more man top htop ssh tmux screen fg bg alert-bg watch}"

# Suppress auto-notify in nested shells
if [[ "${SHELLDONE_NESTED_SHELL:-notify}" == "suppress" ]] && [[ "${SHLVL:-1}" -gt 1 ]]; then
  return 0
fi

# ── State variables ──────────────────────────────────────────────────────────

_shelldone_cmd_name=""
_shelldone_cmd_full=""
_shelldone_cmd_start=""
_shelldone_in_prompt_command=0

# ── DEBUG trap: record command start ─────────────────────────────────────────

_shelldone_debug_trap() {
  # Don't record when PROMPT_COMMAND is running
  [[ "$_shelldone_in_prompt_command" -eq 1 ]] && return

  [[ "$SHELLDONE_AUTO" != "true" ]] && return

  # Only record the first command (not subshells/pipes)
  if [[ -z "$_shelldone_cmd_start" ]]; then
    _shelldone_cmd_name="${BASH_COMMAND%% *}"
    _shelldone_cmd_name="${_shelldone_cmd_name##*/}"
    _shelldone_cmd_full="$BASH_COMMAND"
    if [[ ${#_shelldone_cmd_full} -gt 50 ]]; then
      _shelldone_cmd_full="${_shelldone_cmd_full:0:47}..."
    fi
    _shelldone_cmd_start=$SECONDS
  fi
}

# ── PROMPT_COMMAND: check duration and notify ────────────────────────────────

_shelldone_prompt_command() {
  local last_exit=$?

  _shelldone_in_prompt_command=1

  if [[ "$SHELLDONE_AUTO" == "true" ]] && \
     [[ -n "$_shelldone_cmd_name" ]] && \
     [[ -n "$_shelldone_cmd_start" ]]; then

    local elapsed=$(( SECONDS - _shelldone_cmd_start ))

    local cmd_name="$_shelldone_cmd_name"
    local cmd_full="${_shelldone_cmd_full:-$cmd_name}"

    # Reset state
    _shelldone_cmd_name=""
    _shelldone_cmd_full=""
    _shelldone_cmd_start=""

    if (( elapsed >= SHELLDONE_THRESHOLD )); then
      # Check exclusion list
      local excluded skip=0
      for excluded in $SHELLDONE_EXCLUDE; do
        if [[ "$cmd_name" == $excluded ]]; then  # shellcheck disable=SC2053
          skip=1
          break
        fi
      done

      if [[ $skip -eq 0 ]]; then
        # Check notification filter
        local notify_on="${SHELLDONE_NOTIFY_ON:-all}"
        if [[ "$notify_on" == "failure" && "$last_exit" -eq 0 ]]; then
          skip=1
        elif [[ "$notify_on" == "success" && "$last_exit" -ne 0 ]]; then
          skip=1
        fi
      fi

      if [[ $skip -eq 0 ]]; then
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
      fi
    fi
  else
    # No command was run (empty prompt), just reset
    _shelldone_cmd_name=""
    _shelldone_cmd_full=""
    _shelldone_cmd_start=""
  fi

  _shelldone_in_prompt_command=0
}

# ── Register hooks ────────────────────────────────────────────────────────────

# DEBUG trap must be set at the top level, not inside a function (bash scopes
# DEBUG trap changes inside functions when a parent trap exists). Setting it
# directly inside `source` also fails - bash restores the caller's DEBUG trap
# after source completes. Use PROMPT_COMMAND to defer trap installation to
# the first prompt cycle (top-level context).
#
# To chain with an existing DEBUG trap, we detect it via a temp file during
# the one-shot PROMPT_COMMAND installer (sed extracts the command from
# `trap -p` output - shell parameter expansion has quoting issues inside eval).

_shelldone_trap_installed=""

# Append to PROMPT_COMMAND without overwriting
if [[ -z "${PROMPT_COMMAND:-}" ]]; then
  PROMPT_COMMAND="_shelldone_prompt_command"
elif [[ "$PROMPT_COMMAND" != *"_shelldone_prompt_command"* ]]; then
  PROMPT_COMMAND="_shelldone_prompt_command;${PROMPT_COMMAND}"
fi

# Prepend one-shot trap installer (inline eval, not a function)
_shelldone_do_install_trap='
if [[ -z "$_shelldone_trap_installed" ]]; then
  _shelldone_trap_installed=1
  _catf="/tmp/.shelldone_trap_$$"
  trap -p DEBUG > "$_catf" 2>/dev/null
  if [[ -s "$_catf" ]]; then
    _shelldone_old_cmd=$(sed -n "s/^trap -- .\\(.*\\). DEBUG$/\\1/p" "$_catf")
    if [[ -n "$_shelldone_old_cmd" && "$_shelldone_old_cmd" != *_shelldone_debug_trap* ]]; then
      trap "${_shelldone_old_cmd}; _shelldone_debug_trap" DEBUG
    else
      trap "_shelldone_debug_trap" DEBUG
    fi
    unset _shelldone_old_cmd
  else
    trap "_shelldone_debug_trap" DEBUG
  fi
  rm -f "$_catf" 2>/dev/null
  unset _catf
fi
'
PROMPT_COMMAND="eval \"\$_shelldone_do_install_trap\";${PROMPT_COMMAND}"
