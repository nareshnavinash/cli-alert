#!/usr/bin/env bash
# Bash completion for cli-alert

_cli_alert_completions() {
  local cur prev commands
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="init setup uninstall status test-notify sounds exclude webhook history config mute unmute toggle schedule test version help"

  case "$prev" in
    cli-alert)
      COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
      return 0
      ;;
    init)
      COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
      return 0
      ;;
    setup)
      COMPREPLY=( $(compgen -W "all ai-hooks claude-hook codex-hook gemini-hook copilot-hook cursor-hook" -- "$cur") )
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
    history)
      COMPREPLY=( $(compgen -W "show --clear --path" -- "$cur") )
      return 0
      ;;
    config)
      COMPREPLY=( $(compgen -W "show init edit path" -- "$cur") )
      return 0
      ;;
    test)
      if [[ "${COMP_WORDS[COMP_CWORD-2]:-}" == "webhook" ]]; then
        COMPREPLY=( $(compgen -W "slack discord telegram email whatsapp webhook" -- "$cur") )
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

complete -F _cli_alert_completions cli-alert
