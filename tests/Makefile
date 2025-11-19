# Gnoswap Deployment and Testing Makefile
# 
# Usage:
#   make deploy ENV=local          # Deploy to local environment
#   make deploy ENV=dev            # Deploy to dev environment
#   make test-pool ENV=dev         # Run pool tests on dev environment
#   make test-all ENV=staging      # Run all tests on staging environment
#
# Available environments: local, dev, staging
# Default environment: local

# Default environment
ENV ?= default

# Load environment-specific configuration
include scripts/config/$(ENV).mk

# Token Paths
GNS_PATH := gno.land/r/gnoswap/gns
USDC_PATH := gno.land/r/gnoswap/test_token/usdc
BAZ_PATH := gno.land/r/gnoswap/test_token/baz
BAR_PATH := gno.land/r/gnoswap/test_token/bar
OBL_PATH := gno.land/r/gnoswap/test_token/obl
QUX_PATH := gno.land/r/gnoswap/test_token/qux
FOO_PATH := gno.land/r/gnoswap/test_token/foo

# Color output for better readability
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help
help:
	@echo "$(BLUE)Gnoswap Deployment and Testing$(NC)"
	@echo ""
	@echo "$(GREEN)Environment Commands:$(NC)"
	@echo "  make info ENV=<env>                 - Show current environment configuration"
	@echo "  make envs                           - List available environments"
	@echo ""
	@echo "$(GREEN)Pre-Deployment Commands:$(NC)"
	@echo "  make remove-test                    - [PRE-DEPLOY] Remove all test files before deployment"
	@echo "  make faucet-admin                   - [PRE-DEPLOY] Faucet admin account to necessary accounts"
	@echo ""
	@echo "$(GREEN)Deployment Commands:$(NC)"
	@echo "  make deploy ENV=<env>               - Full deployment (init)"
	@echo "  make deploy-tokens ENV=<env>        - Deploy test tokens only"
	@echo "  make deploy-libs ENV=<env>          - Deploy libraries only"
	@echo "  make deploy-base ENV=<env>          - Deploy base contracts only"
	@echo "  make deploy-realms ENV=<env>        - Deploy gnoswap realms only"
	@echo "  make deploy-v1 ENV=<env>            - Deploy v1 implementations only"
	@echo ""
	@echo "$(GREEN)Testing Commands:$(NC)"
	@echo "  make test-pool ENV=<env>            - Test pool creation and operations"
	@echo "  make test-swap ENV=<env>            - Test swap operations"
	@echo "  make test-stake ENV=<env>           - Test staking operations"
	@echo "  make test-gov ENV=<env>             - Test governance operations"
	@echo "  make test-all ENV=<env>             - Run all tests"
	@echo ""
	@echo "$(YELLOW)Available environments: default, dev, staging, production$(NC)"
	@echo "$(YELLOW)Default environment: default$(NC)"

.PHONY: info
info:
	@echo "$(BLUE)Current Environment Configuration$(NC)"
	@echo "  Environment: $(GREEN)$(ENV)$(NC)"
	@echo "  RPC URL: $(GNOLAND_RPC_URL)"
	@echo "  Chain ID: $(CHAINID)"
	@echo "  Root Dir: $(ROOT_DIR)"
	@echo ""
	@echo "$(BLUE)Contract Addresses$(NC)"
	@echo "  Pool: $(ADDR_POOL)"
	@echo "  Position: $(ADDR_POSITION)"
	@echo "  Router: $(ADDR_ROUTER)"
	@echo "  Staker: $(ADDR_STAKER)"

.PHONY: envs
envs:
	@echo "$(BLUE)Available Environments:$(NC)"
	@ls -1 scripts/config/*.mk | sed 's|scripts/config/|  - |' | sed 's/.mk//'

# Pre-Deployment
# Remove all test files from the project
.PHONY: remove-test
remove-test:
	@echo "$(YELLOW)Removing all *_test.gno and testutils.gno files from project...$(NC)"
	@chmod +x scripts/remove-test.sh
	@bash scripts/remove-test.sh

.PHONY: faucet-admin
faucet-admin:
	@echo "$(GREEN)Faucet admin account to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk send-ugnot-must ENV=$(ENV)

# Deployment targets
.PHONY: deploy
deploy:
	@echo "$(GREEN)Deploying to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk init ENV=$(ENV)

.PHONY: deploy-tokens
deploy-tokens:
	@echo "$(GREEN)Deploying test tokens to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-test-tokens ENV=$(ENV)

.PHONY: deploy-libs
deploy-libs:
	@echo "$(GREEN)Deploying libraries to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-libraries ENV=$(ENV)

.PHONY: deploy-base
deploy-base:
	@echo "$(GREEN)Deploying base contracts to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-base-contracts ENV=$(ENV)

.PHONY: deploy-realms
deploy-realms:
	@echo "$(GREEN)Deploying gnoswap realms to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-gnoswap-realms ENV=$(ENV)

.PHONY: deploy-v1
deploy-v1:
	@echo "$(GREEN)Deploying v1 implementations to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-gnoswap-impl-v1 ENV=$(ENV)

.PHONY: deploy-version
deploy-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make deploy-version CONTRACT=pool VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make deploy-version CONTRACT=pool VERSION=v2)
endif
	@scripts/patch-upgrade.sh contract/r/gnoswap/$(CONTRACT) $(VERSION)
	@echo "$(GREEN)Deploying $(CONTRACT) with version $(VERSION) to $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk deploy-$(CONTRACT)-version VERSION=$(VERSION) ENV=$(ENV)

.PHONY: upgrade-version
upgrade-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make upgrade-version CONTRACT=pool VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make upgrade-version CONTRACT=pool VERSION=v2)
endif
	@echo "$(GREEN)Upgrading $(CONTRACT) to version $(VERSION) on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/deploy.mk upgrade-contract-version CONTRACT=$(CONTRACT) VERSION=$(VERSION) ENV=$(ENV)

# Testing targets
.PHONY: test-pool
test-pool:
	@echo "$(GREEN)Running pool tests on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk pool-create-gns-wugnot-default ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk mint-gns-gnot ENV=$(ENV)

.PHONY: test-swap
test-swap:
	@echo "$(GREEN)Running swap tests on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk swap-exact-in-gns-wugnot ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk swap-exact-out-gns-wugnot ENV=$(ENV)

.PHONY: test-stake
test-stake:
	@echo "$(GREEN)Running staking tests on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk create-external-incentive ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk stake-token-1 ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk collect-staking-reward-1 ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk unstake-token-1 ENV=$(ENV)

.PHONY: test-gov
test-gov:
	@echo "$(GREEN)Running governance tests on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk delegate ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk propose-text ENV=$(ENV)
	@$(MAKE) -f scripts/test.mk propose-community ENV=$(ENV)

.PHONY: test-all
test-all: test-pool test-swap test-stake test-gov
	@echo "$(GREEN)All tests completed on $(ENV) environment!$(NC)"

# Transfer tokens for testing
.PHONY: transfer-tokens
transfer-tokens:
	@echo "$(GREEN)Transferring tokens on $(ENV) environment...$(NC)"
	@$(MAKE) -f scripts/test.mk transfer-base-token ENV=$(ENV)
