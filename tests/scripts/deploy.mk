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
deploy-libraries: deploy-uint256 deploy-int256 deploy-consts deploy-rbac deploy-gnsmath deploy-store deploy-version_manager deploy-utils

.PHONY: deploy-base-contracts
deploy-base-contracts: deploy-access deploy-rbac-realm deploy-halt-realm deploy-referral deploy-gns deploy-emission deploy-common deploy-community_pool deploy-gnft deploy-xgns

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-protocol_fee deploy-pool deploy-position deploy-router deploy-staker deploy-gov-staker deploy-governance deploy-launchpad

.PHONY: deploy-gnoswap-impl-v1
deploy-gnoswap-impl-v1: deploy-common-v1 deploy-protocol_fee-v1 deploy-pool-v1 deploy-position-v1 deploy-router-v1 deploy-staker-v1 deploy-gov-staker-v1 deploy-governance-v1 deploy-launchpad-v1

deploy-gnsmath:
	$(info ************ deploy gnsmath ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/gnsmath/v1 -pkgpath gno.land/p/gnoswap/gnsmath/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 92306ugnot -gas-wanted 92305161 -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/int256/v1 -pkgpath gno.land/p/gnoswap/int256/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 56532ugnot -gas-wanted 56531389 -memo "" gnoswap_admin
	@echo

deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/consts/v1 -pkgpath gno.land/p/gnoswap/consts/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 13623ugnot -gas-wanted 13622167 -memo "" gnoswap_admin
	@echo

deploy-rbac:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/rbac/v1 -pkgpath gno.land/p/gnoswap/rbac/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 37607ugnot -gas-wanted 37606347 -memo "" gnoswap_admin
	@echo

deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/uint256/v1 -pkgpath gno.land/p/gnoswap/uint256/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 116857ugnot -gas-wanted 116856050 -memo "" gnoswap_admin
	@echo

deploy-store:
	$(info ************ deploy store ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/store/v1 -pkgpath gno.land/p/gnoswap/store/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 50500ugnot -gas-wanted 50499354 -memo "" gnoswap_admin
	@echo

deploy-version_manager:
	$(info ************ deploy version_manager ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/version_manager/v1 -pkgpath gno.land/p/gnoswap/version_manager/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45218ugnot -gas-wanted 45217094 -memo "" gnoswap_admin
	@echo

deploy-utils:
	$(info ************ deploy utils ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/utils/v1 -pkgpath gno.land/p/gnoswap/utils/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 18451ugnot -gas-wanted 18450399 -memo "" gnoswap_admin
	@echo

deploy-rbac-realm:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/rbac/v1 -pkgpath gno.land/r/gnoswap/rbac/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 36275ugnot -gas-wanted 36274747 -memo "" gnoswap_admin
	@echo

deploy-access:
	$(info ************ deploy access ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/access/v1 -pkgpath gno.land/r/gnoswap/access/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 22107ugnot -gas-wanted 22106681 -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 38360ugnot -gas-wanted 38359621 -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/community_pool/v1 -pkgpath gno.land/r/gnoswap/community_pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 24734ugnot -gas-wanted 24733402 -memo "" gnoswap_admin
	@echo

deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/emission -pkgpath gno.land/r/gnoswap/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 82360ugnot -gas-wanted 82359412 -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 55102ugnot -gas-wanted 55101030 -memo "" gnoswap_admin
	@echo

deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 90988ugnot -gas-wanted 90987212 -memo "" gnoswap_admin
	@echo

deploy-governance:
	$(info ************ deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance -pkgpath gno.land/r/gnoswap/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 217857ugnot -gas-wanted 217856634 -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker -pkgpath gno.land/r/gnoswap/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 222151ugnot -gas-wanted 222150262 -memo "" gnoswap_admin
	@echo

deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/xgns -pkgpath gno.land/r/gnoswap/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 25847ugnot -gas-wanted 25846662 -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad -pkgpath gno.land/r/gnoswap/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 210250ugnot -gas-wanted 210249618 -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool -pkgpath gno.land/r/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 253330ugnot -gas-wanted 253329853 -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position -pkgpath gno.land/r/gnoswap/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 101541ugnot -gas-wanted 101540111 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee -pkgpath gno.land/r/gnoswap/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 131708ugnot -gas-wanted 131707217 -memo "" gnoswap_admin
	@echo

deploy-referral:
	$(info ************ deploy referral ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/referral/v1 -pkgpath gno.land/r/gnoswap/referral/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 41452ugnot -gas-wanted 41451542 -memo "" gnoswap_admin
	@echo

deploy-halt-realm:
	$(info ************ deploy r/halt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/halt/v1 -pkgpath gno.land/r/gnoswap/halt/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45320ugnot -gas-wanted 45319525 -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router -pkgpath gno.land/r/gnoswap/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 53144ugnot -gas-wanted 53143308 -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker -pkgpath gno.land/r/gnoswap/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 432193ugnot -gas-wanted 432192575 -memo "" gnoswap_admin
	@echo

deploy-atom:
	$(info ************ deploy atom ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atom -pkgpath gno.land/r/gnoswap/test_token/test_atom -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 21548ugnot -gas-wanted 21547787 -memo "" gnoswap_admin
	@echo

deploy-atone:
	$(info ************ deploy atone ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atone -pkgpath gno.land/r/gnoswap/test_token/test_atone -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 22160ugnot -gas-wanted 22159066 -memo "" gnoswap_admin
	@echo

deploy-btc:
	$(info ************ deploy btc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_btc -pkgpath gno.land/r/gnoswap/test_token/test_btc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 22771ugnot -gas-wanted 22770291 -memo "" gnoswap_admin
	@echo

deploy-dai:
	$(info ************ deploy dai ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_dai -pkgpath gno.land/r/gnoswap/test_token/test_dai -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 22701ugnot -gas-wanted 22700284 -memo "" gnoswap_admin
	@echo

deploy-eth:
	$(info ************ deploy eth ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_eth -pkgpath gno.land/r/gnoswap/test_token/test_eth -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 23418ugnot -gas-wanted 23417266 -memo "" gnoswap_admin
	@echo

deploy-photon:
	$(info ************ deploy photon ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_photon -pkgpath gno.land/r/gnoswap/test_token/test_photon -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 23387ugnot -gas-wanted 23386688 -memo "" gnoswap_admin
	@echo

deploy-sol:
	$(info ************ deploy sol ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_sol -pkgpath gno.land/r/gnoswap/test_token/test_sol -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 23357ugnot -gas-wanted 23356456 -memo "" gnoswap_admin
	@echo

deploy-trx:
	$(info ************ deploy trx ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_trx -pkgpath gno.land/r/gnoswap/test_token/test_trx -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 23294ugnot -gas-wanted 23293692 -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdc -pkgpath gno.land/r/gnoswap/test_token/test_usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 24024ugnot -gas-wanted 24023377 -memo "" gnoswap_admin
	@echo

deploy-usdt:
	$(info ************ deploy usdt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdt -pkgpath gno.land/r/gnoswap/test_token/test_usdt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 23956ugnot -gas-wanted 23955665 -memo "" gnoswap_admin
	@echo

deploy-common-v1:
	$(info ************ deploy common-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common/v1 -pkgpath gno.land/r/gnoswap/common/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 38271ugnot -gas-wanted 38270593 -memo "" gnoswap_admin
	@echo

deploy-governance-v1:
	$(info ************ deploy governance-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance/v1 -pkgpath gno.land/r/gnoswap/gov/governance/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 317772ugnot -gas-wanted 317771755 -memo "" gnoswap_admin
	@echo

deploy-gov-staker-v1:
	$(info ************ deploy gov staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker/v1 -pkgpath gno.land/r/gnoswap/gov/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 287739ugnot -gas-wanted 287738675 -memo "" gnoswap_admin
	@echo

deploy-launchpad-v1:
	$(info ************ deploy launchpad-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad/v1 -pkgpath gno.land/r/gnoswap/launchpad/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 207301ugnot -gas-wanted 207300215 -memo "" gnoswap_admin
	@echo

deploy-pool-v1:
	$(info ************ deploy pool-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool/v1 -pkgpath gno.land/r/gnoswap/pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 346974ugnot -gas-wanted 346973503 -memo "" gnoswap_admin
	@echo

deploy-position-v1:
	$(info ************ deploy position-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position/v1 -pkgpath gno.land/r/gnoswap/position/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 191766ugnot -gas-wanted 191765953 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee-v1:
	$(info ************ deploy protocol_fee-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee/v1 -pkgpath gno.land/r/gnoswap/protocol_fee/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 88269ugnot -gas-wanted 88268528 -memo "" gnoswap_admin
	@echo

deploy-router-v1:
	$(info ************ deploy router-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router/v1 -pkgpath gno.land/r/gnoswap/router/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 199676ugnot -gas-wanted 199675655 -memo "" gnoswap_admin
	@echo

deploy-staker-v1:
	$(info ************ deploy staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker/v1 -pkgpath gno.land/r/gnoswap/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 503844ugnot -gas-wanted 503843594 -memo "" gnoswap_admin
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
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/$(CONTRACT)/$(VERSION) -pkgpath gno.land/r/gnoswap/$(CONTRACT)/$(VERSION) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
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
