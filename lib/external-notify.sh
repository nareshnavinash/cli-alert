#!/usr/bin/env bash
# external-notify.sh — External notification channels for cli-alert
# Loaded lazily only when at least one external channel env var is set.

# Guard against double-sourcing
[[ -n "${_CLI_ALERT_EXTERNAL_LOADED:-}" ]] && return 0
_CLI_ALERT_EXTERNAL_LOADED=1

# ── Global defaults ─────────────────────────────────────────────────────────

CLI_ALERT_WEBHOOK_TIMEOUT="${CLI_ALERT_WEBHOOK_TIMEOUT:-5}"
CLI_ALERT_RATE_LIMIT="${CLI_ALERT_RATE_LIMIT:-10}"
CLI_ALERT_EXTERNAL_DEBUG="${CLI_ALERT_EXTERNAL_DEBUG:-false}"

# ── Debug helper ────────────────────────────────────────────────────────────

_cli_alert_external_debug() {
  if [[ "$CLI_ALERT_EXTERNAL_DEBUG" == "true" ]]; then
    printf '[cli-alert:external] %s\n' "$*" >&2
  fi
}

# ── Pure-bash JSON string escaping ──────────────────────────────────────────

_cli_alert_json_escape() {
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

_cli_alert_parse_url() {
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

_cli_alert_detect_http_transport() {
  if command -v curl &>/dev/null; then
    _CLI_ALERT_HTTP_TRANSPORT="curl"
  elif command -v wget &>/dev/null; then
    _CLI_ALERT_HTTP_TRANSPORT="wget"
  elif [[ -e /dev/tcp ]]; then
    _CLI_ALERT_HTTP_TRANSPORT="tcp"
  else
    # Try /dev/tcp by attempting a connection — bash may support it even without the file
    _CLI_ALERT_HTTP_TRANSPORT="tcp"
  fi
  _cli_alert_external_debug "HTTP transport: $_CLI_ALERT_HTTP_TRANSPORT"
}

_cli_alert_detect_http_transport

# ── HTTP POST backends ──────────────────────────────────────────────────────

_cli_alert_http_post_curl() {
  local url="$1" payload="$2" extra_headers="$3"
  local -a cmd=(curl -sS -o /dev/null -w '%{http_code}' -X POST
    --max-time "$CLI_ALERT_WEBHOOK_TIMEOUT"
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
  http_code=$("${cmd[@]}" 2>/dev/null) || true
  _CLI_ALERT_LAST_HTTP_STATUS="$http_code"
  [[ "$http_code" =~ ^2[0-9][0-9]$ ]]
}

_cli_alert_http_post_wget() {
  local url="$1" payload="$2" extra_headers="$3"
  local -a cmd=(wget -qO- --timeout="$CLI_ALERT_WEBHOOK_TIMEOUT"
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
  _CLI_ALERT_LAST_HTTP_STATUS="unknown"
  "${cmd[@]}" 2>/dev/null
}

_cli_alert_http_post_tcp() {
  local url="$1" payload="$2" extra_headers="$3"

  _cli_alert_parse_url "$url" || return 1

  if [[ "$_PARSED_SCHEME" == "https" ]]; then
    _cli_alert_warn_once HTTPS_TRANSPORT "curl or wget required for HTTPS channels (Slack/Discord/Telegram). Install curl for external notifications."
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

_cli_alert_http_post() {
  local url="$1" payload="$2" headers="${3:-}"

  _cli_alert_external_debug "POST $(_cli_alert_redact_url "$url")"

  case "$_CLI_ALERT_HTTP_TRANSPORT" in
    curl) _cli_alert_http_post_curl "$url" "$payload" "$headers" ;;
    wget) _cli_alert_http_post_wget "$url" "$payload" "$headers" ;;
    tcp)  _cli_alert_http_post_tcp  "$url" "$payload" "$headers" ;;
    *)    return 1 ;;
  esac
}

# ── Rate limiting ───────────────────────────────────────────────────────────

_cli_alert_rate_limit_check() {
  [[ "${_CLI_ALERT_SKIP_RATE_LIMIT:-}" == "true" ]] && return 0
  local channel="$1"
  local stamp_file="/tmp/.cli_alert_rate_${channel}_$$_stamp"
  # Use a shared stamp file (not per-PID) for rate limiting across subshells
  stamp_file="/tmp/.cli_alert_rate_${channel}"

  if [[ ! -f "$stamp_file" ]]; then
    return 0  # No stamp = not rate-limited
  fi

  local last_sent now
  last_sent=$(cat "$stamp_file" 2>/dev/null) || return 0
  now=$(date +%s)

  local elapsed=$(( now - last_sent ))
  if (( elapsed < CLI_ALERT_RATE_LIMIT )); then
    _cli_alert_external_debug "rate limited: $channel (${elapsed}s < ${CLI_ALERT_RATE_LIMIT}s)"
    return 1
  fi
  return 0
}

_cli_alert_rate_limit_update() {
  local channel="$1"
  local stamp_file="/tmp/.cli_alert_rate_${channel}"
  date +%s > "$stamp_file" 2>/dev/null
}

# ── URL redaction for debug logging ─────────────────────────────────────────

_cli_alert_redact_url() {
  local url="$1"
  # Keep scheme + host, replace path with <redacted>
  if [[ "$url" =~ ^(https?://[^/]+) ]]; then
    printf '%s/<redacted>' "${BASH_REMATCH[1]}"
  else
    printf '<redacted-url>'
  fi
}

# ── Metadata collection ─────────────────────────────────────────────────────

_cli_alert_collect_metadata() {
  # Hostname
  _CLI_ALERT_META_HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo "unknown")}"

  # Working directory
  _CLI_ALERT_META_PWD="${PWD:-$(pwd 2>/dev/null || echo "")}"

  # Project name: git root basename or PWD basename
  local git_root
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$git_root" ]]; then
    _CLI_ALERT_META_PROJECT="${git_root##*/}"
  else
    _CLI_ALERT_META_PROJECT="${_CLI_ALERT_META_PWD##*/}"
  fi

  # Git branch (optional, graceful skip)
  _CLI_ALERT_META_GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
}

# ── Metadata cleanup ───────────────────────────────────────────────────────

_cli_alert_clear_metadata() {
  unset _CLI_ALERT_META_CMD _CLI_ALERT_META_DURATION _CLI_ALERT_META_SOURCE
  unset _CLI_ALERT_META_AI_NAME _CLI_ALERT_META_STOP_REASON
  unset _CLI_ALERT_META_HOSTNAME _CLI_ALERT_META_PWD
  unset _CLI_ALERT_META_PROJECT _CLI_ALERT_META_GIT_BRANCH
}

# ── Channel: Slack ──────────────────────────────────────────────────────────

_cli_alert_external_slack() {
  local title="$1" message="$2" exit_code="$3"

  _cli_alert_rate_limit_check "slack" || return 0

  local safe_title safe_message
  safe_title="$(_cli_alert_json_escape "$title")"
  safe_message="$(_cli_alert_json_escape "$message")"

  local color
  if [[ "$exit_code" -eq 0 ]]; then
    color="#36a64f"
  else
    color="#dc3545"
  fi

  local username="${CLI_ALERT_SLACK_USERNAME:-cli-alert}"
  local safe_username
  safe_username="$(_cli_alert_json_escape "$username")"

  local payload
  if [[ "${CLI_ALERT_SLACK_BLOCKS:-true}" == "true" ]]; then
    payload="$(_cli_alert_slack_blocks_payload "$title" "$message" "$exit_code" "$color" "$safe_username")"
  else
    payload="{\"username\":\"${safe_username}\""
    if [[ -n "${CLI_ALERT_SLACK_CHANNEL:-}" ]]; then
      local safe_channel
      safe_channel="$(_cli_alert_json_escape "$CLI_ALERT_SLACK_CHANNEL")"
      payload+=",\"channel\":\"${safe_channel}\""
    fi
    payload+=",\"attachments\":[{\"color\":\"${color}\",\"title\":\"${safe_title}\",\"text\":\"${safe_message}\"}]}"
  fi

  if _cli_alert_http_post "$CLI_ALERT_SLACK_WEBHOOK" "$payload"; then
    _cli_alert_rate_limit_update "slack"
    _cli_alert_external_debug "slack notification sent"
  else
    _cli_alert_external_debug "slack notification FAILED (HTTP ${_CLI_ALERT_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

_cli_alert_slack_blocks_payload() {
  local title="$1" message="$2" exit_code="$3" color="$4" safe_username="$5"

  # Status emoji
  local emoji
  if [[ "$exit_code" -eq 0 ]]; then emoji="✅"; else emoji="❌"; fi

  local safe_title
  safe_title="$(_cli_alert_json_escape "${emoji} ${title}")"

  # Collect environment metadata
  _cli_alert_collect_metadata

  # Build section fields (2-column grid)
  local fields=""

  if [[ "${_CLI_ALERT_META_SOURCE:-}" == "ai-hook" ]]; then
    # AI hook variant
    local status_text="Task complete"
    if [[ -n "${_CLI_ALERT_META_STOP_REASON:-}" ]]; then
      local safe_reason
      safe_reason="$(_cli_alert_json_escape "${_CLI_ALERT_META_STOP_REASON}")"
      status_text="Task complete\\n(${safe_reason})"
    fi
    fields="{\"type\":\"mrkdwn\",\"text\":\"*Status*\\n${status_text}\"}"
    fields+=",{\"type\":\"mrkdwn\",\"text\":\"*Source*\\n🤖 AI Hook\"}"
  else
    # Shell command variant
    if [[ -n "${_CLI_ALERT_META_CMD:-}" ]]; then
      local safe_cmd
      safe_cmd="$(_cli_alert_json_escape "${_CLI_ALERT_META_CMD}")"
      fields="{\"type\":\"mrkdwn\",\"text\":\"*Command*\\n${safe_cmd}\"}"
    fi
    if [[ -n "${_CLI_ALERT_META_DURATION:-}" ]]; then
      local safe_dur
      safe_dur="$(_cli_alert_json_escape "${_CLI_ALERT_META_DURATION}")"
      [[ -n "$fields" ]] && fields+=","
      fields+="{\"type\":\"mrkdwn\",\"text\":\"*Duration*\\n${safe_dur}\"}"
    fi
    local safe_exit
    safe_exit="$(_cli_alert_json_escape "$exit_code")"
    [[ -n "$fields" ]] && fields+=","
    fields+="{\"type\":\"mrkdwn\",\"text\":\"*Exit Code*\\n${safe_exit}\"}"
    if [[ -n "${_CLI_ALERT_META_PROJECT:-}" ]]; then
      local safe_proj
      safe_proj="$(_cli_alert_json_escape "${_CLI_ALERT_META_PROJECT}")"
      fields+=",{\"type\":\"mrkdwn\",\"text\":\"*Project*\\n${safe_proj}\"}"
    fi
  fi

  # Build context line: hostname | directory | git branch
  local context_parts=""
  if [[ -n "${_CLI_ALERT_META_HOSTNAME:-}" ]]; then
    local safe_host
    safe_host="$(_cli_alert_json_escape "${_CLI_ALERT_META_HOSTNAME}")"
    context_parts="💻 ${safe_host}"
  fi
  if [[ -n "${_CLI_ALERT_META_PWD:-}" ]]; then
    # Shorten home dir to ~
    local display_pwd="${_CLI_ALERT_META_PWD}"
    if [[ -n "${HOME:-}" && "$display_pwd" == "${HOME}"* ]]; then
      display_pwd="~${display_pwd#"${HOME}"}"
    fi
    local safe_pwd
    safe_pwd="$(_cli_alert_json_escape "$display_pwd")"
    [[ -n "$context_parts" ]] && context_parts+=" | "
    context_parts+="📂 ${safe_pwd}"
  fi
  if [[ -n "${_CLI_ALERT_META_GIT_BRANCH:-}" ]]; then
    local safe_branch
    safe_branch="$(_cli_alert_json_escape "${_CLI_ALERT_META_GIT_BRANCH}")"
    [[ -n "$context_parts" ]] && context_parts+=" | "
    context_parts+="🌿 ${safe_branch}"
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
    safe_context="$(_cli_alert_json_escape "$context_parts")"
    blocks+=",{\"type\":\"context\",\"elements\":[{\"type\":\"mrkdwn\",\"text\":\"${safe_context}\"}]}"
  fi

  # Wrap in attachments for colored sidebar, with legacy fallback fields
  local safe_fallback_message
  safe_fallback_message="$(_cli_alert_json_escape "$message")"
  local safe_fallback_title
  safe_fallback_title="$(_cli_alert_json_escape "$title")"

  local payload="{\"username\":\"${safe_username}\""
  if [[ -n "${CLI_ALERT_SLACK_CHANNEL:-}" ]]; then
    local safe_channel
    safe_channel="$(_cli_alert_json_escape "$CLI_ALERT_SLACK_CHANNEL")"
    payload+=",\"channel\":\"${safe_channel}\""
  fi
  payload+=",\"attachments\":[{\"color\":\"${color}\",\"title\":\"${safe_fallback_title}\",\"text\":\"${safe_fallback_message}\",\"blocks\":[${blocks}]}]}"

  printf '%s' "$payload"
}

# ── Channel: Discord ────────────────────────────────────────────────────────

_cli_alert_external_discord() {
  local title="$1" message="$2" exit_code="$3"

  _cli_alert_rate_limit_check "discord" || return 0

  local safe_title safe_message
  safe_title="$(_cli_alert_json_escape "$title")"
  safe_message="$(_cli_alert_json_escape "$message")"

  local color
  if [[ "$exit_code" -eq 0 ]]; then
    color=3583835  # green
  else
    color=14431557  # red
  fi

  local username="${CLI_ALERT_DISCORD_USERNAME:-cli-alert}"
  local safe_username
  safe_username="$(_cli_alert_json_escape "$username")"

  local payload="{\"username\":\"${safe_username}\",\"embeds\":[{\"title\":\"${safe_title}\",\"description\":\"${safe_message}\",\"color\":${color}}]}"

  if _cli_alert_http_post "$CLI_ALERT_DISCORD_WEBHOOK" "$payload"; then
    _cli_alert_rate_limit_update "discord"
    _cli_alert_external_debug "discord notification sent"
  else
    _cli_alert_external_debug "discord notification FAILED (HTTP ${_CLI_ALERT_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Telegram ───────────────────────────────────────────────────────

_cli_alert_external_telegram() {
  local title="$1" message="$2" exit_code="$3"

  if [[ -z "${CLI_ALERT_TELEGRAM_CHAT_ID:-}" ]]; then
    _cli_alert_external_debug "telegram: missing CLI_ALERT_TELEGRAM_CHAT_ID"
    return 1
  fi

  _cli_alert_rate_limit_check "telegram" || return 0

  local safe_title safe_message safe_chat_id
  safe_title="$(_cli_alert_json_escape "$title")"
  safe_message="$(_cli_alert_json_escape "$message")"
  safe_chat_id="$(_cli_alert_json_escape "$CLI_ALERT_TELEGRAM_CHAT_ID")"

  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="✅"; else icon="❌"; fi

  local text="${icon} *${safe_title}*\n${safe_message}"
  local payload="{\"chat_id\":\"${safe_chat_id}\",\"text\":\"${text}\",\"parse_mode\":\"Markdown\"}"

  local url="https://api.telegram.org/bot${CLI_ALERT_TELEGRAM_TOKEN}/sendMessage"
  if _cli_alert_http_post "$url" "$payload"; then
    _cli_alert_rate_limit_update "telegram"
    _cli_alert_external_debug "telegram notification sent"
  else
    _cli_alert_external_debug "telegram notification FAILED (HTTP ${_CLI_ALERT_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Email ──────────────────────────────────────────────────────────

_cli_alert_external_email() {
  local title="$1" message="$2" exit_code="$3"

  # Validate no header injection
  if [[ "$CLI_ALERT_EMAIL_TO" == *$'\n'* || "$CLI_ALERT_EMAIL_TO" == *$'\r'* ]]; then
    _cli_alert_external_debug "email: invalid recipient (contains newlines)"
    return 1
  fi

  _cli_alert_rate_limit_check "email" || return 0

  local from="${CLI_ALERT_EMAIL_FROM:-cli-alert@$(hostname 2>/dev/null || echo localhost)}"
  local subject="${CLI_ALERT_EMAIL_SUBJECT:-[cli-alert] ${title}}"
  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="SUCCESS"; else icon="FAILURE"; fi

  local body="${icon}: ${title}

${message}

--
Sent by cli-alert"

  if command -v sendmail &>/dev/null; then
    printf 'From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s\n' \
      "$from" "$CLI_ALERT_EMAIL_TO" "$subject" "$body" | sendmail -t 2>/dev/null
  elif command -v mail &>/dev/null; then
    printf '%s\n' "$body" | mail -s "$subject" "$CLI_ALERT_EMAIL_TO" 2>/dev/null
  else
    _cli_alert_warn_once EMAIL_TRANSPORT "sendmail or mail command required for email notifications"
    return 1
  fi

  _cli_alert_rate_limit_update "email"
  _cli_alert_external_debug "email notification sent to $CLI_ALERT_EMAIL_TO"
}

# ── Channel: WhatsApp (Twilio) ──────────────────────────────────────────────

_cli_alert_external_whatsapp() {
  local title="$1" message="$2" exit_code="$3"

  if [[ -z "${CLI_ALERT_WHATSAPP_API_URL:-}" || -z "${CLI_ALERT_WHATSAPP_FROM:-}" || -z "${CLI_ALERT_WHATSAPP_TO:-}" ]]; then
    _cli_alert_external_debug "whatsapp: missing required config (API_URL, FROM, or TO)"
    return 1
  fi

  _cli_alert_rate_limit_check "whatsapp" || return 0

  local icon
  if [[ "$exit_code" -eq 0 ]]; then icon="✅"; else icon="❌"; fi

  local body_text="${icon} ${title}: ${message}"
  local safe_body safe_from safe_to
  safe_body="$(_cli_alert_json_escape "$body_text")"
  safe_from="$(_cli_alert_json_escape "whatsapp:${CLI_ALERT_WHATSAPP_FROM}")"
  safe_to="$(_cli_alert_json_escape "whatsapp:${CLI_ALERT_WHATSAPP_TO}")"

  local payload="{\"From\":\"${safe_from}\",\"To\":\"${safe_to}\",\"Body\":\"${safe_body}\"}"
  local headers="Authorization: Basic ${CLI_ALERT_WHATSAPP_TOKEN}"

  if _cli_alert_http_post "$CLI_ALERT_WHATSAPP_API_URL" "$payload" "$headers"; then
    _cli_alert_rate_limit_update "whatsapp"
    _cli_alert_external_debug "whatsapp notification sent"
  else
    _cli_alert_external_debug "whatsapp notification FAILED (HTTP ${_CLI_ALERT_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel: Generic Webhook ────────────────────────────────────────────────

_cli_alert_external_webhook() {
  local title="$1" message="$2" exit_code="$3"

  _cli_alert_rate_limit_check "webhook" || return 0

  local safe_title safe_message
  safe_title="$(_cli_alert_json_escape "$title")"
  safe_message="$(_cli_alert_json_escape "$message")"

  local payload="{\"title\":\"${safe_title}\",\"message\":\"${safe_message}\",\"exit_code\":${exit_code}}"

  if _cli_alert_http_post "$CLI_ALERT_WEBHOOK_URL" "$payload" "${CLI_ALERT_WEBHOOK_HEADERS:-}"; then
    _cli_alert_rate_limit_update "webhook"
    _cli_alert_external_debug "webhook notification sent"
  else
    _cli_alert_external_debug "webhook notification FAILED (HTTP ${_CLI_ALERT_LAST_HTTP_STATUS:-unknown})"
    return 1
  fi
}

# ── Channel validation ──────────────────────────────────────────────────────

_cli_alert_validate_channel() {
  local channel="$1"
  case "$channel" in
    slack)    [[ -n "${CLI_ALERT_SLACK_WEBHOOK:-}" ]]    || { echo "CLI_ALERT_SLACK_WEBHOOK not set"; return 1; } ;;
    discord)  [[ -n "${CLI_ALERT_DISCORD_WEBHOOK:-}" ]]  || { echo "CLI_ALERT_DISCORD_WEBHOOK not set"; return 1; } ;;
    telegram)
      [[ -n "${CLI_ALERT_TELEGRAM_TOKEN:-}" ]]   || { echo "CLI_ALERT_TELEGRAM_TOKEN not set"; return 1; }
      [[ -n "${CLI_ALERT_TELEGRAM_CHAT_ID:-}" ]] || { echo "CLI_ALERT_TELEGRAM_CHAT_ID not set"; return 1; }
      ;;
    email)
      [[ -n "${CLI_ALERT_EMAIL_TO:-}" ]] || { echo "CLI_ALERT_EMAIL_TO not set"; return 1; }
      command -v sendmail &>/dev/null || command -v mail &>/dev/null || { echo "sendmail or mail command required"; return 1; }
      ;;
    whatsapp)
      [[ -n "${CLI_ALERT_WHATSAPP_TOKEN:-}" ]]   || { echo "CLI_ALERT_WHATSAPP_TOKEN not set"; return 1; }
      [[ -n "${CLI_ALERT_WHATSAPP_API_URL:-}" ]] || { echo "CLI_ALERT_WHATSAPP_API_URL not set"; return 1; }
      [[ -n "${CLI_ALERT_WHATSAPP_FROM:-}" ]]    || { echo "CLI_ALERT_WHATSAPP_FROM not set"; return 1; }
      [[ -n "${CLI_ALERT_WHATSAPP_TO:-}" ]]      || { echo "CLI_ALERT_WHATSAPP_TO not set"; return 1; }
      ;;
    webhook)  [[ -n "${CLI_ALERT_WEBHOOK_URL:-}" ]] || { echo "CLI_ALERT_WEBHOOK_URL not set"; return 1; } ;;
    *)        echo "unknown channel: $channel"; return 1 ;;
  esac
}

