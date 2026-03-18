PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
LIBDIR = $(PREFIX)/lib/shelldone
HOOKDIR = $(PREFIX)/share/shelldone/hooks
BASH_COMPDIR = $(PREFIX)/share/bash-completion/completions
ZSH_COMPDIR = $(PREFIX)/share/zsh/site-functions
VERSION = $(shell cat VERSION)

.PHONY: install uninstall test help

install:
	@echo "Installing shelldone $(VERSION) to $(PREFIX)..."
	install -d $(BINDIR)
	install -d $(LIBDIR)
	install -d $(HOOKDIR)
	install -d $(BASH_COMPDIR)
	install -d $(ZSH_COMPDIR)
	install -m 755 bin/shelldone $(BINDIR)/shelldone
	install -m 644 lib/shelldone.sh $(LIBDIR)/shelldone.sh
	install -m 644 lib/external-notify.sh $(LIBDIR)/external-notify.sh
	install -m 644 lib/auto-notify.zsh $(LIBDIR)/auto-notify.zsh
	install -m 644 lib/auto-notify.bash $(LIBDIR)/auto-notify.bash
	install -m 644 lib/state.sh $(LIBDIR)/state.sh
	install -m 644 lib/ai-hook-common.sh $(LIBDIR)/ai-hook-common.sh
	install -m 644 lib/tui.sh $(LIBDIR)/tui.sh
	install -m 755 hooks/claude-done.sh $(HOOKDIR)/claude-done.sh
	install -m 755 hooks/claude-notify.sh $(HOOKDIR)/claude-notify.sh
	install -m 755 hooks/codex-done.sh $(HOOKDIR)/codex-done.sh
	install -m 755 hooks/codex-notify.sh $(HOOKDIR)/codex-notify.sh
	install -m 755 hooks/gemini-done.sh $(HOOKDIR)/gemini-done.sh
	install -m 755 hooks/gemini-notify.sh $(HOOKDIR)/gemini-notify.sh
	install -m 755 hooks/copilot-done.sh $(HOOKDIR)/copilot-done.sh
	install -m 755 hooks/copilot-notify.sh $(HOOKDIR)/copilot-notify.sh
	install -m 755 hooks/cursor-done.sh $(HOOKDIR)/cursor-done.sh
	install -m 755 hooks/cursor-notify.sh $(HOOKDIR)/cursor-notify.sh
	install -m 644 VERSION $(PREFIX)/share/shelldone/VERSION
	install -m 644 completions/shelldone.bash $(BASH_COMPDIR)/shelldone
	install -m 644 completions/shelldone.zsh $(ZSH_COMPDIR)/_shelldone
	@echo "Installed! Run: shelldone setup"

uninstall:
	@echo "Removing shelldone from $(PREFIX)..."
	rm -f $(BINDIR)/shelldone
	rm -rf $(LIBDIR)
	rm -rf $(PREFIX)/share/shelldone
	rm -f $(BASH_COMPDIR)/shelldone
	rm -f $(ZSH_COMPDIR)/_shelldone
	@echo "Removed. Run 'shelldone uninstall' first to clean shell rc files."

test:
	@bash test.sh

help:
	@echo "shelldone $(VERSION)"
	@echo ""
	@echo "Targets:"
	@echo "  install     Install shelldone to PREFIX (default: /usr/local)"
	@echo "  uninstall   Remove shelldone from PREFIX"
	@echo "  test        Run the test suite"
	@echo "  help        Show this help message"
	@echo ""
	@echo "Options:"
	@echo "  PREFIX=path  Installation prefix (default: /usr/local)"
