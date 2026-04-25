.PHONY: setup-hooks lint test check install

setup-hooks:
	git config core.hooksPath .githooks

lint:
	shellcheck vibemux .githooks/pre-commit .githooks/pre-push .claude/bin/tmux

test:
	@if [ -d tests ]; then \
		for t in tests/test_*; do \
			[ -x "$$t" ] && echo "Running $$t..." && "$$t"; \
		done; \
	else \
		echo "No tests/ directory found, skipping."; \
	fi

check: lint test

install:
	@mkdir -p ~/.local/bin
	@ln -sf "$(CURDIR)/vibemux" ~/.local/bin/vibemux
	@echo "Installed: ~/.local/bin/vibemux -> $(CURDIR)/vibemux"
	@case ":$$PATH:" in \
		*":$$HOME/.local/bin:"*) \
			echo "Ready: run 'vibemux' from anywhere." ;; \
		*) \
			echo ""; \
			echo "WARNING: ~/.local/bin is not in \$$PATH."; \
			echo "Add the following line to your shell rc file (~/.zshrc, ~/.bashrc):"; \
			echo ""; \
			echo "    export PATH=\"\$$HOME/.local/bin:\$$PATH\""; \
			echo "" ;; \
	esac
