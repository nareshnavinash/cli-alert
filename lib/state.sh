#!/usr/bin/env bash
# state.sh — Persistent state management for shelldone (mute, toggle, schedule)
# Loaded lazily on first notification or CLI command.

# Guard against double-sourcing
[[ -n "${_SHELLDONE_STATE_LOADED:-}" ]] && return 0
_SHELLDONE_STATE_LOADED=1

# ── State file location ────────────────────────────────────────────────────

_shelldone_state_dir() {
  printf '%s' "${SHELLDONE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/shelldone}"
}

_shelldone_state_file() {
  printf '%s/state' "$(_shelldone_state_dir)"
}

# ── State read/write (bash 3 compatible, no associative arrays) ───────────

_shelldone_state_read() {
  local key="$1" state_file
  state_file="$(_shelldone_state_file)"
  [[ -f "$state_file" ]] || return 1
  local k v
  while IFS='=' read -r k v; do
    # Skip empty lines and comments
    [[ -z "$k" || "$k" == \#* ]] && continue
    if [[ "$k" == "$key" ]]; then
      printf '%s' "$v"
      return 0
    fi
  done < "$state_file"
  return 1
}

_shelldone_state_write() {
  local key="$1" val="$2"
  local state_dir state_file tmp_file

  state_dir="$(_shelldone_state_dir)"
  state_file="$(_shelldone_state_file)"

  # Ensure state directory exists
  if [[ ! -d "$state_dir" ]]; then
    mkdir -p "$state_dir" 2>/dev/null || return 1
  fi

  tmp_file="${state_file}.tmp.$$"

  # Remove existing key (if file exists), then append new key=value
  if [[ -f "$state_file" ]]; then
    grep -v "^${key}=" "$state_file" > "$tmp_file" 2>/dev/null || true
  fi
  printf '%s=%s\n' "$key" "$val" >> "$tmp_file"

  # Atomic replace
  mv "$tmp_file" "$state_file"
}

_shelldone_state_delete() {
  local key="$1"
  local state_file tmp_file

  state_file="$(_shelldone_state_file)"
  [[ -f "$state_file" ]] || return 0

  tmp_file="${state_file}.tmp.$$"
  grep -v "^${key}=" "$state_file" > "$tmp_file" 2>/dev/null || true

  # Atomic replace
  mv "$tmp_file" "$state_file"

  # Remove empty state file
  if [[ ! -s "$state_file" ]]; then
    rm -f "$state_file" 2>/dev/null
  fi
}

_shelldone_state_dump() {
  local state_file
  state_file="$(_shelldone_state_file)"
  [[ -f "$state_file" ]] || return 0
  cat "$state_file"
}

# ── Duration parsing ──────────────────────────────────────────────────────

_shelldone_parse_duration() {
  local input="$1"
  local total=0 num="" unit=""

  # Handle pure numeric (seconds)
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    printf '%s' "$input"
    return 0
  fi

  # Parse combinations like "1h30m", "2h", "30m", "45s"
  local remaining="$input"
  while [[ -n "$remaining" ]]; do
    if [[ "$remaining" =~ ^([0-9]+)([smhd]) ]]; then
      num="${BASH_REMATCH[1]}"
      unit="${BASH_REMATCH[2]}"
      remaining="${remaining#"${BASH_REMATCH[0]}"}"
      case "$unit" in
        s) total=$((total + num)) ;;
        m) total=$((total + num * 60)) ;;
        h) total=$((total + num * 3600)) ;;
        d) total=$((total + num * 86400)) ;;
      esac
    else
      echo "invalid duration: $input" >&2
      return 1
    fi
  done

  if [[ $total -le 0 ]]; then
    echo "invalid duration: $input" >&2
    return 1
  fi

  printf '%s' "$total"
}

# ── Mute check ────────────────────────────────────────────────────────────

_shelldone_is_muted() {
  local mute_until
  mute_until="$(_shelldone_state_read "mute_until")" || return 1

  # 0 = muted indefinitely
  if [[ "$mute_until" == "0" ]]; then
    return 0
  fi

  # Check if mute has expired
  local now
  now=$(date +%s)
  if (( mute_until > now )); then
    return 0
  fi

  # Expired — clean up
  _shelldone_state_delete "mute_until"
  return 1
}

# ── Per-channel toggle ────────────────────────────────────────────────────

_shelldone_channel_enabled() {
  local channel="$1"
  local val
  val="$(_shelldone_state_read "$channel")" || return 0  # Missing = on (default)
  case "$val" in
    off) return 1 ;;
    *)   return 0 ;;
  esac
}

# ── Quiet hours ───────────────────────────────────────────────────────────

_shelldone_is_quiet_hours() {
  local quiet_start quiet_end

  # Try state file first, then env var fallback
  quiet_start="$(_shelldone_state_read "quiet_start")" 2>/dev/null || true
  quiet_end="$(_shelldone_state_read "quiet_end")" 2>/dev/null || true

  # Env var fallback: SHELLDONE_QUIET_HOURS="22:00-08:00"
  if [[ -z "$quiet_start" && -z "$quiet_end" && -n "${SHELLDONE_QUIET_HOURS:-}" ]]; then
    if [[ "$SHELLDONE_QUIET_HOURS" =~ ^([0-9]{2}:[0-9]{2})-([0-9]{2}:[0-9]{2})$ ]]; then
      quiet_start="${BASH_REMATCH[1]}"
      quiet_end="${BASH_REMATCH[2]}"
    else
      return 1
    fi
  fi

  # No schedule = not quiet
  [[ -z "$quiet_start" || -z "$quiet_end" ]] && return 1

  # Validate format
  [[ "$quiet_start" =~ ^[0-9]{2}:[0-9]{2}$ ]] || return 1
  [[ "$quiet_end" =~ ^[0-9]{2}:[0-9]{2}$ ]] || return 1

  # Convert to minutes since midnight
  local start_h="${quiet_start%%:*}" start_m="${quiet_start##*:}"
  local end_h="${quiet_end%%:*}" end_m="${quiet_end##*:}"
  local start_minutes=$(( 10#$start_h * 60 + 10#$start_m ))
  local end_minutes=$(( 10#$end_h * 60 + 10#$end_m ))

  # Current time in minutes since midnight
  local now_h now_m now_minutes
  now_h=$(date +%H)
  now_m=$(date +%M)
  now_minutes=$(( 10#$now_h * 60 + 10#$now_m ))

  if (( start_minutes <= end_minutes )); then
    # Same-day range: e.g. 09:00-17:00
    (( now_minutes >= start_minutes && now_minutes < end_minutes ))
  else
    # Crosses midnight: e.g. 22:00-08:00
    (( now_minutes >= start_minutes || now_minutes < end_minutes ))
  fi
}
