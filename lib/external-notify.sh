#!/usr/bin/env bash
# external-notify.sh — External notification channels for shelldone
# Loaded lazily only when at least one external channel env var is set.

# Guard against double-sourcing
[[ -n "${_SHELLDONE_EXTERNAL_LOADED:-}" ]] && return 0
_SHELLDONE_EXTERNAL_LOADED=1

# ── Global defaults ─────────────────────────────────────────────────────────

SHELLDONE_WEBHOOK_TIMEOUT="${SHELLDONE_WEBHOOK_TIMEOUT:-5}"
SHELLDONE_RATE_LIMIT="${SHELLDONE_RATE_LIMIT:-10}"
SHELLDONE_EXTERNAL_DEBUG="${SHELLDONE_EXTERNAL_DEBUG:-false}"

# ── Debug helper ────────────────────────────────────────────────────────────

_shelldone_external_debug() {
  if [[ "$SHELLDONE_EXTERNAL_DEBUG" == "true" ]]; then
    printf '[shelldone:external] %s\n' "$*" >&2
  fi
}

# ── Pure-bash JSON string escaping ──────────────────────────────────────────

_shelldone_json_escape() {
  local str="$1"
  # Fast path: no special chars
  if [[ "$str" != *[\"\\]* && "$str" != *$'\n'* && "$str" != *$'\r'* && "$str" != *$'\t'* ]]; then
    printf '%s' "$str"
    return
  fi
  local i char result=""
  for (( i=0; i<${#str}; i++ )); do
    char="${str:i:1}"
    case "$char" in
      '"')   result+='\"' ;;
      '\')   result+='\\' ;;
      $'\n') result+='\n' ;;
      $'\r') result+='\r' ;;
      $'\t') result+='\t' ;;
      *)     result+="$char" ;;
    esac
  done
  printf '%s' "$result"
}

# ── URL parsing ─────────────────────────────────────────────────────────────

_shelldone_parse_url() {
  local url="$1"
  _PARSED_SCHEME="" _PARSED_HOST="" _PARSED_PORT="" _PARSED_PATH=""

  # Extract scheme
  if [[ "$url" == https://* ]]; then
    _PARSED_SCHEME="https"
    url="${url#https://}"
  elif [[ "$url" == http://* ]]; then
    _PARSED_SCHEME="http"
    url="${url#http://}"
  else
    return 1
  fi

  # Extract path
  _PARSED_PATH="/${url#*/}"
  local hostport="${url%%/*}"

  # Extract host and port
  if [[ "$hostport" == *:* ]]; then
    _PARSED_HOST="${hostport%%:*}"
    _PARSED_PORT="${hostport##*:}"
  else
    _PARSED_HOST="$hostport"
    if [[ "$_PARSED_SCHEME" == "https" ]]; then
      _PARSED_PORT=443
    else
      _PARSED_PORT=80
    fi
  fi
}

# ── HTTP transport detection ────────────────────────────────────────────────

_shelldone_detect_http_transport() {
  if command -v curl &>/dev/null; then
    _SHELLDONE_HTTP_TRANSPORT="curl"
  elif command -v wget &>/dev/null; then
    _SHELLDONE_HTTP_TRANSPORT="wget"
  elif [[ -e /dev/tcp ]]; then
    _SHELLDONE_HTTP_TRANSPORT="tcp"
  else
    # Try /dev/tcp by attempting a connection — bash may support it even without the file
    _SHELLDONE_HTTP_TRANSPORT="tcp"
  fi
  _shelldone_external_debug "HTTP transport: $_SHELLDONE_HTTP_TRANSPORT"
}

_shelldone_detect_http_transport

# ── HTTP POST backends ──────────────────────────────────────────────────────

_shelldone_http_post_curl() {
  local url="$1" payload="$2" extra_headers="$3"
  local -a cmd=(curl -sS -o /dev/null -w '%{http_code}' -X POST
    --max-time "$SHELLDONE_WEBHOOK_TIMEOUT"
    -H "Content-Type: application/json")

  if [[ -n "$extra_headers" ]]; then
    local IFS='|'
    local hdr
    for hdr in $extra_headers; do
      [[ -n "$hdr" ]] && cmd+=(-H "$hdr")
    done
  fi

  cmd+=(-d "$payload" "$url")
  local http_code
  local _curl_err_file
  _curl_err_file=$(mktemp 2>/dev/null || echo "/tmp/.shelldone_curl_err_$$")
  http_code=$("${cmd[@]}" 2>"$_curl_err_file") || true
  _SHELLDONE_LAST_CURL_ERROR=""
  if [[ -f "$_curl_err_file" ]]; then
    _SHELLDONE_LAST_CURL_ERROR=$(cat "$_curl_err_file" 2>/dev/null)
    rm -f "$_curl_err_file" 2>/dev/null
  fi
  [[ -n "$_SHELLDONE_LAST_CURL_ERROR" ]] && _shelldone_external_debug "curl stderr: $_SHELLDONE_LAST_CURL_ERROR"
  _SHELLDONE_LAST_HTTP_STATUS="$http_code"
  [[ "$http_code" =~ ^2[0-9][0-9]$ ]]
}

_shelldone_http_post_wget() {
  local url="$1" payload="$2" extra_headers="$3"
  local -a cmd=(wget -qO- --timeout="$SHELLDONE_WEBHOOK_TIMEOUT"
    --header="Content-Type: application/json"
    --post-data="$payload")

  if [[ -n "$extra_headers" ]]; then
    local IFS='|'
    local hdr
    for hdr in $extra_headers; do
      [[ -n "$hdr" ]] && cmd+=(--header="$hdr")
    done
  fi

  cmd+=("$url")
  _SHELLDONE_LAST_HTTP_STATUS="unknown"
  "${cmd[@]}" 2>/dev/null
}

_shelldone_http_post_tcp() {
  local url="$1" payload="$2" extra_headers="$3"

  _shelldone_parse_url "$url" || return 1

  if [[ "$_PARSED_SCHEME" == "https" ]]; then
    _shelldone_warn_once HTTPS_TRANSPORT "curl or wget required for HTTPS channels (Slack/Discord/Telegram). Install curl for external notifications."
    return 1
  fi

  local content_length=${#payload}
  local request="POST ${_PARSED_PATH} HTTP/1.1\r\nHost: ${_PARSED_HOST}\r\nContent-Type: application/json\r\nContent-Length: ${content_length}\r\nConnection: close\r\n"

  if [[ -n "$extra_headers" ]]; then
    local IFS='|'
    local hdr
    for hdr in $extra_headers; do
      [[ -n "$hdr" ]] && request+="${hdr}\r\n"
    done
  fi

  request+="\r\n${payload}"

  exec 3<>/dev/tcp/"$_PARSED_HOST"/"$_PARSED_PORT" 2>/dev/null || return 1
  printf '%b' "$request" >&3
  cat <&3 >/dev/null 2>&1
  exec 3>&-
}

# ── Unified HTTP POST dispatcher ────────────────────────────────────────────

_shelldone_http_post() {
  local url="$1" payload="$2" headers="${3:-}"

  _shelldone_external_debug "POST $(_shelldone_redact_url "$url")"

  case "$_SHELLDONE_HTTP_TRANSPORT" in
    curl) _shelldone_http_post_curl "$url" "$payload" "$headers" ;;
    wget) _shelldone_http_post_wget "$url" "$payload" "$headers" ;;
    tcp)  _shelldone_http_post_tcp  "$url" "$payload" "$headers" ;;
    *)    return 1 ;;
  esac
}

# ── Rate limiting ───────────────────────────────────────────────────────────

_shelldone_rate_limit_check() {
  [[ "${_SHELLDONE_SKIP_RATE_LIMIT:-}" == "true" ]] && return 0
  local channel="$1"
  local stamp_file="/tmp/.shelldone_rate_${channel}_$$_stamp"
  # Use a shared stamp file (not per-PID) for rate limiting across subshells
  stamp_file="/tmp/.shelldone_rate_${channel}"

  if [[ ! -f "$stamp_file" ]]; then
    return 0  # No stamp = not rate-limited
  fi

  local last_sent now
  last_sent=$(cat "$stamp_file" 2>/dev/null) || return 0
  now=$(date +%s)

  local elapsed=$(( now - last_sent ))
  if (( elapsed < SHELLDONE_RATE_LIMIT )); then
    _shelldone_external_debug "rate limited: $channel (${elapsed}s < ${SHELLDONE_RATE_LIMIT}s)"
    return 1
  fi
  return 0
}

_shelldone_rate_limit_update() {
  local channel="$1"
  local stamp_file="/tmp/.shelldone_rate_${channel}"
  date +%s > "$stamp_file" 2>/dev/null
}

# ── URL redaction for debug logging ─────────────────────────────────────────

_shelldone_redact_url() {
  local url="$1"
  # Keep scheme + host, replace path with <redacted>
  if [[ "$url" =~ ^(https?://[^/]+) ]]; then
    printf '%s/<redacted>' "${BASH_REMATCH[1]}"
  else
    printf '<redacted-url>'
  fi
}

# ── Metadata collection ─────────────────────────────────────────────────────

_shelldone_collect_metadata() {
  # Hostname
  _SHELLDONE_META_HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo "unknown")}"

  # Working directory
  _SHELLDONE_META_PWD="${PWD:-$(pwd 2>/dev/null || echo "")}"

  # Project name: git root basename or PWD basename
  local git_root
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$git_root" ]]; then
    _SHELLDONE_META_PROJECT="${git_root##*/}"
  else
    _SHELLDONE_META_PROJECT="${_SHELLDONE_META_PWD##*/}"
  fi

  # Git branch (optional, graceful skip)
  _SHELLDONE_META_GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
}

# ── Metadata cleanup ───────────────────────────────────────────────────────

_shelldone_clear_metadata() {
  unset _SHELLDONE_META_CMD _SHELLDONE_META_DURATION _SHELLDONE_META_SOURCE
  unset _SHELLDONE_META_AI_NAME _SHELLDONE_META_STOP_REASON
  unset _SHELLDONE_META_HOSTNAME _SHELLDONE_META_PWD
  unset _SHELLDONE_META_PROJECT _SHELLDONE_META_GIT_BRANCH
}

# ── Channel: Slack ──────────────────────────────────────────────────────────

_shelldone_external_slack() {
  local title="$1" message="$2" exit_code="$3"

  _shelldone_rate_limit_check "slack" || return 0

  local safe_title safe_message
  safe_title="$(_shelldone_json_escape "$title")"
  safe_message="$(_shelldone_json_escape "$message")"

  local color
  if [[ "$exit_code" -eq 0 ]]; then
    color="#36a64f"
  else
    color="#dc3545"
  fi

  local username="${SHELLDONE_SLACK_USERNAME:-shelldone}"
  local safe_username
  safe_username="$(_shelldone_json_escape "$username")"

  local payload
  if [[ "${SHELLDONE_SLACK_BLOCKS:-true}" == "true" ]]; then
    payload="$(_shelldone_slack_blocks_payload "$title" "$message" "$exit_code" "$color" "$safe_username")"
  else
    payload="{\"username\":\"${safe_username}\""
    if [[ -n "${SHELLDONE_SLACK_CHANNEL:-}" ]]; then
      local safe_channel
      safe_channel="$(_shelldone_json_escape "$SHELLDONE_SLACK_CHANNEL")"
      payload+=",\"channel\":\"${safe_channel}\""
    fi
    payload+=",\"attachments\":[{\"color\":\"${color}\",\"title\":\"${safe_title}\",\"text\":\"${safe_message}\"}]}"
  fi

  if _shelldone_http_post "$SHELLDONE_SLACK_WEBHOOK" "$payload"; then
    _shelldone_rate_limit_update "slack"
    _shelldone_external_debug "slack notification sent"
  else
    _shelldone_external_debug "slack notification FAILED (HTTP ${_SHELLDONE_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

_shelldone_slack_blocks_payload() {
  local title="$1" message="$2" exit_code="$3" color="$4" safe_username="$5"

  # Status emoji
  local emoji
  if [[ "$exit_code" -eq 0 ]]; then emoji="✅"; else emoji="❌"; fi

  local safe_title
  safe_title="$(_shelldone_json_escape "${emoji} ${title}")"

  # Collect environment metadata
  _shelldone_collect_metadata

  # Build section fields (2-column grid)
  local fields=""

  if [[ "${_SHELLDONE_META_SOURCE:-}" == "ai-hook" ]]; then
    # AI hook variant
    local status_text="Task complete"
    if [[ -n "${_SHELLDONE_META_STOP_REASON:-}" ]]; then
      local safe_reason
      safe_reason="$(_shelldone_json_escape "${_SHELLDONE_META_STOP_REASON}")"
      status_text="Task complete\\n(${safe_reason})"
    fi
    fields="{\"type\":\"mrkdwn\",\"text\":\"*Status*\\n${status_text}\"}"
    local ai_source="AI Hook"
    if [[ -n "${_SHELLDONE_META_AI_NAME:-}" ]]; then
      ai_source="$(_shelldone_json_escape "${_SHELLDONE_META_AI_NAME}")"
    fi
    fields+=",{\"type\":\"mrkdwn\",\"text\":\"*Source*\\n🤖 ${ai_source}\"}"
    if [[ -n "${USER:-}" ]]; then
      local safe_user
      safe_user="$(_shelldone_json_escape "$USER")"
      fields+=",{\"type\":\"mrkdwn\",\"text\":\"*User*\\n${safe_user}\"}"
    fi
  else
    # Shell command variant
    if [[ -n "${_SHELLDONE_META_CMD:-}" ]]; then
      local safe_cmd
      safe_cmd="$(_shelldone_json_escape "${_SHELLDONE_META_CMD}")"
      fields="{\"type\":\"mrkdwn\",\"text\":\"*Command*\\n${safe_cmd}\"}"
    fi
    if [[ -n "${_SHELLDONE_META_DURATION:-}" ]]; then
      local safe_dur
      safe_dur="$(_shelldone_json_escape "${_SHELLDONE_META_DURATION}")"
      [[ -n "$fields" ]] && fields+=","
      fields+="{\"type\":\"mrkdwn\",\"text\":\"*Duration*\\n${safe_dur}\"}"
    fi
    local safe_exit
    safe_exit="$(_shelldone_json_escape "$exit_code")"
    [[ -n "$fields" ]] && fields+=","
    fields+="{\"type\":\"mrkdwn\",\"text\":\"*Exit Code*\\n${safe_exit}\"}"
    if [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]; then
      local safe_proj
      safe_proj="$(_shelldone_json_escape "${_SHELLDONE_META_PROJECT}")"
      fields+=",{\"type\":\"mrkdwn\",\"text\":\"*Project*\\n${safe_proj}\"}"
    fi
    if [[ -n "${USER:-}" ]]; then
      local safe_user
      safe_user="$(_shelldone_json_escape "$USER")"
      fields+=",{\"type\":\"mrkdwn\",\"text\":\"*User*\\n${safe_user}\"}"
    fi
  fi

  # Build context line: hostname | directory | git branch
  local context_parts=""
  if [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]]; then
    local safe_host
    safe_host="$(_shelldone_json_escape "${_SHELLDONE_META_HOSTNAME}")"
    context_parts="💻 ${safe_host}"
  fi
  if [[ -n "${_SHELLDONE_META_PWD:-}" ]]; then
    # Shorten home dir to ~
    local display_pwd="${_SHELLDONE_META_PWD}"
    if [[ -n "${HOME:-}" && "$display_pwd" == "${HOME}"* ]]; then
      display_pwd="~${display_pwd#"${HOME}"}"
    fi
    local safe_pwd
    safe_pwd="$(_shelldone_json_escape "$display_pwd")"
    [[ -n "$context_parts" ]] && context_parts+=" | "
    context_parts+="📂 ${safe_pwd}"
  fi
  if [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]]; then
    local safe_branch
    safe_branch="$(_shelldone_json_escape "${_SHELLDONE_META_GIT_BRANCH}")"
    [[ -n "$context_parts" ]] && context_parts+=" | "
    context_parts+="🌿 ${safe_branch}"
  fi
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M' 2>/dev/null || true)"
  if [[ -n "$timestamp" ]]; then
    local safe_ts
    safe_ts="$(_shelldone_json_escape "$timestamp")"
    [[ -n "$context_parts" ]] && context_parts+=" | "
    context_parts+="🕐 ${safe_ts}"
  fi

  # Assemble blocks
  local blocks=""
  # Header block
  blocks="{\"type\":\"header\",\"text\":{\"type\":\"plain_text\",\"text\":\"${safe_title}\",\"emoji\":true}}"
  # Section with fields
  if [[ -n "$fields" ]]; then
    blocks+=",{\"type\":\"section\",\"fields\":[${fields}]}"
  fi
  # Context block
  if [[ -n "$context_parts" ]]; then
    local safe_context
    safe_context="$(_shelldone_json_escape "$context_parts")"
    blocks+=",{\"type\":\"context\",\"elements\":[{\"type\":\"mrkdwn\",\"text\":\"${safe_context}\"}]}"
  fi

  # Wrap in attachments for colored sidebar, with legacy fallback fields
  local safe_fallback_message
  safe_fallback_message="$(_shelldone_json_escape "$message")"
  local safe_fallback_title
  safe_fallback_title="$(_shelldone_json_escape "$title")"

  local payload="{\"username\":\"${safe_username}\""
  if [[ -n "${SHELLDONE_SLACK_CHANNEL:-}" ]]; then
    local safe_channel
    safe_channel="$(_shelldone_json_escape "$SHELLDONE_SLACK_CHANNEL")"
    payload+=",\"channel\":\"${safe_channel}\""
  fi
  payload+=",\"text\":\"${safe_fallback_title} - ${safe_fallback_message}\""
  payload+=",\"blocks\":[${blocks}]"
  payload+=",\"attachments\":[{\"color\":\"${color}\"}]}"

  printf '%s' "$payload"
}

# ── Channel: Discord ────────────────────────────────────────────────────────

_shelldone_external_discord() {
  local title="$1" message="$2" exit_code="$3"

  _shelldone_rate_limit_check "discord" || return 0

  # Status emoji prefix
  local emoji
  if [[ "$exit_code" -eq 0 ]]; then emoji="✅"; else emoji="❌"; fi

  local safe_title safe_message
  safe_title="$(_shelldone_json_escape "${emoji} ${title}")"
  safe_message="$(_shelldone_json_escape "$message")"

  local color
  if [[ "$exit_code" -eq 0 ]]; then
    color=3583835  # green
  else
    color=14431557  # red
  fi

  local username="${SHELLDONE_DISCORD_USERNAME:-shelldone}"
  local safe_username
  safe_username="$(_shelldone_json_escape "$username")"

  # Collect metadata for fields
  _shelldone_collect_metadata

  # Build fields array
  local fields=""
  if [[ "${_SHELLDONE_META_SOURCE:-}" == "ai-hook" ]]; then
    local status_text="Task complete"
    if [[ -n "${_SHELLDONE_META_STOP_REASON:-}" ]]; then
      local safe_reason
      safe_reason="$(_shelldone_json_escape "${_SHELLDONE_META_STOP_REASON}")"
      status_text="Task complete (${safe_reason})"
    fi
    fields="{\"name\":\"Status\",\"value\":\"${status_text}\",\"inline\":true}"
    local ai_source="AI Hook"
    if [[ -n "${_SHELLDONE_META_AI_NAME:-}" ]]; then
      ai_source="$(_shelldone_json_escape "${_SHELLDONE_META_AI_NAME}")"
    fi
    fields+=",{\"name\":\"Source\",\"value\":\"🤖 ${ai_source}\",\"inline\":true}"
  else
    if [[ -n "${_SHELLDONE_META_CMD:-}" ]]; then
      local safe_cmd
      safe_cmd="$(_shelldone_json_escape "${_SHELLDONE_META_CMD}")"
      fields="{\"name\":\"Command\",\"value\":\"${safe_cmd}\",\"inline\":true}"
    fi
    if [[ -n "${_SHELLDONE_META_DURATION:-}" ]]; then
      local safe_dur
      safe_dur="$(_shelldone_json_escape "${_SHELLDONE_META_DURATION}")"
      [[ -n "$fields" ]] && fields+=","
      fields+="{\"name\":\"Duration\",\"value\":\"${safe_dur}\",\"inline\":true}"
    fi
    local safe_exit
    safe_exit="$(_shelldone_json_escape "$exit_code")"
    [[ -n "$fields" ]] && fields+=","
    fields+="{\"name\":\"Exit Code\",\"value\":\"${safe_exit}\",\"inline\":true}"
    if [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]; then
      local safe_proj
      safe_proj="$(_shelldone_json_escape "${_SHELLDONE_META_PROJECT}")"
      [[ -n "$fields" ]] && fields+=","
      fields+="{\"name\":\"Project\",\"value\":\"${safe_proj}\",\"inline\":true}"
    fi
  fi

  # Build footer
  local footer_parts=""
  [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]] && footer_parts="${_SHELLDONE_META_HOSTNAME}"
  if [[ -n "${_SHELLDONE_META_PWD:-}" ]]; then
    local display_pwd="${_SHELLDONE_META_PWD}"
    if [[ -n "${HOME:-}" && "$display_pwd" == "${HOME}"* ]]; then
      display_pwd="~${display_pwd#"${HOME}"}"
    fi
    [[ -n "$footer_parts" ]] && footer_parts+=" | "
    footer_parts+="$display_pwd"
  fi
  if [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]]; then
    [[ -n "$footer_parts" ]] && footer_parts+=" | "
    footer_parts+="${_SHELLDONE_META_GIT_BRANCH}"
  fi
  local safe_footer
  safe_footer="$(_shelldone_json_escape "$footer_parts")"

  # ISO 8601 timestamp (Discord renders in user's timezone)
  local iso_ts
  iso_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"

  # Build embed
  local embed="{\"title\":\"${safe_title}\",\"description\":\"${safe_message}\",\"color\":${color}"
  if [[ -n "$fields" ]]; then
    embed+=",\"fields\":[${fields}]"
  fi
  if [[ -n "$safe_footer" ]]; then
    embed+=",\"footer\":{\"text\":\"${safe_footer}\"}"
  fi
  if [[ -n "$iso_ts" ]]; then
    embed+=",\"timestamp\":\"${iso_ts}\""
  fi
  embed+="}"

  local payload="{\"username\":\"${safe_username}\",\"embeds\":[${embed}]}"

  if _shelldone_http_post "$SHELLDONE_DISCORD_WEBHOOK" "$payload"; then
    _shelldone_rate_limit_update "discord"
    _shelldone_external_debug "discord notification sent"
  else
    _shelldone_external_debug "discord notification FAILED (HTTP ${_SHELLDONE_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Telegram ───────────────────────────────────────────────────────

_shelldone_external_telegram() {
  local title="$1" message="$2" exit_code="$3"

  if [[ -z "${SHELLDONE_TELEGRAM_CHAT_ID:-}" ]]; then
    _shelldone_external_debug "telegram: missing SHELLDONE_TELEGRAM_CHAT_ID"
    return 1
  fi

  _shelldone_rate_limit_check "telegram" || return 0

  local safe_chat_id
  safe_chat_id="$(_shelldone_json_escape "$SHELLDONE_TELEGRAM_CHAT_ID")"

  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="✅"; else icon="❌"; fi

  # Collect metadata for structured lines
  _shelldone_collect_metadata

  # Build HTML-formatted text
  local safe_title
  safe_title="$(_shelldone_json_escape "$title")"
  local text="${icon} <b>${safe_title}</b>"

  # Add structured fields
  if [[ "${_SHELLDONE_META_SOURCE:-}" == "ai-hook" ]]; then
    local status_text="Task complete"
    if [[ -n "${_SHELLDONE_META_STOP_REASON:-}" ]]; then
      local safe_reason
      safe_reason="$(_shelldone_json_escape "${_SHELLDONE_META_STOP_REASON}")"
      status_text="Task complete (${safe_reason})"
    fi
    text+="\\n\\n<b>Status:</b> ${status_text}"
    local ai_source="AI Hook"
    if [[ -n "${_SHELLDONE_META_AI_NAME:-}" ]]; then
      ai_source="$(_shelldone_json_escape "${_SHELLDONE_META_AI_NAME}")"
    fi
    text+="\\n<b>Source:</b> 🤖 ${ai_source}"
  else
    if [[ -n "${_SHELLDONE_META_CMD:-}" ]]; then
      local safe_cmd
      safe_cmd="$(_shelldone_json_escape "${_SHELLDONE_META_CMD}")"
      text+="\\n\\n<b>Command:</b> ${safe_cmd}"
    fi
    if [[ -n "${_SHELLDONE_META_DURATION:-}" ]]; then
      local safe_dur
      safe_dur="$(_shelldone_json_escape "${_SHELLDONE_META_DURATION}")"
      text+="\\n<b>Duration:</b> ${safe_dur}"
    fi
    local safe_exit
    safe_exit="$(_shelldone_json_escape "$exit_code")"
    text+="\\n<b>Exit Code:</b> ${safe_exit}"
    if [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]; then
      local safe_proj
      safe_proj="$(_shelldone_json_escape "${_SHELLDONE_META_PROJECT}")"
      text+="\\n<b>Project:</b> ${safe_proj}"
    fi
  fi

  # Context footer
  local ctx_parts=""
  [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]] && ctx_parts="${_SHELLDONE_META_HOSTNAME}"
  if [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]]; then
    [[ -n "$ctx_parts" ]] && ctx_parts+=" | "
    ctx_parts+="${_SHELLDONE_META_GIT_BRANCH}"
  fi
  if [[ -n "$ctx_parts" ]]; then
    local safe_ctx
    safe_ctx="$(_shelldone_json_escape "$ctx_parts")"
    text+="\\n\\n<i>${safe_ctx}</i>"
  fi

  local payload="{\"chat_id\":\"${safe_chat_id}\",\"text\":\"${text}\",\"parse_mode\":\"HTML\"}"

  local url="https://api.telegram.org/bot${SHELLDONE_TELEGRAM_TOKEN}/sendMessage"
  if _shelldone_http_post "$url" "$payload"; then
    _shelldone_rate_limit_update "telegram"
    _shelldone_external_debug "telegram notification sent"
  else
    _shelldone_external_debug "telegram notification FAILED (HTTP ${_SHELLDONE_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Email ──────────────────────────────────────────────────────────

