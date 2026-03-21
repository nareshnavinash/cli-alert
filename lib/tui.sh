#!/usr/bin/env bash
# tui.sh - Terminal UI utilities for shelldone
# Provides colors, output helpers, interactive prompts, and validation.
# bash 3.2 compatible (no associative arrays, no namerefs).

[[ -n "${_SHELLDONE_TUI_LOADED:-}" ]] && return 0
_SHELLDONE_TUI_LOADED=1

# ── Color / style codes ─────────────────────────────────────────────────────
# Auto-disabled when NO_COLOR is set or stdout is not a tty.

_tui_init_colors() {
  if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    _TUI_GREEN=""  _TUI_RED=""    _TUI_YELLOW=""
    _TUI_BLUE=""   _TUI_BOLD=""   _TUI_DIM=""
    _TUI_RESET=""  _TUI_CYAN=""
  else
    _TUI_GREEN=$'\033[32m'   _TUI_RED=$'\033[31m'      _TUI_YELLOW=$'\033[33m'
    _TUI_BLUE=$'\033[34m'    _TUI_BOLD=$'\033[1m'      _TUI_DIM=$'\033[2m'
    _TUI_RESET=$'\033[0m'    _TUI_CYAN=$'\033[36m'
  fi
}
_tui_init_colors

# ── Output helpers ───────────────────────────────────────────────────────────

_tui_ok()     { printf '%s✓%s %s\n' "${_TUI_GREEN}" "${_TUI_RESET}" "$1"; }
_tui_warn()   { printf '%s!%s %s\n' "${_TUI_YELLOW}" "${_TUI_RESET}" "$1"; }
_tui_err()    { printf '%s✗%s %s\n' "${_TUI_RED}" "${_TUI_RESET}" "$1"; }
_tui_info()   { printf '%sℹ%s %s\n' "${_TUI_BLUE}" "${_TUI_RESET}" "$1"; }

_tui_header() {
  printf '\n%s%s%s\n' "${_TUI_BOLD}" "$1" "${_TUI_RESET}"
}

_tui_step() {
  local n="$1" total="$2" desc="$3"
  printf '%s[%d/%d]%s %s\n' "${_TUI_DIM}" "$n" "$total" "${_TUI_RESET}" "$desc"
}

# ── Interactive prompts ──────────────────────────────────────────────────────
# All respect SHELLDONE_NONINTERACTIVE=true (return defaults / fail gracefully).

_tui_is_interactive() {
  [[ "${SHELLDONE_NONINTERACTIVE:-}" != "true" ]] && [[ -t 0 ]]
}

_tui_confirm() {
  local msg="$1" default="${2:-default_no}"
  local hint
  if [[ "$default" == "default_yes" ]]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi

  if ! _tui_is_interactive; then
    [[ "$default" == "default_yes" ]]
    return $?
  fi

  printf '%s %s ' "$msg" "$hint"
  local reply
  read -r reply </dev/tty
  case "${reply:-}" in
    [yY]|[yY][eE][sS]) return 0 ;;
    [nN]|[nN][oO])     return 1 ;;
    "")
      [[ "$default" == "default_yes" ]]
      return $?
      ;;
    *) return 1 ;;
  esac
}

_tui_prompt() {
  local msg="$1" default="${2:-}"

  if ! _tui_is_interactive; then
    printf '%s\n' "$default"
    return 0
  fi

  if [[ -n "$default" ]]; then
    printf '%s [%s]: ' "$msg" "$default" >/dev/tty
  else
    printf '%s: ' "$msg" >/dev/tty
  fi
  local reply
  read -r reply </dev/tty
  # Trim leading/trailing whitespace (common when pasting URLs)
  reply="${reply#"${reply%%[![:space:]]*}"}"
  reply="${reply%"${reply##*[![:space:]]}"}"
  if [[ -z "$reply" ]]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$reply"
  fi
}

_tui_prompt_secret() {
  local msg="$1"

  if ! _tui_is_interactive; then
    echo ""
    return 1
  fi

  printf '%s: ' "$msg" >/dev/tty
  local reply
  read -rs reply </dev/tty
  echo "" >/dev/tty  # newline after hidden input
  printf '%s\n' "$reply"
}

# _tui_select "prompt" option1 option2 ...
# Result stored in $_TUI_SELECTED (and $_TUI_SELECTED_INDEX)
_TUI_SELECTED=""
_TUI_SELECTED_INDEX=""

_tui_select() {
  local prompt="$1"
  shift
  local -a options=("$@")
  local count=${#options[@]}

  if ! _tui_is_interactive; then
    _TUI_SELECTED="${options[@]:0:1}"
    _TUI_SELECTED_INDEX=0
    return 0
  fi

  printf '%s\n' "$prompt"
  local i
  for (( i=0; i<count; i++ )); do
    printf '  %s%d)%s %s\n' "${_TUI_BOLD}" $((i + 1)) "${_TUI_RESET}" "${options[@]:$i:1}"
  done

  while true; do
    printf 'Choice [1-%d]: ' "$count"
    local reply
    read -r reply </dev/tty
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= count )); then
      _TUI_SELECTED="${options[@]:$((reply - 1)):1}"
      _TUI_SELECTED_INDEX=$((reply - 1))
      return 0
    fi
    printf '  Please enter a number between 1 and %d.\n' "$count"
  done
}

