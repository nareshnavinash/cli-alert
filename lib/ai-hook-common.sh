#!/usr/bin/env bash
# ai-hook-common.sh — Shared library for AI CLI hook scripts
# Sourced by hooks/*-done.sh to provide common JSON extraction
# and toggle-aware notification dispatch.

# Guard against double-sourcing
[[ -n "${_CLI_ALERT_HOOK_COMMON_LOADED:-}" ]] && return 0
_CLI_ALERT_HOOK_COMMON_LOADED=1

# ── Lib resolution ────────────────────────────────────────────────────────

_cli_alert_hook_resolve_lib() {
  local script_dir="$1"
  local base_dir
  base_dir="$(cd "$script_dir/.." && pwd)"

  if [[ -f "${base_dir}/lib/cli-alert/cli-alert.sh" ]]; then
    source "${base_dir}/lib/cli-alert/cli-alert.sh"
    local state_lib="${base_dir}/lib/cli-alert/state.sh"
    [[ -f "$state_lib" ]] && source "$state_lib"
  elif [[ -f "${base_dir}/lib/cli-alert.sh" ]]; then
    source "${base_dir}/lib/cli-alert.sh"
    local state_lib="${base_dir}/lib/state.sh"
    [[ -f "$state_lib" ]] && source "$state_lib"
  else
    echo "cli-alert: cannot find lib" >&2
    exit 1
  fi
}

# ── JSON field extraction ─────────────────────────────────────────────────

_cli_alert_hook_read_json_field() {
  local input="$1" field="$2"

  if ! command -v python3 &>/dev/null; then
    return 1
  fi

  python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    val = data.get(sys.argv[2], '')
    print(val)
except:
    print('')
" "$input" "$field" 2>/dev/null || true
}

# ── Toggle-aware notification ─────────────────────────────────────────────

_cli_alert_hook_notify() {
  local ai_name="$1" message="$2" exit_code="${3:-0}"
  local ai_key
  ai_key="$(printf '%s' "$ai_name" | tr '[:upper:] ' '[:lower:]-')"

  # Check per-AI toggle if state module is available
  if declare -f _cli_alert_state_read &>/dev/null; then
    local val
    val="$(_cli_alert_state_read "$ai_key" 2>/dev/null)" || val=""
    if [[ "$val" == "off" ]]; then
      return 0
    fi
  fi

  # Set metadata for enriched Slack messages
  export _CLI_ALERT_META_SOURCE="ai-hook"
  export _CLI_ALERT_META_AI_NAME="$ai_name"

  # Run external notifications synchronously in hook context — the parent
  # AI CLI may kill the process tree when the hook script exits, which would
  # terminate background HTTP requests before they complete.
  export _CLI_ALERT_HOOK_CONTEXT=true

  _cli_alert_notify "$ai_name" "$message" "$exit_code"
}
