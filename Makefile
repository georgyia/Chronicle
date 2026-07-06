# Chronicle developer task runner.
# Tooling (swiftlint, swiftformat) is optional locally; targets no-op with a hint if missing.

SWIFT ?= swift
CONFIG ?= debug

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build all targets ($(CONFIG))
	$(SWIFT) build -c $(CONFIG)

.PHONY: release
release: ## Build a release (universal) binary set
	$(SWIFT) build -c release --arch arm64 --arch x86_64

.PHONY: test
test: ## Run the full test suite
	$(SWIFT) test --parallel

.PHONY: coverage
coverage: ## Run tests with code coverage enabled
	$(SWIFT) test --enable-code-coverage --parallel
	@./scripts/coverage.sh

.PHONY: bench
bench: ## Run the benchmark suite
	$(SWIFT) run -c release chronicle-bench

.PHONY: format
format: ## Format sources in place (requires swiftformat)
	@command -v swiftformat >/dev/null 2>&1 \
		&& swiftformat . \
		|| echo "swiftformat not installed; run 'brew install swiftformat'"

.PHONY: format-check
format-check: ## Verify formatting without writing (CI gate)
	@command -v swiftformat >/dev/null 2>&1 \
		&& swiftformat . --lint \
		|| echo "swiftformat not installed; run 'brew install swiftformat'"

.PHONY: lint
lint: ## Lint sources (requires swiftlint)
	@command -v swiftlint >/dev/null 2>&1 \
		&& swiftlint lint --strict \
		|| echo "swiftlint not installed; run 'brew install swiftlint'"

.PHONY: docs
docs: ## Generate DocC documentation
	$(SWIFT) package generate-documentation

.PHONY: completions
completions: build ## Generate shell completion scripts into ./completions
	@mkdir -p completions
	@.build/debug/chronicle --generate-completion-script zsh > completions/_chronicle
	@.build/debug/chronicle --generate-completion-script bash > completions/chronicle.bash
	@.build/debug/chronicle --generate-completion-script fish > completions/chronicle.fish
	@echo "Wrote completions to ./completions"

.PHONY: man
man: ## Generate man pages via the ArgumentParser plugin
	$(SWIFT) package plugin generate-manual --target chronicle --output-directory ./man || \
		echo "Manual generation requires the swift-argument-parser manual plugin"

.PHONY: clean
clean: ## Remove build artifacts
	$(SWIFT) package clean
	rm -rf .build

.PHONY: precommit
precommit: format lint build test ## Run the full local pre-commit gate