# ── Validation helpers ───────────────────────────────────────────────────────

_tui_validate_url() {
  local url="$1"
  [[ "$url" =~ ^https?:// ]]
}

_tui_sanitize_url() {
  local url="$1"
  # Strip non-printable / non-ASCII bytes (zero-width space, BOM, NBSP, etc.)
  # URLs are pure ASCII, so this is always safe.
  url=$(printf '%s' "$url" | LC_ALL=C tr -cd '\040-\176')
  # Trim remaining ASCII whitespace
  url="${url#"${url%%[![:space:]]*}"}"
  url="${url%"${url##*[![:space:]]}"}"
  printf '%s' "$url"
}

_tui_validate_not_empty() {
  [[ -n "${1:-}" ]]
}

_tui_validate_number() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

# ── Rich TUI primitives ───────────────────────────────────────────────────

# _tui_divider [label]
# Visual section separator: ── Shell Integration ──
_tui_divider() {
  local label="${1:-}"
  if [[ -z "$label" ]]; then
    printf '%s────────────────────────────────%s\n' "${_TUI_DIM}" "${_TUI_RESET}"
  else
    printf '%s── %s%s%s%s ──────────────────────%s\n' \
      "${_TUI_DIM}" "${_TUI_RESET}${_TUI_BOLD}" "$label" \
      "${_TUI_RESET}${_TUI_DIM}" "" "${_TUI_RESET}"
  fi
}

# _tui_kv "Key" "Value" [color]
# Formatted key-value line:   Slack:          [configured]
_tui_kv() {
  local key="$1" value="$2" color="${3:-}"
  local color_code=""
  case "$color" in
    green) color_code="$_TUI_GREEN" ;;
    red)   color_code="$_TUI_RED" ;;
    dim)   color_code="$_TUI_DIM" ;;
  esac
  printf '  %-16s %s%s%s\n' "${key}:" "${color_code}" "$value" "${color_code:+${_TUI_RESET}}"
}

# _tui_badge "label" "color"
# Inline status indicator: [configured] in green, [not set] in dim
_tui_badge() {
  local label="$1" color="${2:-dim}"
  local color_code=""
  case "$color" in
    green)  color_code="$_TUI_GREEN" ;;
    red)    color_code="$_TUI_RED" ;;
    yellow) color_code="$_TUI_YELLOW" ;;
    dim)    color_code="$_TUI_DIM" ;;
  esac
  printf '%s[%s]%s' "${color_code}" "$label" "${color_code:+${_TUI_RESET}}"
}

# _tui_progress current total "label"
# Step-based progress bar: [████░░░░░░] 4/7 Installing AI hooks
_tui_progress() {
  local current="$1" total="$2" label="$3"
  local bar_width=20

  if ! _tui_is_interactive; then
    printf '[%d/%d] %s\n' "$current" "$total" "$label"
    return 0
  fi

  local filled=0
  if [[ "$total" -gt 0 ]]; then
    filled=$(( current * bar_width / total ))
  fi
  local empty=$(( bar_width - filled ))

  # Use UTF-8 blocks if locale supports it, else ASCII
  local fill_char="#" empty_char="-"
  if [[ "${LANG:-}" == *UTF-8* ]] || [[ "${LC_ALL:-}" == *UTF-8* ]] || [[ "${LC_CTYPE:-}" == *UTF-8* ]]; then
    fill_char="█"
    empty_char="░"
  fi

  local bar=""
  local j
  for (( j = 0; j < filled; j++ )); do bar+="$fill_char"; done
  for (( j = 0; j < empty; j++ )); do bar+="$empty_char"; done

  printf '\r  [%s] %d/%d %s' "$bar" "$current" "$total" "$label"
  if [[ "$current" -eq "$total" ]]; then
    printf '\n'
  fi
}

