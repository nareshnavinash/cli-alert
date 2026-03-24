#!/usr/bin/env bash
# codex-done.sh - Codex CLI (OpenAI) notify hook
# Sends a notification when Codex CLI finishes its turn (agent-turn-complete).
# Configured in ~/.codex/config.toml as: notify = ["/path/to/codex-done.sh"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "${SCRIPT_DIR}/../../../lib/shelldone/ai-hook-common.sh"
_shelldone_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract stop reason (same schema as Claude)
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

_shelldone_hook_notify "Codex CLI" "$message" "$hook_exit"
