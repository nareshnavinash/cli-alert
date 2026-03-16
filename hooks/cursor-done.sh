#!/usr/bin/env bash
# cursor-done.sh — Cursor stop hook
# Sends a notification when Cursor finishes its turn.
# Configured in ~/.cursor/hooks.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "$(cd "$SCRIPT_DIR/../lib/cli-alert" && pwd)/ai-hook-common.sh"
_cli_alert_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract stop reason
stop_reason=""
if [[ -n "$input" ]]; then
  stop_reason=$(_cli_alert_hook_read_json_field "$input" "stop_reason")
fi

# Build notification message
message="Task complete"
if [[ -n "$stop_reason" ]]; then
  message="Task complete (${stop_reason})"
fi

_cli_alert_hook_notify "Cursor" "$message" 0
