#!/usr/bin/env bash
# gemini-done.sh - Gemini CLI (Google) command hook
# Sends a notification when Gemini CLI finishes its turn.
# Configured in ~/.gemini/settings.json as a command hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "${SCRIPT_DIR}/../../../lib/shelldone/ai-hook-common.sh"
_shelldone_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract event metadata
event_type=""
if [[ -n "$input" ]]; then
  event_type=$(_shelldone_hook_read_json_field "$input" "type")
fi

# Build notification message
message="Task complete"
if [[ -n "$event_type" ]]; then
  message="Task complete (${event_type})"
  export _SHELLDONE_META_STOP_REASON="$event_type"
fi

# Determine exit code from stop reason
hook_exit=0
if declare -f _shelldone_hook_exit_code_for_reason &>/dev/null; then
  hook_exit=$(_shelldone_hook_exit_code_for_reason "$event_type")
fi

_shelldone_hook_notify "Gemini CLI" "$message" "$hook_exit"
