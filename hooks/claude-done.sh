#!/usr/bin/env bash
# claude-done.sh - Claude Code Stop hook
# Sends a notification when Claude Code finishes its turn.
# Configured as a Claude Code hook (reads JSON event from stdin).

set -euo pipefail

# Resolve script directory and source shared hook library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_COMMON="${SCRIPT_DIR}/../lib/ai-hook-common.sh"
if [[ ! -f "$HOOK_COMMON" ]]; then
  # Installed layout: hooks in PREFIX/share/shelldone/hooks/, lib in PREFIX/lib/shelldone/
  HOOK_COMMON="${SCRIPT_DIR}/../../../lib/shelldone/ai-hook-common.sh"
fi
if [[ -f "$HOOK_COMMON" ]]; then
  source "$HOOK_COMMON"
  _shelldone_hook_resolve_lib "$SCRIPT_DIR"
else
  echo "shelldone: cannot find lib" >&2
  exit 1
fi

# Read the hook event JSON from stdin
input="$(cat)"

# Extract stop reason
stop_reason=""
if declare -f _shelldone_hook_read_json_field &>/dev/null; then
  stop_reason=$(_shelldone_hook_read_json_field "$input" "stop_reason")
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
  export _SHELLDONE_META_STOP_REASON="$stop_reason"
fi

# Determine exit code from stop reason
hook_exit=0
if declare -f _shelldone_hook_exit_code_for_reason &>/dev/null; then
  hook_exit=$(_shelldone_hook_exit_code_for_reason "$stop_reason")
fi

# Send notification (toggle-aware if available)
if declare -f _shelldone_hook_notify &>/dev/null; then
  _shelldone_hook_notify "Claude Code" "$message" "$hook_exit"
else
  _shelldone_notify "Claude Code" "$message" "$hook_exit"
fi