_shelldone_external_email() {
  local title="$1" message="$2" exit_code="$3"

  # Validate no header injection
  if [[ "$SHELLDONE_EMAIL_TO" == *$'\n'* || "$SHELLDONE_EMAIL_TO" == *$'\r'* ]]; then
    _shelldone_external_debug "email: invalid recipient (contains newlines)"
    return 1
  fi

  _shelldone_rate_limit_check "email" || return 0

  local from="${SHELLDONE_EMAIL_FROM:-shelldone@$(hostname 2>/dev/null || echo localhost)}"
  local subject="${SHELLDONE_EMAIL_SUBJECT:-[shelldone] ${title}}"
  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="SUCCESS"; else icon="FAILURE"; fi

  # Collect metadata
  _shelldone_collect_metadata

  local body="${icon}: ${title}

${message}"

  # Add structured metadata fields (only include fields that have values)
  local details=""
  [[ -n "${_SHELLDONE_META_CMD:-}" ]]        && details+="Command:   ${_SHELLDONE_META_CMD}"$'\n'
  [[ -n "${_SHELLDONE_META_DURATION:-}" ]]   && details+="Duration:  ${_SHELLDONE_META_DURATION}"$'\n'
  details+="Exit Code: ${exit_code}"$'\n'
  [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]    && details+="Project:   ${_SHELLDONE_META_PROJECT}"$'\n'
  [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]]   && details+="Host:      ${_SHELLDONE_META_HOSTNAME}"$'\n'
  if [[ -n "${_SHELLDONE_META_PWD:-}" ]]; then
    local display_pwd="${_SHELLDONE_META_PWD}"
    if [[ -n "${HOME:-}" && "$display_pwd" == "${HOME}"* ]]; then
      display_pwd="~${display_pwd#"${HOME}"}"
    fi
    details+="Directory: ${display_pwd}"$'\n'
  fi
  [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]] && details+="Branch:    ${_SHELLDONE_META_GIT_BRANCH}"$'\n'
  local ts
  ts="$(date '+%Y-%m-%d %H:%M' 2>/dev/null || true)"
  [[ -n "$ts" ]] && details+="Time:      ${ts}"$'\n'

  body+="

