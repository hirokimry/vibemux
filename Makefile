.PHONY: setup-hooks lint test check install

setup-hooks:
	git config core.hooksPath .githooks

lint:
	shellcheck aimux .githooks/pre-commit .githooks/pre-push

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
	mkdir -p ~/.local/bin
	ln -sf "$(CURDIR)/aimux" ~/.local/bin/aimux
	@echo "Installed: ~/.local/bin/aimux"
