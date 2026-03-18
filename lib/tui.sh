#!/usr/bin/env bash
# tui.sh — Terminal UI utilities for shelldone
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
    _TUI_SELECTED="${options[0]}"
    _TUI_SELECTED_INDEX=0
    return 0
  fi

  printf '%s\n' "$prompt"
  local i
  for i in "${!options[@]}"; do
    printf '  %s%d)%s %s\n' "${_TUI_BOLD}" $((i + 1)) "${_TUI_RESET}" "${options[$i]}"
  done

  while true; do
    printf 'Choice [1-%d]: ' "$count"
    local reply
    read -r reply </dev/tty
    if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= count )); then
      _TUI_SELECTED="${options[$((reply - 1))]}"
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
