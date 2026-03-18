#compdef shelldone
# Zsh completion for shelldone

_shelldone() {
  local -a commands
  commands=(
    'init:Output shell init code (use with eval)'
    'setup:Interactive setup wizard'
    'uninstall:Remove shell integration and AI CLI hooks'
    'status:Quick status overview'
    'test-notify:Send a test notification'
    'sounds:List available system sounds'
    'exclude:Manage auto-notify exclusion list'
    'webhook:Manage external notification channels'
    'channel:Guided channel setup and management'
    'history:View notification history'
    'config:Manage config file and settings'
    'doctor:Check configuration for issues'
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
      _describe -t commands 'shelldone command' commands
      ;;
    args)
      case "${words[1]}" in
        init)
          _describe -t shells 'shell' '(bash zsh)'
          ;;
        setup)
          _describe -t actions 'action' '(--quick --full all ai-hooks claude-hook codex-hook gemini-hook copilot-hook cursor-hook)'
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
        channel)
          if (( CURRENT == 2 )); then
            _describe -t actions 'action' '(list add remove test)'
          elif (( CURRENT == 3 )); then
            _describe -t channels 'channel' '(slack discord telegram email whatsapp webhook)'
          fi
          ;;
        history)
          _describe -t actions 'action' '(show --clear --path)'
          ;;
        config)
          if (( CURRENT == 2 )); then
            _describe -t actions 'action' '(show init edit path set get list)'
          elif [[ "${words[2]}" == "set" || "${words[2]}" == "get" ]] && (( CURRENT == 3 )); then
            _describe -t keys 'config key' '(SHELLDONE_ENABLED SHELLDONE_AUTO SHELLDONE_THRESHOLD SHELLDONE_NOTIFY_ON SHELLDONE_SOUND_SUCCESS SHELLDONE_SOUND_FAILURE SHELLDONE_VOICE SHELLDONE_FOCUS_DETECT SHELLDONE_HISTORY SHELLDONE_EXCLUDE SHELLDONE_QUIET_HOURS SHELLDONE_RATE_LIMIT SHELLDONE_WEBHOOK_TIMEOUT)'
          fi
          ;;
        status)
          _describe -t flags 'flag' '(--full -v)'
          ;;
        uninstall)
          _describe -t flags 'flag' '(--yes -y)'
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

_shelldone "$@"
