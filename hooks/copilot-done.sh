#!/usr/bin/env bash
# copilot-done.sh — GitHub Copilot CLI sessionEnd hook
# Sends a notification when Copilot CLI finishes a session.
# Configured via ~/.github/hooks/shelldone-session-end.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "${SCRIPT_DIR}/../../../lib/shelldone/ai-hook-common.sh"
_shelldone_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract session metadata
reason=""
if [[ -n "$input" ]]; then
  reason=$(_shelldone_hook_read_json_field "$input" "reason")
fi

# Build notification message
message="Task complete"
if [[ -n "$reason" ]]; then
  message="Task complete (${reason})"
  export _SHELLDONE_META_STOP_REASON="$reason"
fi

# Determine exit code from stop reason
hook_exit=0
if declare -f _shelldone_hook_exit_code_for_reason &>/dev/null; then
  hook_exit=$(_shelldone_hook_exit_code_for_reason "$reason")
fi

_shelldone_hook_notify "Copilot CLI" "$message" "$hook_exit"
