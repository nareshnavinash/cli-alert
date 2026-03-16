#!/usr/bin/env bash
# claude-done.sh — Claude Code Stop hook
# Sends a notification when Claude Code finishes its turn.
# Configured as a Claude Code hook (reads JSON event from stdin).

set -euo pipefail

# Resolve lib directory (works for both source and installed layouts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/cli-alert/cli-alert.sh" ]]; then
  source "${SCRIPT_DIR}/lib/cli-alert/cli-alert.sh"
elif [[ -f "${SCRIPT_DIR}/lib/cli-alert.sh" ]]; then
  source "${SCRIPT_DIR}/lib/cli-alert.sh"
else
  echo "cli-alert: cannot find lib" >&2
  exit 1
fi

# Read the hook event JSON from stdin
input="$(cat)"

# Extract stop reason if python3 is available
stop_reason=""
if command -v python3 &>/dev/null; then
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

_cli_alert_notify "Claude Code" "$message" 0