${details}
--
Sent by shelldone"

  if command -v sendmail &>/dev/null; then
    printf 'From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s\n' \
      "$from" "$SHELLDONE_EMAIL_TO" "$subject" "$body" | sendmail -t 2>/dev/null
  elif command -v mail &>/dev/null; then
    printf '%s\n' "$body" | mail -s "$subject" "$SHELLDONE_EMAIL_TO" 2>/dev/null
  else
    _shelldone_warn_once EMAIL_TRANSPORT "sendmail or mail command required for email notifications"
    return 1
  fi

  _shelldone_rate_limit_update "email"
  _shelldone_external_debug "email notification sent to $SHELLDONE_EMAIL_TO"
}

# ── Channel: WhatsApp (Twilio) ──────────────────────────────────────────────

_shelldone_external_whatsapp() {
  local title="$1" message="$2" exit_code="$3"

  if [[ -z "${SHELLDONE_WHATSAPP_API_URL:-}" || -z "${SHELLDONE_WHATSAPP_FROM:-}" || -z "${SHELLDONE_WHATSAPP_TO:-}" ]]; then
    _shelldone_external_debug "whatsapp: missing required config (API_URL, FROM, or TO)"
    return 1
  fi

  _shelldone_rate_limit_check "whatsapp" || return 0

  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="✅"; else icon="❌"; fi

  # Collect metadata for context line
  _shelldone_collect_metadata
  local ctx_parts=""
  [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]    && ctx_parts="${_SHELLDONE_META_PROJECT}"
  if [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]]; then
    [[ -n "$ctx_parts" ]] && ctx_parts+=" | "
    ctx_parts+="${_SHELLDONE_META_HOSTNAME}"
  fi
  if [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]]; then
    [[ -n "$ctx_parts" ]] && ctx_parts+=" | "
    ctx_parts+="${_SHELLDONE_META_GIT_BRANCH}"
  fi

  local body_text="${icon} ${title}: ${message}"
  [[ -n "$ctx_parts" ]] && body_text+=$'\n'"${ctx_parts}"
  local safe_body safe_from safe_to
  safe_body="$(_shelldone_json_escape "$body_text")"
  safe_from="$(_shelldone_json_escape "whatsapp:${SHELLDONE_WHATSAPP_FROM}")"
  safe_to="$(_shelldone_json_escape "whatsapp:${SHELLDONE_WHATSAPP_TO}")"

  local payload="{\"From\":\"${safe_from}\",\"To\":\"${safe_to}\",\"Body\":\"${safe_body}\"}"
  local headers="Authorization: Basic ${SHELLDONE_WHATSAPP_TOKEN}"

  if _shelldone_http_post "$SHELLDONE_WHATSAPP_API_URL" "$payload" "$headers"; then
    _shelldone_rate_limit_update "whatsapp"
    _shelldone_external_debug "whatsapp notification sent"
  else
    _shelldone_external_debug "whatsapp notification FAILED (HTTP ${_SHELLDONE_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Generic Webhook ────────────────────────────────────────────────

