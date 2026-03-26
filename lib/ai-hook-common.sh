#!/usr/bin/env bash
# ai-hook-common.sh - Shared library for AI CLI hook scripts
# Sourced by hooks/*-done.sh to provide common JSON extraction
# and toggle-aware notification dispatch.

# Guard against double-sourcing
[[ -n "${_SHELLDONE_HOOK_COMMON_LOADED:-}" ]] && return 0
_SHELLDONE_HOOK_COMMON_LOADED=1

# ── Lib resolution ────────────────────────────────────────────────────────

_shelldone_hook_resolve_lib() {
  local script_dir="$1"
  local base_dir
  base_dir="$(cd "$script_dir/.." && pwd)"

  if [[ -f "${base_dir}/lib/shelldone/shelldone.sh" ]]; then
    source "${base_dir}/lib/shelldone/shelldone.sh"
    local state_lib="${base_dir}/lib/shelldone/state.sh"
    [[ -f "$state_lib" ]] && source "$state_lib"
  elif [[ -f "${base_dir}/lib/shelldone.sh" ]]; then
    source "${base_dir}/lib/shelldone.sh"
    local state_lib="${base_dir}/lib/state.sh"
    [[ -f "$state_lib" ]] && source "$state_lib"
  else
    # Installed layout: hooks in PREFIX/share/shelldone/hooks/, lib in PREFIX/lib/shelldone/
    local prefix_dir
    prefix_dir="$(cd "$script_dir/../../.." 2>/dev/null && pwd)" || true
    if [[ -n "$prefix_dir" && -f "${prefix_dir}/lib/shelldone/shelldone.sh" ]]; then
      source "${prefix_dir}/lib/shelldone/shelldone.sh"
      local state_lib="${prefix_dir}/lib/shelldone/state.sh"
      [[ -f "$state_lib" ]] && source "$state_lib"
    else
      echo "shelldone: cannot find lib" >&2
      exit 1
    fi
  fi
}

# ── JSON field extraction ─────────────────────────────────────────────────

_shelldone_hook_read_json_field() {
  local input="$1" field="$2"

  # Pure-bash extraction for simple flat JSON (avoids python3 startup latency).
  # Matches "field": "value" — sufficient for AI CLI hook payloads.
  if [[ "$input" =~ \"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  # Fallback to python3 for nested/complex JSON
  if command -v python3 &>/dev/null; then
    python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    val = data.get(sys.argv[2], '')
    print(val)
except:
    print('')
" "$input" "$field" 2>/dev/null || true
  fi
}

# ── Exit code mapping for stop reasons ────────────────────────────────────

_shelldone_hook_exit_code_for_reason() {
  local reason="$1"
  case "$reason" in
    error|max_turns_reached|context_window_full|timeout)
      printf '1'
      ;;
    end_turn|stop_sequence|max_tokens|user_interrupt|"")
      printf '0'
      ;;
    *)
      # Unknown reason - default to success (safe fallback)
      printf '0'
      ;;
  esac
}

# ── Toggle-aware notification ─────────────────────────────────────────────

_shelldone_hook_notify() {
  local ai_name="$1" message="$2" exit_code="${3:-0}"
  local ai_key
  ai_key="$(printf '%s' "$ai_name" | tr '[:upper:] ' '[:lower:]-')"

  # Check per-AI toggle if state module is available
  if declare -f _shelldone_state_read &>/dev/null; then
    local val
    val="$(_shelldone_state_read "$ai_key" 2>/dev/null)" || val=""
    if [[ "$val" == "off" ]]; then
      return 0
    fi
  fi

  # Set metadata for enriched Slack messages
  export _SHELLDONE_META_SOURCE="ai-hook"
  export _SHELLDONE_META_AI_NAME="$ai_name"

  # Double-fork and detach: the notification runs in a fully independent
  # process so the hook script can exit immediately.  This prevents the
  # hook from blocking the parent AI CLI's terminal-restoration sequence,
  # which otherwise causes race-condition garbage ("7u") when the user
  # types quickly after the session ends.
  #
  # The inner subshell closes stdin/stdout/stderr and starts a new session
  # (via setsid where available) so the parent AI CLI cannot kill it when
  # the hook process tree is reaped.
  export _SHELLDONE_HOOK_CONTEXT=true
  (
    # Start new session if possible (survives parent process-group kill)
    if command -v setsid &>/dev/null; then
      setsid "$BASH" -c '
        export _SHELLDONE_HOOK_CONTEXT=true
        source "'"${_SHELLDONE_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}/shelldone.sh"'"
        _shelldone_notify "'"$ai_name"'" "'"$message"'" "'"$exit_code"'"
      ' </dev/null >/dev/null 2>/dev/null &
    else
      # macOS lacks setsid; double-fork + disown is sufficient since
      # Claude Code sends SIGTERM to the direct child, not the full tree
      _shelldone_notify "$ai_name" "$message" "$exit_code"
    fi
  ) </dev/null >/dev/null 2>/dev/null &
  disown 2>/dev/null
}
