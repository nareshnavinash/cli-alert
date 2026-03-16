#!/usr/bin/env bash
# uninstall.sh — Clean removal of cli-alert
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use the CLI if available, otherwise do it inline
if [[ -x "${SCRIPT_DIR}/bin/cli-alert" ]]; then
  exec "${SCRIPT_DIR}/bin/cli-alert" uninstall
fi

# Fallback: inline removal
MARKER_BEGIN="# >>> cli-alert >>>"
MARKER_END="# <<< cli-alert <<<"

ok() { printf '\033[1;32m[cli-alert]\033[0m %s\n' "$1"; }
info() { printf '\033[1;34m[cli-alert]\033[0m %s\n' "$1"; }

_uninstall_tmp_file=""
_uninstall_cleanup() { [[ -n "$_uninstall_tmp_file" ]] && rm -f "$_uninstall_tmp_file" 2>/dev/null; }
trap _uninstall_cleanup EXIT

remove_from_rc() {
  local rc_file="$1"
  [[ ! -f "$rc_file" ]] && return 0
  if ! grep -qF "$MARKER_BEGIN" "$rc_file" 2>/dev/null; then
    info "Not in $(basename "$rc_file"), skipping"
    return 0
  fi
  local tmp_file
  tmp_file=$(mktemp)
  _uninstall_tmp_file="$tmp_file"
  local in_block=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$MARKER_BEGIN" ]]; then in_block=1; continue; fi
    if [[ "$line" == "$MARKER_END" ]]; then in_block=0; continue; fi
    [[ $in_block -eq 0 ]] && printf '%s\n' "$line" >> "$tmp_file"
  done < "$rc_file"
  mv "$tmp_file" "$rc_file"
  ok "Removed from $rc_file"
}

remove_from_rc "$HOME/.zshrc"
remove_from_rc "$HOME/.bashrc"

echo ""
ok "Uninstalled! Restart your shell to apply."