_shelldone_external_webhook() {
  local title="$1" message="$2" exit_code="$3"

  _shelldone_rate_limit_check "webhook" || return 0

  # Collect metadata
  _shelldone_collect_metadata

  local safe_title safe_message
  safe_title="$(_shelldone_json_escape "$title")"
  safe_message="$(_shelldone_json_escape "$message")"

  local success="true"
  [[ "$exit_code" -ne 0 ]] && success="false"

  local payload="{\"title\":\"${safe_title}\",\"message\":\"${safe_message}\",\"exit_code\":${exit_code},\"success\":${success}"

  # Add optional metadata fields
  if [[ -n "${_SHELLDONE_META_CMD:-}" ]]; then
    local safe_cmd
    safe_cmd="$(_shelldone_json_escape "${_SHELLDONE_META_CMD}")"
    payload+=",\"command\":\"${safe_cmd}\""
  fi
  if [[ -n "${_SHELLDONE_META_DURATION:-}" ]]; then
    local safe_dur
    safe_dur="$(_shelldone_json_escape "${_SHELLDONE_META_DURATION}")"
    payload+=",\"duration\":\"${safe_dur}\""
  fi
  if [[ -n "${_SHELLDONE_META_HOSTNAME:-}" ]]; then
    local safe_host
    safe_host="$(_shelldone_json_escape "${_SHELLDONE_META_HOSTNAME}")"
    payload+=",\"hostname\":\"${safe_host}\""
  fi
  if [[ -n "${_SHELLDONE_META_PROJECT:-}" ]]; then
    local safe_proj
    safe_proj="$(_shelldone_json_escape "${_SHELLDONE_META_PROJECT}")"
    payload+=",\"project\":\"${safe_proj}\""
  fi
  if [[ -n "${_SHELLDONE_META_PWD:-}" ]]; then
    local safe_dir
    safe_dir="$(_shelldone_json_escape "${_SHELLDONE_META_PWD}")"
    payload+=",\"directory\":\"${safe_dir}\""
  fi
  if [[ -n "${_SHELLDONE_META_GIT_BRANCH:-}" ]]; then
    local safe_branch
    safe_branch="$(_shelldone_json_escape "${_SHELLDONE_META_GIT_BRANCH}")"
    payload+=",\"git_branch\":\"${safe_branch}\""
  fi
  local source="${_SHELLDONE_META_SOURCE:-shell}"
  local safe_source
  safe_source="$(_shelldone_json_escape "$source")"
  payload+=",\"source\":\"${safe_source}\""
  local iso_ts
  iso_ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  if [[ -n "$iso_ts" ]]; then
    payload+=",\"timestamp\":\"${iso_ts}\""
  fi

  payload+="}"

  if _shelldone_http_post "$SHELLDONE_WEBHOOK_URL" "$payload" "${SHELLDONE_WEBHOOK_HEADERS:-}"; then
    _shelldone_rate_limit_update "webhook"
    _shelldone_external_debug "webhook notification sent"
  else
    _shelldone_external_debug "webhook notification FAILED (HTTP ${_SHELLDONE_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel validation ──────────────────────────────────────────────────────

_shelldone_validate_channel() {
  local channel="$1"
  case "$channel" in
    slack)    [[ -n "${SHELLDONE_SLACK_WEBHOOK:-}" ]]    || { echo "SHELLDONE_SLACK_WEBHOOK not set. Set up with: shelldone channel add slack"; return 1; } ;;
    discord)  [[ -n "${SHELLDONE_DISCORD_WEBHOOK:-}" ]]  || { echo "SHELLDONE_DISCORD_WEBHOOK not set. Set up with: shelldone channel add discord"; return 1; } ;;
    telegram)
      [[ -n "${SHELLDONE_TELEGRAM_TOKEN:-}" ]]   || { echo "SHELLDONE_TELEGRAM_TOKEN not set. Set up with: shelldone channel add telegram"; return 1; }
      [[ -n "${SHELLDONE_TELEGRAM_CHAT_ID:-}" ]] || { echo "SHELLDONE_TELEGRAM_CHAT_ID not set. Set up with: shelldone channel add telegram"; return 1; }
      ;;
    email)
      [[ -n "${SHELLDONE_EMAIL_TO:-}" ]] || { echo "SHELLDONE_EMAIL_TO not set. Set up with: shelldone channel add email"; return 1; }
      command -v sendmail &>/dev/null || command -v mail &>/dev/null || { echo "sendmail or mail command required"; return 1; }
      ;;
    whatsapp)
      [[ -n "${SHELLDONE_WHATSAPP_TOKEN:-}" ]]   || { echo "SHELLDONE_WHATSAPP_TOKEN not set. Set up with: shelldone channel add whatsapp"; return 1; }
      [[ -n "${SHELLDONE_WHATSAPP_API_URL:-}" ]] || { echo "SHELLDONE_WHATSAPP_API_URL not set. Set up with: shelldone channel add whatsapp"; return 1; }
      [[ -n "${SHELLDONE_WHATSAPP_FROM:-}" ]]    || { echo "SHELLDONE_WHATSAPP_FROM not set. Set up with: shelldone channel add whatsapp"; return 1; }
      [[ -n "${SHELLDONE_WHATSAPP_TO:-}" ]]      || { echo "SHELLDONE_WHATSAPP_TO not set. Set up with: shelldone channel add whatsapp"; return 1; }
      ;;
    webhook)  [[ -n "${SHELLDONE_WEBHOOK_URL:-}" ]] || { echo "SHELLDONE_WEBHOOK_URL not set. Set up with: shelldone channel add webhook"; return 1; } ;;
    *)        echo "unknown channel: $channel"; return 1 ;;
  esac
}

