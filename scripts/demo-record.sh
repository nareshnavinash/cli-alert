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
#   # Dry-run (CI validation, no sleeps or evals):
#   DRY_RUN=true bash scripts/demo-record.sh
#
#   # Or manually:
#   asciinema rec demo.cast --command "bash scripts/demo-record.sh" --cols 110 --rows 35
# =============================================================================

set -euo pipefail

# --- Configuration ---
TYPING_DELAY=0.04    # Delay between characters (seconds)
LINE_PAUSE=1.5       # Pause after a comment line
CMD_PAUSE=2.0        # Pause after a command completes
SECTION_PAUSE=3.0    # Pause between demo sections

# --- DRY_RUN support ---
if [[ "${DRY_RUN:-}" == "true" ]]; then
  TYPING_DELAY=0
  LINE_PAUSE=0
  CMD_PAUSE=0
  SECTION_PAUSE=0
fi

_sleep() {
  [[ "${DRY_RUN:-}" == "true" ]] && return 0
  sleep "$@"
}

# --- Colors ---
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'
PROMPT='\033[1;34m$\033[0m '

# --- Helper Functions ---

# Simulate typing character by character
type_cmd() {
  local text="$1"
  printf "%b" "$PROMPT"
  if [[ "${DRY_RUN:-}" == "true" ]]; then
    printf "%s" "$text"
  else
    for ((i = 0; i < ${#text}; i++)); do
      printf "%s" "${text:$i:1}"
      sleep "$TYPING_DELAY"
    done
  fi
  printf "\n"
}

# Type a command, then execute it (safe commands only)
run_cmd() {
  local cmd="$1"
  type_cmd "$cmd"
  _sleep 0.3
  if [[ "${DRY_RUN:-}" == "true" ]]; then
    echo "[DRY_RUN] would execute: $cmd"
  else
    eval "$cmd"
  fi
  _sleep "$CMD_PAUSE"
}

# Type a command, then print scripted output instead of executing
fake_cmd() {
  local cmd="$1"
  shift
  type_cmd "$cmd"
  _sleep 0.3
  local line
  for line in "$@"; do
    printf "%s\n" "$line"
  done
  _sleep "$CMD_PAUSE"
}

# Simulate user typing text character-by-character (for TUI interactions)
mock_input() {
  local text="$1"
  if [[ "${DRY_RUN:-}" == "true" ]]; then
    printf "%s" "$text"
  else
    for ((i = 0; i < ${#text}; i++)); do
      printf "%s" "${text:$i:1}"
      sleep 0.06
    done
  fi
  printf "\n"
}

# Print a green comment/header
comment() {
  printf "\n%b# %s%b\n" "$GREEN" "$1" "$RESET"
  _sleep "$LINE_PAUSE"
}

# Print a section header with decoration
section() {
  printf "\n"
  printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
  printf "%b  %s%b\n" "$YELLOW" "$1" "$RESET"
  printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
  _sleep "$SECTION_PAUSE"
}

# --- Demo Starts Here ---

clear

section "shelldone — Terminal Notifications for Long-Running Commands"

_sleep 1

# ── Section 1: Install ─────────────────────────────────────────────────────
comment "Install shelldone (git clone + install)"
fake_cmd "git clone https://github.com/nareshnavinash/shelldone.git" \
  "Cloning into 'shelldone'..." \
  "remote: Enumerating objects: 542, done." \
  "remote: Counting objects: 100% (542/542), done." \
  "Receiving objects: 100% (542/542), 128.50 KiB | 2.14 MiB/s, done."

fake_cmd "cd shelldone && ./install.sh" \
  "Installing shelldone..." \
  "  Linking shelldone to /usr/local/bin/shelldone ... done" \
  "  Adding shell hooks to ~/.zshrc ... done" \
  "  shelldone v1.3.0 installed successfully!"

# ── Section 2: Version & Status ───────────────────────────────────────────
section "Check Version & Status"

comment "Show version with build details"
run_cmd "shelldone version --verbose"

comment "Check system status and configuration"
run_cmd "shelldone status"

# ── Section 3: Auto-Notify ─────────────────────────────────────────────────
section "Auto-Notify on Long-Running Commands"

comment "Wrap a command with 'alert' — notifies when done"
comment "(Using a short sleep for demo purposes)"
type_cmd "alert sleep 3"
_sleep 3
printf "✓ sleep Complete (3s) — exit 0\n"
_sleep "$CMD_PAUSE"

# ── Section 4: Quick Setup ─────────────────────────────────────────────────
section "Quick Setup"

comment "Run the non-interactive quick setup (sensible defaults)"
fake_cmd "shelldone setup --quick" \
  "[shelldone] Already in .zshrc, skipping" \
  "[shelldone] Claude Code Stop hook already installed" \
  "[shelldone] Claude Code Notification hook already installed" \
  "[shelldone] Codex CLI Stop hook already installed" \
  "[shelldone] Codex CLI Notification hook already installed" \
  "[shelldone] Gemini CLI hook already installed" \
  "[shelldone] Gemini CLI Notification hook already installed" \
  "[shelldone] AI hooks: 5 installed, 0 skipped (not detected)" \
  "" \
  "[shelldone] Setup complete!" \
  "[shelldone] Restart your shell or run: exec zsh"

# ── Section 5: Interactive Setup Wizard ────────────────────────────────────
section "Interactive Setup Wizard (TUI)"

comment "Launch the full interactive setup wizard"
type_cmd "shelldone setup"
_sleep 0.5

# Welcome dashboard
printf "\n%bshelldone 1.3.0%b setup\n" "$BOLD" "$RESET"
printf "%bPlatform: Darwin | Shell: zsh%b\n\n" "$DIM" "$RESET"

printf "%b── %bCurrent Status%b%b ──────────────────────%b\n" "$DIM" "$BOLD" "$RESET$DIM" "" "$RESET"
printf "  %-16s %b[configured]%b\n" "Shell integration:" "$GREEN" "$RESET"
printf "  %-16s 1 of 6\n" "Channels:"
printf "  %-16s 1 of 3 detected\n" "AI hooks:"
printf "\n"
_sleep "$CMD_PAUSE"

# Mode selection
printf "Choose setup mode:\n"
printf "  %b1)%b Quick (sensible defaults)\n" "$BOLD" "$RESET"
printf "  %b2)%b Advanced (configure everything)\n" "$BOLD" "$RESET"
printf "  %b3)%b Reconfigure (channels & hooks only)\n" "$BOLD" "$RESET"
printf "Choice [1-3]: "
_sleep 0.5
mock_input "2"
_sleep "$CMD_PAUSE"

# Shell integration
printf "\n%b── %bShell Integration%b%b ──────────────────────%b\n" "$DIM" "$BOLD" "$RESET$DIM" "" "$RESET"
printf "%b[2/7]%b Shell integration\n" "$DIM" "$RESET"
printf "  Currently: .zshrc %b[configured]%b\n" "$GREEN" "$RESET"
printf "  Re-apply shell integration? [y/N] "
_sleep 0.3
mock_input "n"
printf "  %bℹ%b Skipped shell integration\n" "\033[34m" "$RESET"
_sleep "$CMD_PAUSE"

# ── Section 5: Channel Dashboard ──────────────────────────────────────────
section "Channel Dashboard"

comment "The advanced wizard shows a live channel dashboard"

printf "\n%b── %bExternal Channels%b%b ──────────────────────%b\n" "$DIM" "$BOLD" "$RESET$DIM" "" "$RESET"
printf "%b[4/7]%b External channels\n\n" "$DIM" "$RESET"
printf "  %-16s %b[configured]%b\n" "Slack:" "$GREEN" "$RESET"
printf "  %-16s %b[not set]%b\n" "Discord:" "$DIM" "$RESET"
printf "  %-16s %b[not set]%b\n" "Telegram:" "$DIM" "$RESET"
printf "  %-16s %b[not set]%b\n" "Email:" "$DIM" "$RESET"
printf "  %-16s %b[not set]%b\n" "WhatsApp:" "$DIM" "$RESET"
printf "  %-16s %b[not set]%b\n" "Webhook:" "$DIM" "$RESET"
printf "\n"
_sleep "$CMD_PAUSE"

printf "Choose an action:\n"
printf "  %b1)%b Add/reconfigure a channel\n" "$BOLD" "$RESET"
printf "  %b2)%b Remove a channel\n" "$BOLD" "$RESET"
printf "  %b3)%b Test a channel\n" "$BOLD" "$RESET"
printf "  %b4)%b Continue to next step\n" "$BOLD" "$RESET"
printf "Choice [1-4]: "
_sleep 0.5
mock_input "3"

printf "\nTest which channel?\n"
printf "  %b1)%b slack\n" "$BOLD" "$RESET"
printf "Choice [1-1]: "
_sleep 0.3
mock_input "1"
printf "\n  Sending test notification to Slack...\n"
printf "  %b✓%b Test sent successfully! (HTTP 200)\n" "$GREEN" "$RESET"
_sleep "$CMD_PAUSE"

printf "\nChoice [1-4]: "
_sleep 0.3
mock_input "4"
_sleep "$CMD_PAUSE"

# ── Section 6: AI Hooks Multiselect ──────────────────────────────────────
section "AI Hook Installation (Multiselect)"

comment "Select which AI CLI hooks to install in one step"

printf "\n%b── %bAI CLI Hooks%b%b ──────────────────────%b\n" "$DIM" "$BOLD" "$RESET$DIM" "" "$RESET"
printf "%b[5/7]%b AI CLI hooks\n\n" "$DIM" "$RESET"

printf "  %-16s %b[installed]%b\n" "Claude Code:" "$GREEN" "$RESET"
printf "  %-16s %b[detected]%b\n" "Codex CLI:" "$YELLOW" "$RESET"
printf "  %-16s %b[detected]%b\n" "Gemini CLI:" "$YELLOW" "$RESET"
printf "\n"
_sleep "$CMD_PAUSE"

printf "Select hooks to install:\n"
printf "  %b1)%b [ ] Claude Code\n" "$BOLD" "$RESET"
printf "  %b2)%b [ ] Codex CLI\n" "$BOLD" "$RESET"
printf "  %b3)%b [ ] Gemini CLI\n" "$BOLD" "$RESET"
printf "  Enter numbers (comma-separated), %ba%b=all, %bn%b=none: " "$BOLD" "$RESET" "$BOLD" "$RESET"
_sleep 0.5
mock_input "a"
printf "  %b1)%b [x] Claude Code\n" "$BOLD" "$RESET"
printf "  %b2)%b [x] Codex CLI\n" "$BOLD" "$RESET"
printf "  %b3)%b [x] Gemini CLI\n" "$BOLD" "$RESET"
_sleep "$CMD_PAUSE"

# Progress bar
printf "\r  [████████████████████] 1/3 Installing Claude Code hook"
_sleep 0.5
printf "\n  %b✓%b Claude Code hook installed\n" "$GREEN" "$RESET"
printf "\r  [████████████████████] 2/3 Installing Codex CLI hook"
_sleep 0.5
printf "\n  %b✓%b Codex CLI hook installed\n" "$GREEN" "$RESET"
printf "\r  [████████████████████] 3/3 Installing Gemini CLI hook"
_sleep 0.5
printf "\n  %b✓%b Gemini CLI hook installed\n\n" "$GREEN" "$RESET"
printf "  %b✓%b 3 AI hook(s) installed\n" "$GREEN" "$RESET"
_sleep "$CMD_PAUSE"

# ── Section 7: Health Check ───────────────────────────────────────────────
section "Health Check"

comment "Run the built-in health check"
run_cmd "shelldone doctor"

# ── Section 8: Notification Sounds ────────────────────────────────────────
section "Notification Sounds"

comment "List available notification sounds"
run_cmd "shelldone sounds"

# ── Section 9: Mute & Schedule ────────────────────────────────────────────
section "Mute & Schedule"

comment "Temporarily mute notifications"
run_cmd "shelldone mute 5m"
run_cmd "shelldone unmute"

# ── Section 10: Webhook Status ────────────────────────────────────────────
section "Webhook Status"

comment "Check webhook / channel status"
run_cmd "shelldone webhook status"

# ── Outro ─────────────────────────────────────────────────────────────────
printf "\n"
printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
printf "%b  %s%b\n" "$GREEN" "That's shelldone! Pure bash, zero dependencies." "$RESET"
printf "%b  %s%b\n" "$GREEN" "GitHub: https://github.com/nareshnavinash/shelldone" "$RESET"
printf "%b%s%b\n" "$CYAN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$RESET"
printf "\n"
_sleep 4
