# Load environment-specific configuration
ENV ?= default
include scripts/config/$(ENV).mk

# Patch admin address
.PHONY: patch-admin-address
patch-admin-address:
	$(info ************ patching admin address ************)
	@bash scripts/patch-admin-address.sh $(ADDR_ADMIN)
	@echo

## INIT
.PHONY: init
init: deploy-test-tokens deploy-gnoswap

.PHONY: deploy-gnoswap
init: deploy-libraries deploy-base-contracts deploy-gnoswap-realms deploy-gnoswap-impl-v1

# All realms under contract/r/gnoswap/test_token/ (each subdir with gnomod.toml)
TEST_TOKEN_NAMES := atom atone btc dai eth photon sol trx usdc usdt

.PHONY: deploy-test-tokens
deploy-test-tokens: $(addprefix deploy-,$(TEST_TOKEN_NAMES))

.PHONY: deploy-libraries
deploy-libraries: deploy-uint256 deploy-int256 deploy-rbac deploy-gnsmath deploy-store deploy-version_manager deploy-deps-tokens-grc721

.PHONY: deploy-base-contracts
deploy-base-contracts: deploy-access deploy-rbac-realm deploy-halt-realm deploy-referral deploy-gns deploy-emission deploy-common deploy-community_pool deploy-gnft deploy-xgns

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-protocol_fee deploy-pool deploy-position deploy-router deploy-staker deploy-gov-staker deploy-governance deploy-launchpad

.PHONY: deploy-gnoswap-impl-v1
deploy-gnoswap-impl-v1: deploy-protocol_fee-v1 deploy-pool-v1 deploy-position-v1 deploy-router-v1 deploy-staker-v1 deploy-gov-staker-v1 deploy-governance-v1 deploy-launchpad-v1

