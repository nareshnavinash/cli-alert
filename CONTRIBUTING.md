# Contributing to shelldone

Thank you for your interest in contributing! This document explains how to get started.

## Development Setup

```bash
git clone https://github.com/nareshnavinash/shelldone.git
cd shelldone
bash test.sh   # run the full test suite (374 tests)
```

No build step is required — shelldone is pure shell script.

## Code Style

- All shell scripts must pass **ShellCheck** with zero warnings:
  ```bash
  shellcheck bin/shelldone lib/*.sh hooks/*.sh install.sh uninstall.sh test.sh completions/shelldone.bash
  shellcheck -s bash completions/shelldone.zsh
  ```
- Target **bash 4.0+** compatibility. Avoid bashisms that require 5.x.
- Use `local` for all function variables.
- Prefix internal functions with `_shelldone_`.
- Use double-source guards (`[[ -n "${_SHELLDONE_LOADED:-}" ]] && return`) in library files.

## Adding a New External Channel

1. Add the channel function `_shelldone_external_<name>()` in `lib/external-notify.sh`.
2. Wrap the HTTP call in the `if _shelldone_http_post ...; then ... else ... fi` pattern.
3. Add validation to `_shelldone_validate_channel()`.
4. Add a dispatch line in `_shelldone_notify_external()`.
5. Add status display in the `cmd_webhook` status block (`bin/shelldone`).
6. Add tests (unit, integration, E2E) in `test.sh`.
7. Document the channel in `README.md` under **External Notifications**.

## Running Tests

```bash
bash test.sh
```

All 374 tests must pass before submitting a PR. Tests cover unit, integration, and end-to-end scenarios including mock HTTP servers.

## Pull Request Guidelines

1. Fork the repo and create a feature branch: `git checkout -b feature/my-feature`
2. Keep commits focused — one logical change per commit.
3. Ensure all tests pass and ShellCheck reports no warnings.
4. Update `README.md` if your change adds user-facing functionality.
5. Link the relevant issue in your PR description, if one exists.

## License

By submitting a contribution, you agree that your work will be licensed under the project's [MIT License](LICENSE) (inbound = outbound).