# ── Main external dispatcher ────────────────────────────────────────────────

_cli_alert_notify_external() {
  local title="$1" message="$2" exit_code="$3"
  local _err_dest="/dev/null"
  if [[ "$CLI_ALERT_EXTERNAL_DEBUG" == "true" ]]; then
    _err_dest="/dev/stderr"
  fi

  _cli_alert_dispatch_external_channels() {
    set +e  # Don't let failures propagate
    [[ -n "${CLI_ALERT_SLACK_WEBHOOK:-}" ]]   && _cli_alert_channel_enabled "slack" 2>/dev/null    && _cli_alert_external_slack    "$title" "$message" "$exit_code"
    [[ -n "${CLI_ALERT_DISCORD_WEBHOOK:-}" ]] && _cli_alert_channel_enabled "discord" 2>/dev/null  && _cli_alert_external_discord  "$title" "$message" "$exit_code"
    [[ -n "${CLI_ALERT_TELEGRAM_TOKEN:-}" ]]  && _cli_alert_channel_enabled "telegram" 2>/dev/null && _cli_alert_external_telegram "$title" "$message" "$exit_code"
    [[ -n "${CLI_ALERT_EMAIL_TO:-}" ]]        && _cli_alert_channel_enabled "email" 2>/dev/null    && _cli_alert_external_email    "$title" "$message" "$exit_code"
    [[ -n "${CLI_ALERT_WHATSAPP_TOKEN:-}" ]]  && _cli_alert_channel_enabled "whatsapp" 2>/dev/null && _cli_alert_external_whatsapp "$title" "$message" "$exit_code"
    [[ -n "${CLI_ALERT_WEBHOOK_URL:-}" ]]     && _cli_alert_channel_enabled "webhook" 2>/dev/null  && _cli_alert_external_webhook  "$title" "$message" "$exit_code"
    true  # Ensure success return
  }

  # Run synchronously in hook context (background process may be killed by
  # the parent AI CLI when the hook script exits), otherwise background.
  if [[ "${_CLI_ALERT_HOOK_CONTEXT:-}" == "true" ]]; then
    _cli_alert_dispatch_external_channels 2>>"$_err_dest"
  else
    ( _cli_alert_dispatch_external_channels ) 2>>"$_err_dest" &
    disown 2>/dev/null
  fi
}
