# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Reporting a Vulnerability

If you discover a security issue in cli-alert, please report it responsibly.

**Email:** nareshnavinash@gmail.com

Please include:

- A description of the issue and its potential impact
- Steps to reproduce
- Any relevant environment details (OS, shell, version)

You can expect an initial response within 72 hours. We will work with you to understand the issue and coordinate a fix before any public disclosure.

## Scope

cli-alert is a local shell tool. Security-relevant areas include:

- Command injection via unsanitized input in notification payloads
- Credential exposure (webhook URLs, API tokens) in logs or debug output
- Unsafe temporary file handling
- Unexpected behavior when processing untrusted JSON from Claude Code hooks

Issues outside the project's control (e.g., vulnerabilities in upstream notification daemons or third-party webhook services) are out of scope but appreciated as informational reports.