# ── Main external dispatcher ────────────────────────────────────────────────

_shelldone_notify_external() {
  local title="$1" message="$2" exit_code="$3"
  local _err_dest="/dev/null"
  if [[ "$SHELLDONE_EXTERNAL_DEBUG" == "true" ]]; then
    _err_dest="/dev/stderr"
  fi

  _shelldone_dispatch_external_channels() {
    set +e  # Don't let failures propagate
    [[ -n "${SHELLDONE_SLACK_WEBHOOK:-}" ]]   && _shelldone_channel_enabled "slack" 2>/dev/null    && _shelldone_external_slack    "$title" "$message" "$exit_code"
    [[ -n "${SHELLDONE_DISCORD_WEBHOOK:-}" ]] && _shelldone_channel_enabled "discord" 2>/dev/null  && _shelldone_external_discord  "$title" "$message" "$exit_code"
    [[ -n "${SHELLDONE_TELEGRAM_TOKEN:-}" ]]  && _shelldone_channel_enabled "telegram" 2>/dev/null && _shelldone_external_telegram "$title" "$message" "$exit_code"
    [[ -n "${SHELLDONE_EMAIL_TO:-}" ]]        && _shelldone_channel_enabled "email" 2>/dev/null    && _shelldone_external_email    "$title" "$message" "$exit_code"
    [[ -n "${SHELLDONE_WHATSAPP_TOKEN:-}" ]]  && _shelldone_channel_enabled "whatsapp" 2>/dev/null && _shelldone_external_whatsapp "$title" "$message" "$exit_code"
    [[ -n "${SHELLDONE_WEBHOOK_URL:-}" ]]     && _shelldone_channel_enabled "webhook" 2>/dev/null  && _shelldone_external_webhook  "$title" "$message" "$exit_code"
    true  # Ensure success return
  }

  # Run synchronously in hook context (background process may be killed by
  # the parent AI CLI when the hook script exits), otherwise background.
  if [[ "${_SHELLDONE_HOOK_CONTEXT:-}" == "true" ]]; then
    _shelldone_dispatch_external_channels 2>>"$_err_dest"
  else
    ( _shelldone_dispatch_external_channels ) 2>>"$_err_dest" &
    disown 2>/dev/null
  fi
}
