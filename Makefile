# include .env file and export its env vars.
-include .env
export

.PHONY: all
all: help

## Solidity
.PHONY: build
build: ## Build Solidity contracts using forge
	forge build

.PHONY: test
test: ## Test Solidity contracts using forge
	forge test

.PHONY: fmt
fmt:  ## Format code
	forge fmt

.PHONY: coverage
coverage: build ## Run coverage report
	forge coverage --report lcov
	genhtml ./lcov.info -o coverage --ignore-errors category --branch-coverage
	open ./coverage/index.html

.PHONY: clean
clean: ## Clean up forge artifacts
	forge clean

.PHONY: clean-all
clean-all: clean ## Clean all build artifacts and caches
	rm -rf ./out
	rm -rf ./build
	rm -rf ./cache

## Anvil Local Deployment
.PHONY: anvil
anvil: ## Start local Anvil node
	anvil

## Deploy contracts to local Anvil node
.PHONY: deploy-local
deploy-local:
	forge script script/DeployUpgradeable.s.sol:DeployUpgradeable \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		-vvvv



GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
CYAN   := $(shell tput -Txterm setaf 6)
RESET  := $(shell tput -Txterm sgr0)

## Help
.PHONY: help
help: ## Show this help
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "    ${YELLOW}%-30s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "  ${CYAN}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)
