#!/usr/bin/env bash
# =============================================================================
# shelldone Demo Recording Script
# =============================================================================
#
# This script demonstrates shelldone features with simulated typing for
# asciinema recordings. When recorded, it looks like a human typing commands.
#
# Usage:
#   # Direct run (just to preview):
#   bash scripts/demo-record.sh
#
#   # Record with asciinema (recommended):
#   bash scripts/record-demo.sh
#
#   # Or manually:
#   asciinema rec demo.cast --command "bash scripts/demo-record.sh" --cols 100 --rows 30
# =============================================================================

set -euo pipefail

# --- Configuration ---
TYPING_DELAY=0.04    # Delay between characters (seconds)
LINE_PAUSE=1.5       # Pause after a comment line
CMD_PAUSE=2.0        # Pause after a command completes
SECTION_PAUSE=3.0    # Pause between demo sections

# --- Colors ---
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'
PROMPT='\033[1;34m$\033[0m '

# --- Helper Functions ---

# Simulate typing character by character
type_cmd() {
  local text="$1"
  printf "%b" "$PROMPT"
  for ((i = 0; i < ${#text}; i++)); do
    printf "%s" "${text:$i:1}"
    sleep "$TYPING_DELAY"
  done
  printf "\n"
}

# Type a command, then execute it
run_cmd() {
  local cmd="$1"
  type_cmd "$cmd"
  sleep 0.3
  eval "$cmd"
  sleep "$CMD_PAUSE"
}

# Print a green comment/header
comment() {
  printf "\n%b# %s%b\n" "$GREEN" "$1" "$RESET"
  sleep "$LINE_PAUSE"
}

# Print a section header with decoration
section() {
  printf "\n"
  printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
  printf "%b  %s%b\n" "$YELLOW" "$1" "$RESET"
  printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
  sleep "$SECTION_PAUSE"
}

# --- Demo Starts Here ---

clear

section "shelldone — Terminal Notifications for Long-Running Commands"

sleep 1

# Section 1: Install
comment "Install shelldone (git clone + install)"
type_cmd "git clone https://github.com/nareshnavinash/shelldone.git"
printf "Cloning into 'shelldone'...\n"
printf "remote: Enumerating objects: 542, done.\n"
printf "remote: Counting objects: 100%% (542/542), done.\n"
printf "Receiving objects: 100%% (542/542), 128.50 KiB | 2.14 MiB/s, done.\n"
sleep "$CMD_PAUSE"

type_cmd "cd shelldone && ./install.sh"
printf "Installing shelldone...\n"
printf "  Linking shelldone to /usr/local/bin/shelldone ... done\n"
printf "  Adding shell hooks to ~/.zshrc ... done\n"
printf "  shelldone v1.3.0 installed successfully!\n"
sleep "$CMD_PAUSE"

# Section 2: Version
section "Check Version"

comment "Show version with build details"
run_cmd "shelldone version --verbose"

# Section 3: Status / Diagnostics
section "System Diagnostics"

comment "Check system status and configuration"
run_cmd "shelldone status"

# Section 4: Wrap a command
section "Auto-Notify on Long-Running Commands"

comment "Wrap a command with 'alert' — notifies when done"
comment "(Using a short sleep for demo purposes)"
run_cmd "alert sleep 3"

# Section 5: AI CLI Hooks
section "AI CLI Integration"

comment "Set up hooks for Claude Code (also supports Codex, Gemini, Copilot, Cursor)"
run_cmd "shelldone setup claude-hook"

# Section 6: Interactive TUI Setup
section "Interactive TUI Setup"

comment "Launch the interactive setup menu"
type_cmd "shelldone setup"
printf "┌──────────────────────────────────────────┐\n"
printf "│         shelldone — Channel Setup         │\n"
printf "├──────────────────────────────────────────┤\n"
printf "│  1) Slack                                │\n"
printf "│  2) Discord                              │\n"
printf "│  3) Telegram                             │\n"
printf "│  4) Email                                │\n"
printf "│  5) WhatsApp                             │\n"
printf "│  6) Webhook                              │\n"
printf "│  7) AI CLI Hooks                         │\n"
printf "│  q) Quit                                 │\n"
printf "└──────────────────────────────────────────┘\n"
sleep "$CMD_PAUSE"

# Section 7: External Channels
section "External Notification Channels"

comment "Check webhook / channel status (Slack, Discord, Telegram, Email, WhatsApp)"
run_cmd "shelldone webhook status"

# Section 8: Sounds
section "Notification Sounds"

comment "List available notification sounds"
run_cmd "shelldone sounds"

# Outro
printf "\n"
printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
printf "%b  %s%b\n" "$GREEN" "That's shelldone! Pure bash, zero dependencies." "$RESET"
printf "%b  %s%b\n" "$GREEN" "GitHub: https://github.com/nareshnavinash/shelldone" "$RESET"
printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
printf "\n"
sleep 4
