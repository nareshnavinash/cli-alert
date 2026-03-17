#!/usr/bin/env bash
# codex-done.sh — Codex CLI (OpenAI) Stop hook
# Sends a notification when Codex CLI finishes its turn.
# Configured in ~/.codex/config.json as an experimental hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "$(cd "$SCRIPT_DIR/../lib/shelldone" && pwd)/ai-hook-common.sh"
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

_shelldone_hook_notify "Codex CLI" "$message" 0