deploy-deps-tokens-grc721:
	$(info ************ deploy deps-token-grc721 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/deps/tokens/grc721 -pkgpath gno.land/p/gnoswap/deps/grc721 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 54914ugnot -gas-wanted 54914000 -memo "" gnoswap_admin
	@echo

deploy-gnsmath:
	$(info ************ deploy gnsmath ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/gnsmath -pkgpath gno.land/p/gnoswap/gnsmath -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 33686ugnot -gas-wanted 33686000 -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 26886ugnot -gas-wanted 26886000 -memo "" gnoswap_admin
	@echo

deploy-rbac:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/rbac -pkgpath gno.land/p/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 19920ugnot -gas-wanted 19920000 -memo "" gnoswap_admin
	@echo

deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 39498ugnot -gas-wanted 39498000 -memo "" gnoswap_admin
	@echo

deploy-store:
	$(info ************ deploy store ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/store -pkgpath gno.land/p/gnoswap/store -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 21968ugnot -gas-wanted 21968000 -memo "" gnoswap_admin
	@echo

deploy-version_manager:
	$(info ************ deploy version_manager ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/version_manager -pkgpath gno.land/p/gnoswap/version_manager -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 25149ugnot -gas-wanted 25149000 -memo "" gnoswap_admin
	@echo

deploy-rbac-realm:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/rbac -pkgpath gno.land/r/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 30000ugnot -gas-wanted 30000000 -memo "" gnoswap_admin
	@echo

deploy-access:
	$(info ************ deploy access ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/access -pkgpath gno.land/r/gnoswap/access -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 20345ugnot -gas-wanted 20345000 -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 114015ugnot -gas-wanted 114015000 -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/community_pool -pkgpath gno.land/r/gnoswap/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 37710ugnot -gas-wanted 37710000 -memo "" gnoswap_admin
	@echo

deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/emission -pkgpath gno.land/r/gnoswap/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 47066ugnot -gas-wanted 47066000 -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 44466ugnot -gas-wanted 44466000 -memo "" gnoswap_admin
	@echo

deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 56777ugnot -gas-wanted 56777000 -memo "" gnoswap_admin
	@echo

deploy-governance:
	$(info ************ deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance -pkgpath gno.land/r/gnoswap/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 58500ugnot -gas-wanted 58500000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker -pkgpath gno.land/r/gnoswap/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 59544ugnot -gas-wanted 59544000 -memo "" gnoswap_admin
	@echo

deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/xgns -pkgpath gno.land/r/gnoswap/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 32325ugnot -gas-wanted 32325000 -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad -pkgpath gno.land/r/gnoswap/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 53082ugnot -gas-wanted 53082000 -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool -pkgpath gno.land/r/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 60353ugnot -gas-wanted 60353000 -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position -pkgpath gno.land/r/gnoswap/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40893ugnot -gas-wanted 40893000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee -pkgpath gno.land/r/gnoswap/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 31482ugnot -gas-wanted 31482000 -memo "" gnoswap_admin
	@echo

deploy-referral:
	$(info ************ deploy referral ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/referral -pkgpath gno.land/r/gnoswap/referral -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 30698ugnot -gas-wanted 30698000 -memo "" gnoswap_admin
	@echo

deploy-halt-realm:
	$(info ************ deploy r/halt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/halt -pkgpath gno.land/r/gnoswap/halt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 34019ugnot -gas-wanted 34019000 -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router -pkgpath gno.land/r/gnoswap/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 29010ugnot -gas-wanted 29010000 -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker -pkgpath gno.land/r/gnoswap/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 96935ugnot -gas-wanted 96935000 -memo "" gnoswap_admin
	@echo

deploy-governance-v1:
	$(info ************ deploy governance-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance/v1 -pkgpath gno.land/r/gnoswap/gov/governance/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 165000ugnot -gas-wanted 165000000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker-v1:
	$(info ************ deploy gov staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker/v1 -pkgpath gno.land/r/gnoswap/gov/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 124500ugnot -gas-wanted 124500000 -memo "" gnoswap_admin
	@echo

deploy-launchpad-v1:
	$(info ************ deploy launchpad-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad/v1 -pkgpath gno.land/r/gnoswap/launchpad/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 108000ugnot -gas-wanted 108000000 -memo "" gnoswap_admin
	@echo

deploy-pool-v1:
	$(info ************ deploy pool-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool/v1 -pkgpath gno.land/r/gnoswap/pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 135000ugnot -gas-wanted 135000000 -memo "" gnoswap_admin
	@echo

deploy-position-v1:
	$(info ************ deploy position-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position/v1 -pkgpath gno.land/r/gnoswap/position/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100440ugnot -gas-wanted 100440000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee-v1:
	$(info ************ deploy protocol_fee-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee/v1 -pkgpath gno.land/r/gnoswap/protocol_fee/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 69791ugnot -gas-wanted 69791000 -memo "" gnoswap_admin
	@echo

deploy-router-v1:
	$(info ************ deploy router-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router/v1 -pkgpath gno.land/r/gnoswap/router/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 147000ugnot -gas-wanted 147000000 -memo "" gnoswap_admin
	@echo

deploy-staker-v1:
	$(info ************ deploy staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker/v1 -pkgpath gno.land/r/gnoswap/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 198000ugnot -gas-wanted 198000000 -memo "" gnoswap_admin
	@echo

deploy-atom:
	$(info ************ deploy atom ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atom -pkgpath gno.land/r/gnoswap/test_token/test_atom -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45443ugnot -gas-wanted 45443000 -memo "" gnoswap_admin
	@echo

deploy-atone:
	$(info ************ deploy atone ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atone -pkgpath gno.land/r/gnoswap/test_token/test_atone -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45705ugnot -gas-wanted 45705000 -memo "" gnoswap_admin
	@echo

deploy-btc:
	$(info ************ deploy btc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_btc -pkgpath gno.land/r/gnoswap/test_token/test_btc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45596ugnot -gas-wanted 45596000 -memo "" gnoswap_admin
	@echo

deploy-dai:
	$(info ************ deploy dai ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_dai -pkgpath gno.land/r/gnoswap/test_token/test_dai -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45525ugnot -gas-wanted 45525000 -memo "" gnoswap_admin
	@echo

deploy-eth:
	$(info ************ deploy eth ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_eth -pkgpath gno.land/r/gnoswap/test_token/test_eth -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45707ugnot -gas-wanted 45707000 -memo "" gnoswap_admin
	@echo

deploy-photon:
	$(info ************ deploy photon ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_photon -pkgpath gno.land/r/gnoswap/test_token/test_photon -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45600ugnot -gas-wanted 45600000 -memo "" gnoswap_admin
	@echo

deploy-sol:
	$(info ************ deploy sol ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_sol -pkgpath gno.land/r/gnoswap/test_token/test_sol -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45446ugnot -gas-wanted 45446000 -memo "" gnoswap_admin
	@echo

deploy-trx:
	$(info ************ deploy trx ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_trx -pkgpath gno.land/r/gnoswap/test_token/test_trx -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45525ugnot -gas-wanted 45525000 -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdc -pkgpath gno.land/r/gnoswap/test_token/test_usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45273ugnot -gas-wanted 45273000 -memo "" gnoswap_admin
	@echo

deploy-usdt:
	$(info ************ deploy usdt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdt -pkgpath gno.land/r/gnoswap/test_token/test_usdt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45525ugnot -gas-wanted 45525000 -memo "" gnoswap_admin
	@echo

# Deploy contracts with specific version
# Usage: make deploy-contract-version CONTRACT=staker VERSION=v2
deploy-contract-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make deploy-contract-version CONTRACT=staker VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make deploy-contract-version CONTRACT=staker VERSION=v2)
endif
	$(info ************ deploy $(CONTRACT)-$(VERSION) ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/$(CONTRACT)/$(VERSION) -pkgpath gno.land/r/gnoswap/$(CONTRACT)/$(VERSION) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

upgrade-contract-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
	$(info ************ upgrade implementation of $(CONTRACT)-$(VERSION) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/$(CONTRACT) -func UpgradeImpl -args "gno.land/r/gnoswap/$(CONTRACT)/$(VERSION)" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo
