#!/usr/bin/env bash
# cursor-done.sh — Cursor stop hook
# Sends a notification when Cursor finishes its turn.
# Configured in ~/.cursor/hooks.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "$(cd "$SCRIPT_DIR/../lib/shelldone" && pwd)/ai-hook-common.sh"
_shelldone_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract stop reason
stop_reason=""
if [[ -n "$input" ]]; then
  stop_reason=$(_shelldone_hook_read_json_field "$input" "stop_reason")
fi

# Build notification message
message="Task complete"
if [[ -n "$stop_reason" ]]; then
  message="Task complete (${stop_reason})"
  export _SHELLDONE_META_STOP_REASON="$stop_reason"
fi

# Determine exit code from stop reason
hook_exit=0
if declare -f _shelldone_hook_exit_code_for_reason &>/dev/null; then
  hook_exit=$(_shelldone_hook_exit_code_for_reason "$stop_reason")
fi

_shelldone_hook_notify "Cursor" "$message" "$hook_exit"
