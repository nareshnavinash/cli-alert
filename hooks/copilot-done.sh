#!/usr/bin/env bash
# copilot-done.sh — GitHub Copilot CLI sessionEnd hook
# Sends a notification when Copilot CLI finishes a session.
# Configured via ~/.github/hooks/cli-alert-session-end.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "$(cd "$SCRIPT_DIR/../lib/cli-alert" && pwd)/ai-hook-common.sh"
_cli_alert_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract session metadata
reason=""
if [[ -n "$input" ]]; then
  reason=$(_cli_alert_hook_read_json_field "$input" "reason")
fi

# Build notification message
message="Session complete"
if [[ -n "$reason" ]]; then
  message="Session complete (${reason})"
  export _CLI_ALERT_META_STOP_REASON="$reason"
fi

_cli_alert_hook_notify "Copilot CLI" "$message" 0
