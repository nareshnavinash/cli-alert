#!/usr/bin/env bash
# gemini-notify.sh - Gemini CLI (Google) Notification hook
# Sends a notification when Gemini CLI fires a system notification.
# Configured in ~/.gemini/settings.json as a command hook.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ai-hook-common.sh" 2>/dev/null || \
  source "${SCRIPT_DIR}/../../../lib/shelldone/ai-hook-common.sh"
_shelldone_hook_resolve_lib "$SCRIPT_DIR"

# Read the hook event JSON from stdin
input="$(cat)"

# Extract notification fields
title=""
message=""
if [[ -n "$input" ]]; then
  title=$(_shelldone_hook_read_json_field "$input" "title")
  message=$(_shelldone_hook_read_json_field "$input" "message")
fi

# Set metadata for enriched Slack messages
if [[ -n "$title" ]]; then
  export _SHELLDONE_META_STOP_REASON="$title"
fi

# Build notification message
notify_msg="${message:-Notification}"
if [[ -n "$title" && -z "$message" ]]; then
  notify_msg="$title"
elif [[ -n "$title" && -n "$message" ]]; then
  notify_msg="${title}: ${message}"
fi

_shelldone_hook_notify "Gemini CLI" "$notify_msg" 0