# _tui_multiselect "prompt" option1 option2 ...
# Results in _TUI_MULTISELECTED (space-separated) and _TUI_MULTISELECTED_INDICES
_TUI_MULTISELECTED=""
_TUI_MULTISELECTED_INDICES=""

_tui_multiselect() {
  local prompt="$1"
  shift
  local -a options=("$@")
  local count=${#options[@]}

  # Non-interactive: select all
  if ! _tui_is_interactive; then
    _TUI_MULTISELECTED="${options[*]}"
    local indices=""
    local k
    for (( k=0; k<count; k++ )); do
      indices="${indices:+$indices }$k"
    done
    _TUI_MULTISELECTED_INDICES="$indices"
    return 0
  fi

  printf '%s\n' "$prompt"
  local i
  for (( i=0; i<count; i++ )); do
    printf '  %s%d)%s [ ] %s\n' "${_TUI_BOLD}" $((i + 1)) "${_TUI_RESET}" "${options[@]:$i:1}"
  done
  printf '  Enter numbers (comma-separated), %sa%s=all, %sn%s=none: ' \
    "${_TUI_BOLD}" "${_TUI_RESET}" "${_TUI_BOLD}" "${_TUI_RESET}"

  local reply
  read -r reply </dev/tty

  local -a selected_indices=()

  case "$reply" in
    [aA]|[aA][lL][lL])
      for (( i=0; i<count; i++ )); do
        selected_indices+=("$i")
      done
      ;;
    [nN]|[nN][oO][nN][eE])
      ;;
    *)
      # Parse comma-separated numbers
      local IFS=','
      local -a parts
      read -ra parts <<< "$reply"
      local seen=""
      local p
      for p in "${parts[@]}"; do
        # Trim whitespace
        p="${p#"${p%%[![:space:]]*}"}"
        p="${p%"${p##*[![:space:]]}"}"
        # Validate: must be a number in range, and not duplicate
        if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= count )); then
          local idx=$((p - 1))
          # Dedup check
          if [[ " $seen " != *" $idx "* ]]; then
            selected_indices+=("$idx")
            seen="$seen $idx"
          fi
        fi
      done
      ;;
  esac

  # Build results
  _TUI_MULTISELECTED=""
  _TUI_MULTISELECTED_INDICES=""
  for i in "${selected_indices[@]+"${selected_indices[@]}"}"; do
    _TUI_MULTISELECTED="${_TUI_MULTISELECTED:+$_TUI_MULTISELECTED }${options[@]:$i:1}"
    _TUI_MULTISELECTED_INDICES="${_TUI_MULTISELECTED_INDICES:+$_TUI_MULTISELECTED_INDICES }$i"
  done

  # Show selected items with [x] markers
  for (( i=0; i<count; i++ )); do
    local marker="[ ]"
    local si
    for si in "${selected_indices[@]+"${selected_indices[@]}"}"; do
      if [[ "$si" -eq "$i" ]]; then
        marker="[x]"
        break
      fi
    done
    printf '  %s%d)%s %s %s\n' "${_TUI_BOLD}" $((i + 1)) "${_TUI_RESET}" "$marker" "${options[@]:$i:1}"
  done
}

# _tui_spinner "message" command args...
# Inline spinner while running a background command
_tui_spinner() {
  local message="$1"
  shift

  # Non-interactive: just run the command silently
  if ! _tui_is_interactive; then
    "$@" >/dev/null 2>&1
    return $?
  fi

  local spinner_frames="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local frame_count=10

  # Run command in background
  "$@" >/dev/null 2>&1 &
  local cmd_pid=$!

  # Spinner loop
  local i=0
  local _old_trap
  _old_trap=$(trap -p EXIT)

  _spinner_cleanup() {
    kill "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
    printf '\r%*s\r' $((${#message} + 4)) "" >/dev/tty
    # Restore old trap
    eval "${_old_trap:-trap - EXIT}"
  }
  trap _spinner_cleanup EXIT INT TERM

  while kill -0 "$cmd_pid" 2>/dev/null; do
    # Extract single UTF-8 character from spinner_frames
    # Each braille char is 3 bytes in UTF-8
    local offset=$((i % frame_count * 3))
    local frame="${spinner_frames:$offset:3}"
    printf '\r  %s %s' "$frame" "$message" >/dev/tty
    sleep 0.1
    i=$((i + 1))
  done

  wait "$cmd_pid"
  local exit_code=$?

  # Clear spinner line
  printf '\r%*s\r' $((${#message} + 6)) "" >/dev/tty

  # Restore trap
  eval "${_old_trap:-trap - EXIT}"

  return $exit_code
}
