# Load environment-specific configuration
ENV ?= default
include scripts/config/$(ENV).mk

## INIT
.PHONY: init
init: deploy-test-tokens deploy-gnoswap

.PHONY: deploy-gnoswap
init: deploy-libraries deploy-base-contracts deploy-gnoswap-realms deploy-gnoswap-impl-v1

.PHONY: deploy-test-tokens
deploy-test-tokens: deploy-bar deploy-baz deploy-foo deploy-obl deploy-qux deploy-usdc

.PHONY: deploy-libraries
deploy-libraries: deploy-uint256 deploy-int256 deploy-rbac deploy-gnsmath deploy-store deploy-version_manager

.PHONY: deploy-base-contracts
deploy-base-contracts: deploy-access deploy-rbac-realm deploy-halt-realm deploy-referral deploy-gns deploy-emission deploy-common deploy-community_pool deploy-gnft deploy-xgns

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-protocol_fee deploy-pool deploy-position deploy-router deploy-staker deploy-gov-staker deploy-governance deploy-launchpad

.PHONY: deploy-gnoswap-impl-v1
deploy-gnoswap-impl-v1: deploy-protocol_fee-v1 deploy-pool-v1 deploy-position-v1 deploy-router-v1 deploy-staker-v1 deploy-gov-staker-v1 deploy-governance-v1 deploy-launchpad-v1

deploy-gnsmath:
	$(info ************ deploy gnsmath ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/gnsmath -pkgpath gno.land/p/gnoswap/gnsmath -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-rbac:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/rbac -pkgpath gno.land/p/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-store:
	$(info ************ deploy store ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/store -pkgpath gno.land/p/gnoswap/store -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-version_manager:
	$(info ************ deploy version_manager ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/version_manager -pkgpath gno.land/p/gnoswap/version_manager -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-rbac-realm:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/rbac -pkgpath gno.land/r/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-access:
	$(info ************ deploy access ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/access -pkgpath gno.land/r/gnoswap/access -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/community_pool -pkgpath gno.land/r/gnoswap/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/emission -pkgpath gno.land/r/gnoswap/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-governance:
	$(info ************ deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance -pkgpath gno.land/r/gnoswap/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker -pkgpath gno.land/r/gnoswap/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/xgns -pkgpath gno.land/r/gnoswap/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad -pkgpath gno.land/r/gnoswap/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool -pkgpath gno.land/r/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position -pkgpath gno.land/r/gnoswap/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee -pkgpath gno.land/r/gnoswap/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-referral:
	$(info ************ deploy referral ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/referral -pkgpath gno.land/r/gnoswap/referral -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-halt-realm:
	$(info ************ deploy r/halt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/halt -pkgpath gno.land/r/gnoswap/halt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router -pkgpath gno.land/r/gnoswap/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker -pkgpath gno.land/r/gnoswap/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-bar:
	$(info ************ deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/bar -pkgpath gno.land/r/gnoswap/test_token/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-baz:
	$(info ************ deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/baz -pkgpath gno.land/r/gnoswap/test_token/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-foo:
	$(info ************ deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/foo -pkgpath gno.land/r/gnoswap/test_token/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-obl:
	$(info ************ deploy obl ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/obl -pkgpath gno.land/r/gnoswap/test_token/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-qux:
	$(info ************ deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/qux -pkgpath gno.land/r/gnoswap/test_token/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/usdc -pkgpath gno.land/r/gnoswap/test_token/usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-governance-v1:
	$(info ************ deploy governance-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance/v1 -pkgpath gno.land/r/gnoswap/gov/governance/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker-v1:
	$(info ************ deploy gov staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker/v1 -pkgpath gno.land/r/gnoswap/gov/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-launchpad-v1:
	$(info ************ deploy launchpad-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad/v1 -pkgpath gno.land/r/gnoswap/launchpad/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-pool-v1:
	$(info ************ deploy pool-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool/v1 -pkgpath gno.land/r/gnoswap/pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-position-v1:
	$(info ************ deploy position-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position/v1 -pkgpath gno.land/r/gnoswap/position/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee-v1:
	$(info ************ deploy protocol_fee-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee/v1 -pkgpath gno.land/r/gnoswap/protocol_fee/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-router-v1:
	$(info ************ deploy router-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router/v1 -pkgpath gno.land/r/gnoswap/router/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-staker-v1:
	$(info ************ deploy staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker/v1 -pkgpath gno.land/r/gnoswap/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
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
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/$(CONTRACT)/$(VERSION) -pkgpath gno.land/r/gnoswap/$(CONTRACT)/$(VERSION) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 10000000ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

upgrade-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
	$(info ************ upgrade implementation of $(CONTRACT)-$(VERSION) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/$(CONTRACT) -func UpgradeImpl -args "gno.land/r/gnoswap/$(CONTRACT)/$(VERSION)" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 10000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo