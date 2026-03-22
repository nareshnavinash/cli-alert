# External Channels

Get notified on Slack, Discord, Telegram, email, WhatsApp, or any webhook endpoint. External notifications fire even when the terminal is focused - ideal for monitoring from your phone or another device.

> **Slack** is the only external channel tested end-to-end with real webhook delivery. Discord, Telegram, Email, WhatsApp, and generic webhooks all follow the same HTTP dispatch pattern and should work correctly. If you encounter an issue with a specific channel, the project is [MIT licensed](https://github.com/nareshnavinash/shelldone/blob/main/LICENSE) - bug reports and fixes are welcome.

## Channel Setup

### Slack

1. Go to [api.slack.com/apps](https://api.slack.com/apps) > Create New App > From scratch
2. Enable **Incoming Webhooks** > Activate > **Add New Webhook to Workspace**
3. Select a channel and copy the webhook URL

```bash
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

Optional:

```bash
export SHELLDONE_SLACK_USERNAME="my-bot"     # default: shelldone
export SHELLDONE_SLACK_CHANNEL="#alerts"      # override channel
```

### Discord

1. Open Server Settings > Integrations > Webhooks > **New Webhook**
2. Select a channel, copy the webhook URL

```bash
export SHELLDONE_DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
```

Optional:

```bash
export SHELLDONE_DISCORD_USERNAME="my-bot"   # default: shelldone
```

### Telegram

1. Message [@BotFather](https://t.me/BotFather) > `/newbot` > copy the bot token
2. Send a message to your bot, then get your chat ID:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1
   ```

```bash
export SHELLDONE_TELEGRAM_TOKEN="123456:ABC-DEF..."
export SHELLDONE_TELEGRAM_CHAT_ID="your-chat-id"
```

### Email

Requires `sendmail` or `mail` command on the system.

```bash
export SHELLDONE_EMAIL_TO="you@example.com"
```

Optional:

```bash
export SHELLDONE_EMAIL_FROM="alerts@myhost.com"        # default: shelldone@<hostname>
export SHELLDONE_EMAIL_SUBJECT="[deploy] finished"     # default: [shelldone] <title>
```

### WhatsApp (via Twilio)

```bash
export SHELLDONE_WHATSAPP_API_URL="https://api.twilio.com/2010-04-01/Accounts/.../Messages.json"
export SHELLDONE_WHATSAPP_TOKEN="base64-encoded-sid:token"
export SHELLDONE_WHATSAPP_FROM="+14155238886"
export SHELLDONE_WHATSAPP_TO="+1234567890"
```

All four variables are required.

### Generic Webhook

```bash
export SHELLDONE_WEBHOOK_URL="https://your-endpoint.com/hook"
export SHELLDONE_WEBHOOK_HEADERS="Authorization: Bearer token123|X-Custom: value"  # optional, pipe-separated
```

The webhook receives a JSON payload:

```json
{
  "title": "make Complete",
  "message": "\u2713 make build (2m 15s, exit 0)",
  "exit_code": 0
}
```

## Persisting Channel Configuration

AI CLI hooks (Claude Code, Codex, Gemini, Copilot, Cursor) run as **separate processes** spawned by the AI tool - they do **not** inherit your shell's environment variables. If you only set a webhook via `export` in your terminal, `shelldone webhook test slack` will work from that shell, but hooks triggered by AI CLIs will not have the variable.

There are two ways to ensure hooks can access your channel configuration:

**Option 1: Config file (recommended)**

Add your webhook URLs to `~/.config/shelldone/config`. Hooks read this file on every invocation, regardless of environment:

```bash
shelldone config edit
# Uncomment and fill in the relevant lines:
# export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

**Option 2: Shell profile**

Add the `export` to your `.zshrc` or `.bashrc` **before** starting the AI CLI. The AI tool inherits the variable at launch and passes it to hooks:

```bash
# In .zshrc or .bashrc (BEFORE eval "$(shelldone init zsh)")
export SHELLDONE_SLACK_WEBHOOK="https://hooks.slack.com/services/T.../B.../xxx"
```

> **Why `export` alone doesn't work:** `export` sets a variable in the current shell and its future children. It cannot update already-running processes. If you export a webhook URL after starting Claude Code, Claude Code's process (and its hooks) won't see it. You'd need to restart the AI CLI for it to pick up the new variable.

## Dispatch Flow

```
_shelldone_notify_external(title, message, exit_code)
         |
         v
  [Collect metadata: hostname, pwd, project, git branch]
         |
         v
  [For each configured channel:]
         |
    +----+----+----+----+----+----+
    |    |    |    |    |    |    |
  Slack Disc Tele Email WApp Hook (skip if var unset)
    |
    v
  [_shelldone_channel_enabled?]---no---> skip
    |yes
    v
  [Rate limit check]
    |
    +---> Read /tmp/.shelldone_rate_<channel>
    +---> If elapsed < SHELLDONE_RATE_LIMIT ---> skip
    |clear
    v
  [Build channel-specific JSON payload]
    |
    +---> Slack: Block Kit with header, fields, context
    +---> Discord: embed with color sidebar
    +---> Telegram: HTML formatted via Bot API
    +---> Email: sendmail/mail with key=value body
    +---> WhatsApp: Twilio API
    +---> Webhook: generic JSON POST
    |
    v
  [HTTP transport: curl > wget > /dev/tcp]
    |
    v
  [POST with timeout (SHELLDONE_WEBHOOK_TIMEOUT)]
    |
    v
  [Update rate stamp file]
    |
    v
  [Clean up metadata vars]
```

## Settings

| Variable | Default | Description |
|---|---|---|
| `SHELLDONE_RATE_LIMIT` | `10` | Min seconds between notifications per channel |
| `SHELLDONE_WEBHOOK_TIMEOUT` | `5` | HTTP timeout in seconds |
| `SHELLDONE_EXTERNAL_DEBUG` | `false` | Log external notification attempts to stderr |

## Testing & Verifying Channels

```bash
shelldone webhook status              # show transport, channels, rate limit
shelldone webhook test slack           # send a test message to Slack
shelldone webhook test discord         # test Discord
shelldone webhook test telegram        # test Telegram
shelldone webhook test email           # test Email
shelldone webhook test whatsapp        # test WhatsApp
shelldone webhook test webhook         # test generic webhook
```

The test command validates all required variables upfront, shows success/failure with the HTTP status code, and is not subject to rate limiting:

```
$ shelldone webhook test slack
Sending test to slack...
[shelldone] Test sent successfully! (HTTP 200)

$ shelldone webhook test slack   # with a bad URL
Sending test to slack...
[shelldone] Test FAILED. (HTTP 403)
[shelldone] Run with SHELLDONE_EXTERNAL_DEBUG=true for details.
```

> **Note:** Slack, Discord, Telegram, and WhatsApp require `curl` or `wget` (HTTPS). The generic webhook can use `/dev/tcp` for plain HTTP endpoints if neither is available.
