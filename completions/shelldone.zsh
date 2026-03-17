#compdef cli-alert
# Zsh completion for cli-alert

_cli-alert() {
  local -a commands
  commands=(
    'init:Output shell init code (use with eval)'
    'setup:Configure shell rc files and AI CLI hooks'
    'uninstall:Remove shell integration and AI CLI hooks'
    'status:Show diagnostic info and verify setup'
    'test-notify:Send a test notification'
    'sounds:List available system sounds'
    'exclude:Manage auto-notify exclusion list'
    'webhook:Manage external notification channels'
    'history:View notification history'
    'config:Manage config file'
    'mute:Mute all notifications'
    'unmute:Resume notifications'
    'toggle:Toggle notification layers'
    'schedule:Set daily quiet hours'
    'test:Run verification tests'
    'version:Show version'
    'help:Show help'
  )

  _arguments -C \
    '1:command:->command' \
    '*::arg:->args'

  case "$state" in
    command)
      _describe -t commands 'cli-alert command' commands
      ;;
    args)
      case "${words[1]}" in
        init)
          _describe -t shells 'shell' '(bash zsh)'
          ;;
        setup)
          _describe -t actions 'action' '(all ai-hooks claude-hook codex-hook gemini-hook copilot-hook cursor-hook)'
          ;;
        exclude)
          _describe -t actions 'action' '(list add remove)'
          ;;
        webhook)
          if (( CURRENT == 2 )); then
            _describe -t actions 'action' '(status test)'
          elif [[ "${words[2]}" == "test" ]] && (( CURRENT == 3 )); then
            _describe -t channels 'channel' '(slack discord telegram email whatsapp webhook)'
          fi
          ;;
        history)
          _describe -t actions 'action' '(show --clear --path)'
          ;;
        config)
          _describe -t actions 'action' '(show init edit path)'
          ;;
        toggle)
          if (( CURRENT == 2 )); then
            _describe -t layers 'layer' '(sound desktop voice slack discord telegram email whatsapp webhook external claude codex gemini copilot cursor)'
          elif (( CURRENT == 3 )); then
            _describe -t states 'state' '(on off)'
          fi
          ;;
        schedule)
          _describe -t actions 'action' '(off)'
          ;;
        version)
          _describe -t flags 'flag' '(--verbose)'
          ;;
      esac
      ;;
  esac
}

_cli-alert "$@"
