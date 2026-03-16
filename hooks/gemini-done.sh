#!/usr/bin/env bash
# gemini-done.sh — Gemini CLI (Google) command hook
# Sends a notification when Gemini CLI finishes its turn.
# Configured in ~/.gemini/settings.json as a command hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "$(cd "$SCRIPT_DIR/../lib/cli-alert" && pwd)/ai-hook-common.sh"
_cli_alert_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract event metadata
event_type=""
if [[ -n "$input" ]]; then
  event_type=$(_cli_alert_hook_read_json_field "$input" "type")
fi

# Build notification message
message="Task complete"
if [[ -n "$event_type" ]]; then
  message="Task complete (${event_type})"
  export _CLI_ALERT_META_STOP_REASON="$event_type"
fi

_cli_alert_hook_notify "Gemini CLI" "$message" 0
