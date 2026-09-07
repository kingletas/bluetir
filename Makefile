SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
PREFIX ?= $(HOME)/bin
CONFIG ?= $(ROOT_DIR)/etc/bluetir.yml

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# --- setup ---

.PHONY: setup
setup: ## Install the gems this project needs
	@bundle install

.PHONY: config
config: ## Create etc/bluetir.yml from the sample, if it does not exist
	@if [[ -f "$(ROOT_DIR)/etc/bluetir.yml" ]]; then \
		echo "etc/bluetir.yml already exists, leaving it alone"; \
	else \
		cp "$(ROOT_DIR)/etc/bluetir.yml.sample" "$(ROOT_DIR)/etc/bluetir.yml"; \
		echo "wrote etc/bluetir.yml — point base_url at your store"; \
	fi

# --- checks ---

.PHONY: check
check: lint test ## Everything a commit has to pass

.PHONY: lint
lint: ## Check style with RuboCop
	@bundle exec rubocop

.PHONY: test
test: ## Run the unit suite, which needs no browser
	@bundle exec rake test

.PHONY: test-browser
test-browser: ## Run the flows through a real headless browser
	@bundle exec rake test:browser

# --- running ---

.PHONY: plan
plan: ## Show what a run would do, without opening a browser
	@$(ROOT_DIR)/bin/bluetir -n -c "$(CONFIG)"

.PHONY: run
run: ## Place an order against the configured store
	@$(ROOT_DIR)/bin/bluetir -c "$(CONFIG)"

.PHONY: pages
pages: ## Check every page named in the assertions file
	@$(ROOT_DIR)/bin/bluetir -m pages -c "$(CONFIG)"

# --- install ---

.PHONY: install
install: ## Put bluetir on PATH in $(PREFIX)
	@mkdir -p "$(PREFIX)"
	@printf '#!/usr/bin/env bash\n# Written by `make install`. Bluetir runs from its checkout, so this\n# points at it rather than being a copy that cannot find its own library.\nexec "%s/bin/bluetir" "$$@"\n' "$(ROOT_DIR)" > "$(PREFIX)/bluetir"
	@chmod 0755 "$(PREFIX)/bluetir"
	@echo "installed $(PREFIX)/bluetir -> $(ROOT_DIR)/bin/bluetir"
	@echo "note: it runs from $(ROOT_DIR), so keep this checkout in place"

.PHONY: uninstall
uninstall: ## Remove bluetir from $(PREFIX)
	@rm -f "$(PREFIX)/bluetir"
	@echo "removed $(PREFIX)/bluetir"
