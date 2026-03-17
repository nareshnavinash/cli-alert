#!/usr/bin/env bash
# install.sh — Quick installer (downloads or runs from source)
# For package manager users, use brew/apt/scoop instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;34m[shelldone]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[shelldone]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[shelldone]\033[0m %s\n' "$1"; }

# ── Detect platform ─────────────────────────────────────────────────────────
# Keep in sync with lib/shelldone.sh:_shelldone_detect_platform

detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux)
      if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

PLATFORM=$(detect_platform)
info "Detected platform: $PLATFORM"

# ── Make scripts executable ──────────────────────────────────────────────────

chmod +x "${SCRIPT_DIR}/bin/shelldone"
chmod +x "${SCRIPT_DIR}/hooks/"*.sh
chmod +x "${SCRIPT_DIR}/test.sh"
chmod +x "${SCRIPT_DIR}/uninstall.sh"
ok "Made scripts executable"

# ── Add bin to PATH if not already there ─────────────────────────────────────

BIN_DIR="${SCRIPT_DIR}/bin"
if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$BIN_DIR"; then
  info "Adding ${BIN_DIR} to PATH..."
  export PATH="${BIN_DIR}:${PATH}"
fi

# ── Run setup ────────────────────────────────────────────────────────────────

"${BIN_DIR}/shelldone" setup

# ── Check for notification tools ─────────────────────────────────────────────

case "$PLATFORM" in
  darwin)
    if command -v terminal-notifier &>/dev/null; then
      ok "macOS: terminal-notifier available (preferred)"
    else
      warn "macOS: terminal-notifier not found (recommended for proper notification icon)"
      warn "  Install with: brew install terminal-notifier"
      info "  Falling back to osascript (notifications will show Script Editor icon)"
    fi
    ok "macOS: osascript and afplay available (built-in)"
    ;;
  linux)
    if command -v notify-send &>/dev/null; then
      ok "Linux: notify-send available"
    else
      warn "Linux: notify-send not found"
      warn "  Install with: sudo apt install libnotify-bin"
      warn "  Or: sudo dnf install libnotify"
    fi
    ;;
  wsl)
    if command -v powershell.exe &>/dev/null; then
      ok "WSL: powershell.exe available"
    elif command -v wsl-notify-send &>/dev/null; then
      ok "WSL: wsl-notify-send available"
    else
      warn "WSL: no notification tool found"
      warn "  Install wsl-notify-send or BurntToast PowerShell module"
    fi
    ;;
esac

# ── Check for HTTP tools (needed for external notification channels) ──────────

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
  warn "Neither curl nor wget found."
  warn "  External notification channels (Slack, Discord, Telegram, etc.) require curl or wget."
  warn "  Install with: sudo apt install curl  (or: brew install curl)"
fi

echo ""
ok "Installation complete!"
info "Restart your shell or run: exec $(basename "$SHELL")"
info "Test with: alert sleep 2"
