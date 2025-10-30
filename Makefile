# include .env file and export its env vars.
-include .env
export

.PHONY: all
all: help

## Solidity
.PHONY: build
build: ## Build Solidity contracts using forge
	forge build

.PHONY: export-abi
export-abi: build ## Export contracts ABI
	@echo 'Exporting ABI for smart contracts'
	mkdir -p ./abi-export
	for contract in IConsumptionRecord ConsumptionRecordUpgradeable \
		IConsumptionRecordAmendment ConsumptionRecordAmendmentUpgradeable \
		IConsumptionUnit ConsumptionUnitUpgradeable \
		ITributeDraft TributeDraftUpgradeable \
		ISoulBoundToken SoulBoundTokenBase \
		ICRARegistry CRARegistryUpgradeable ICRAAware; \
	do \
		cat ./out/$${contract}.sol/$${contract}.json | jq -r '.abi' > ./abi-export/$${contract}.json; \
	done

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

## Deployment
.PHONY: predict-local
predict-local: build ## Predict contract addresses local
	forge script script/PredictAddresses.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast

.PHONY: deploy-local
deploy-local: build ## Deploy contracts to local Anvil node
	forge script script/DeployUpgradeable.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		-vvvv

.PHONY: upgrade-local
upgrade-local: build ## Upgrade contracts at local Anvil node
	forge script script/UpgradeImplementations.s.sol \
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
