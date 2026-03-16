#!/usr/bin/env bash
# claude-notify.sh — Claude Code Notification hook
# Sends a notification when Claude Code fires a system notification
# (e.g., waiting for user input, context window full).
# Configured as a Claude Code hook (reads JSON event from stdin).

set -euo pipefail

# Resolve script directory and source shared hook library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_COMMON="${SCRIPT_DIR}/../lib/ai-hook-common.sh"
if [[ -f "$HOOK_COMMON" ]]; then
  source "$HOOK_COMMON"
  _cli_alert_hook_resolve_lib "$SCRIPT_DIR"
else
  # Fallback: try installed layout
  HOOK_COMMON="$(cd "$SCRIPT_DIR/../lib/cli-alert" && pwd)/ai-hook-common.sh" 2>/dev/null || true
  if [[ -f "$HOOK_COMMON" ]]; then
    source "$HOOK_COMMON"
    _cli_alert_hook_resolve_lib "$SCRIPT_DIR"
  else
    # Legacy fallback: resolve lib directly
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    if [[ -f "${BASE_DIR}/lib/cli-alert/cli-alert.sh" ]]; then
      source "${BASE_DIR}/lib/cli-alert/cli-alert.sh"
    elif [[ -f "${BASE_DIR}/lib/cli-alert.sh" ]]; then
      source "${BASE_DIR}/lib/cli-alert.sh"
    else
      echo "cli-alert: cannot find lib" >&2
      exit 1
    fi
  fi
fi

# Read the hook event JSON from stdin
input="$(cat)"

# Extract notification fields
title=""
message=""
if declare -f _cli_alert_hook_read_json_field &>/dev/null; then
  title=$(_cli_alert_hook_read_json_field "$input" "title")
  message=$(_cli_alert_hook_read_json_field "$input" "message")
elif command -v python3 &>/dev/null; then
  title=$(python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    print(data.get('title', ''))
except:
    print('')
" "$input" 2>/dev/null) || true
  message=$(python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    print(data.get('message', ''))
except:
    print('')
" "$input" 2>/dev/null) || true
fi

# Set metadata for enriched Slack messages
if [[ -n "$title" ]]; then
  export _CLI_ALERT_META_STOP_REASON="$title"
fi

# Build notification message
notify_msg="${message:-Notification}"
if [[ -n "$title" && -z "$message" ]]; then
  notify_msg="$title"
elif [[ -n "$title" && -n "$message" ]]; then
  notify_msg="${title}: ${message}"
fi

# Send notification (toggle-aware if available)
if declare -f _cli_alert_hook_notify &>/dev/null; then
  _cli_alert_hook_notify "Claude Code" "$notify_msg" 0
else
  _cli_alert_notify "Claude Code" "$notify_msg" 0
fi
