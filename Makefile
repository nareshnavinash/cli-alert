PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/cli-alert
HOOKDIR = $(PREFIX)/share/cli-alert/hooks
BASH_COMPDIR = $(PREFIX)/share/bash-completion/completions
ZSH_COMPDIR = $(PREFIX)/share/zsh/site-functions
VERSION = $(shell cat VERSION)

.PHONY: install uninstall test

install:
	@echo "Installing cli-alert $(VERSION) to $(PREFIX)..."
	install -d $(BINDIR)
	install -d $(LIBDIR)
	install -d $(HOOKDIR)
	install -d $(BASH_COMPDIR)
	install -d $(ZSH_COMPDIR)
	install -m 755 bin/cli-alert $(BINDIR)/cli-alert
	install -m 644 lib/cli-alert.sh $(LIBDIR)/cli-alert.sh
	install -m 644 lib/external-notify.sh $(LIBDIR)/external-notify.sh
	install -m 644 lib/auto-notify.zsh $(LIBDIR)/auto-notify.zsh
	install -m 644 lib/auto-notify.bash $(LIBDIR)/auto-notify.bash
	install -m 644 lib/state.sh $(LIBDIR)/state.sh
	install -m 644 lib/ai-hook-common.sh $(LIBDIR)/ai-hook-common.sh
	install -m 755 hooks/claude-done.sh $(HOOKDIR)/claude-done.sh
	install -m 755 hooks/codex-done.sh $(HOOKDIR)/codex-done.sh
	install -m 755 hooks/gemini-done.sh $(HOOKDIR)/gemini-done.sh
	install -m 755 hooks/copilot-done.sh $(HOOKDIR)/copilot-done.sh
	install -m 755 hooks/cursor-done.sh $(HOOKDIR)/cursor-done.sh
	install -m 644 VERSION $(PREFIX)/share/cli-alert/VERSION
	install -m 644 completions/cli-alert.bash $(BASH_COMPDIR)/cli-alert
	install -m 644 completions/cli-alert.zsh $(ZSH_COMPDIR)/_cli-alert
	@echo "Installed! Run: cli-alert setup"

uninstall:
	@echo "Removing cli-alert from $(PREFIX)..."
	rm -f $(BINDIR)/cli-alert
	rm -rf $(LIBDIR)
	rm -rf $(PREFIX)/share/cli-alert
	rm -f $(BASH_COMPDIR)/cli-alert
	rm -f $(ZSH_COMPDIR)/_cli-alert
	@echo "Removed. Run 'cli-alert uninstall' first to clean shell rc files."

test:
	@bash test.sh
