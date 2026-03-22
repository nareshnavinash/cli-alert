# Troubleshooting

## Platform Notes

shelldone has been extensively tested on macOS (bash + zsh) with Claude Code, Gemini CLI, and Codex CLI. Slack is the only external channel validated end-to-end; other channels follow the same HTTP dispatch pattern. Linux, WSL, and Windows support is based on consistent bash/zsh behavior across operating systems and platform-specific code paths for notification delivery.

If you encounter a platform-specific or channel-specific issue, the project is [MIT licensed](https://github.com/nareshnavinash/shelldone/blob/main/LICENSE) - contributions and bug reports are welcome.

## Quick Diagnosis

```bash
shelldone status
```

This shows your platform, available notification tools, current config, shell integration status, AI CLI hook status, and external channel configuration.

## Debug Mode

**Desktop notifications:**

```bash
export SHELLDONE_DEBUG=true
alert echo hello
```

Prints detailed debug output to stderr showing platform detection, notification routing, and sound playback.

**External notifications:**

```bash
export SHELLDONE_EXTERNAL_DEBUG=true
alert echo hello
```

Prints HTTP transport selection, POST targets (URLs redacted), and per-channel success/failure with HTTP status codes.

## Common Issues

### No notification appears

- Run `shelldone status` to check notification tools are available
- Run `shelldone test-notify` to send a test notification
- On macOS: check System Settings > Notifications for terminal app permissions
- On Linux: install `libnotify-bin` (`apt install libnotify-bin`)

### No sound plays

- Run `shelldone sounds` to see available sounds
- Check that the sound file exists: `ls /System/Library/Sounds/` (macOS)
- Try a custom path: `export SHELLDONE_SOUND_SUCCESS=/path/to/sound.aiff`

### Auto-notify not working

- Ensure `SHELLDONE_AUTO=true` (default)
- Check threshold: `SHELLDONE_THRESHOLD=10` means commands must run 10+ seconds
- Check exclusions: `shelldone exclude list`
- Ensure shell integration is loaded: `shelldone status` shows rc file status

### External notifications not arriving

- Run `shelldone webhook status` to verify channel config
- Test a specific channel: `shelldone webhook test slack`
- Enable debug output: `export SHELLDONE_EXTERNAL_DEBUG=true`
- Ensure `curl` or `wget` is installed (required for HTTPS channels)
- Check for HTTP errors: test output shows the HTTP status code on failure
- Verify rate limiting isn't blocking: default is 10 seconds between notifications per channel

### External notifications work from shell but not from AI CLI hooks

- AI hooks run as separate processes that don't inherit your shell's `export` variables
- Persist your webhook URL in the config file: `shelldone config edit` (uncomment the relevant line)
- Or add the `export` to `.zshrc`/`.bashrc` and **restart the AI CLI** so it inherits the variable
- See [Persisting Channel Configuration](external-channels.md#persisting-channel-configuration) for details

### AI CLI hooks not firing

- Run `shelldone status` to check hook installation for all AI CLIs
- Re-install a specific hook: `shelldone setup claude-hook` (or `codex-hook`, `gemini-hook`, etc.)
- Re-install all: `shelldone setup ai-hooks`
- Verify the AI CLI's settings file contains the hook entry
- Requires `python3` for installation (hooks use it for JSON parsing)
- Check per-AI toggle: `shelldone toggle` shows if a hook is toggled off

### Focus detection suppressing notifications

- Disable: `export SHELLDONE_FOCUS_DETECT=false`
- Or add your terminal to the detection list: `export SHELLDONE_TERMINALS="Terminal iTerm2 Alacritty MyTerminal"`
- Note: focus detection only works on macOS (AppleScript) and Linux (xdotool)
