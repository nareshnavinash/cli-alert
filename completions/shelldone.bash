#!/usr/bin/env bash
# Bash completion for shelldone

_shelldone_completions() {
  local cur prev commands
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="init setup uninstall status test-notify sounds exclude webhook channel history config doctor mute unmute toggle schedule test version help"

  case "$prev" in
    shelldone)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
      return 0
      ;;
    init)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return 0
      ;;
    setup)
      COMPREPLY=( $(compgen -W "--quick --full all ai-hooks claude-hook codex-hook gemini-hook copilot-hook cursor-hook" -- "$cur") )
      return 0
      ;;
    exclude)
      COMPREPLY=( $(compgen -W "list add remove" -- "$cur") )
      return 0
      ;;
    webhook)
      COMPREPLY=( $(compgen -W "status test" -- "$cur") )
      return 0
      ;;
    channel)
      COMPREPLY=( $(compgen -W "list add remove test" -- "$cur") )
      return 0
      ;;
    history)
      COMPREPLY=( $(compgen -W "show --clear --path" -- "$cur") )
      return 0
      ;;
    config)
      COMPREPLY=( $(compgen -W "show init edit path set get list" -- "$cur") )
      return 0
      ;;
    status)
      COMPREPLY=( $(compgen -W "--full -v" -- "$cur") )
      return 0
      ;;
    uninstall)
      COMPREPLY=( $(compgen -W "--yes -y" -- "$cur") )
      return 0
      ;;
    test)
      if [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "webhook" ]] || [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "channel" ]]; then
        COMPREPLY=( $(compgen -W "slack discord telegram email whatsapp webhook" -- "$cur") )
        return 0
      fi
      ;;
    add|remove)
      if [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "channel" ]]; then
        COMPREPLY=( $(compgen -W "slack discord telegram email whatsapp webhook" -- "$cur") )
        return 0
      fi
      ;;
    set)
      if [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "config" ]]; then
        COMPREPLY=( $(compgen -W "SHELLDONE_ENABLED SHELLDONE_AUTO SHELLDONE_THRESHOLD SHELLDONE_NOTIFY_ON SHELLDONE_SOUND_SUCCESS SHELLDONE_SOUND_FAILURE SHELLDONE_VOICE SHELLDONE_FOCUS_DETECT SHELLDONE_HISTORY SHELLDONE_EXCLUDE SHELLDONE_QUIET_HOURS SHELLDONE_RATE_LIMIT SHELLDONE_WEBHOOK_TIMEOUT" -- "$cur") )
        return 0
      fi
      ;;
    get)
      if [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "config" ]]; then
        COMPREPLY=( $(compgen -W "SHELLDONE_ENABLED SHELLDONE_AUTO SHELLDONE_THRESHOLD SHELLDONE_NOTIFY_ON SHELLDONE_SOUND_SUCCESS SHELLDONE_SOUND_FAILURE SHELLDONE_VOICE SHELLDONE_FOCUS_DETECT SHELLDONE_HISTORY SHELLDONE_EXCLUDE SHELLDONE_QUIET_HOURS SHELLDONE_RATE_LIMIT SHELLDONE_WEBHOOK_TIMEOUT" -- "$cur") )
        return 0
      fi
      ;;
    toggle)
      COMPREPLY=( $(compgen -W "sound desktop voice slack discord telegram email whatsapp webhook external claude codex gemini copilot cursor on off" -- "$cur") )
      return 0
      ;;
    schedule)
      COMPREPLY=( $(compgen -W "off" -- "$cur") )
      return 0
      ;;
    version)
      COMPREPLY=( $(compgen -W "--verbose" -- "$cur") )
      return 0
      ;;
  esac

  return 0
}

complete -F _shelldone_completions shelldone
