#!/usr/bin/env bash
# claude-done.sh — Claude Code Stop hook
# Sends a notification when Claude Code finishes its turn.
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

# Extract stop reason
stop_reason=""
if declare -f _cli_alert_hook_read_json_field &>/dev/null; then
  stop_reason=$(_cli_alert_hook_read_json_field "$input" "stop_reason")
elif command -v python3 &>/dev/null; then
  stop_reason=$(python3 -c "
import sys, json
try:
    data = json.loads(sys.argv[1])
    print(data.get('stop_reason', ''))
except:
    print('')
" "$input" 2>/dev/null) || true
fi

# Build notification message
message="Task complete"
if [[ -n "$stop_reason" ]]; then
  message="Task complete (${stop_reason})"
fi

# Send notification (toggle-aware if available)
if declare -f _cli_alert_hook_notify &>/dev/null; then
  _cli_alert_hook_notify "Claude Code" "$message" 0
else
  _cli_alert_notify "Claude Code" "$message" 0
fi
