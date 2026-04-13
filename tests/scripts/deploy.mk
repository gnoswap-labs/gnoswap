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

deploy-deps-tokens-grc721:
	$(info ************ deploy deps-token-grc721 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/deps/tokens/grc721 -pkgpath gno.land/p/gnoswap/deps/grc721 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 54914ugnot -gas-wanted 54914000 -memo "" gnoswap_admin
	@echo

deploy-gnsmath:
	$(info ************ deploy gnsmath ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/gnsmath -pkgpath gno.land/p/gnoswap/gnsmath -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 44914ugnot -gas-wanted 44914000 -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 35848ugnot -gas-wanted 35848000 -memo "" gnoswap_admin
	@echo

deploy-rbac:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/rbac -pkgpath gno.land/p/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 26560ugnot -gas-wanted 26560000 -memo "" gnoswap_admin
	@echo

deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 52664ugnot -gas-wanted 52664000 -memo "" gnoswap_admin
	@echo

deploy-store:
	$(info ************ deploy store ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/store -pkgpath gno.land/p/gnoswap/store -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 29290ugnot -gas-wanted 29290000 -memo "" gnoswap_admin
	@echo

deploy-version_manager:
	$(info ************ deploy version_manager ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/version_manager -pkgpath gno.land/p/gnoswap/version_manager -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 33532ugnot -gas-wanted 33532000 -memo "" gnoswap_admin
	@echo

deploy-rbac-realm:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/rbac -pkgpath gno.land/r/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 31962ugnot -gas-wanted 31962000 -memo "" gnoswap_admin
	@echo

deploy-access:
	$(info ************ deploy access ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/access -pkgpath gno.land/r/gnoswap/access -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 27126ugnot -gas-wanted 27126000 -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 152020ugnot -gas-wanted 152020000 -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/community_pool -pkgpath gno.land/r/gnoswap/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 50280ugnot -gas-wanted 50280000 -memo "" gnoswap_admin
	@echo

deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/emission -pkgpath gno.land/r/gnoswap/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 62754ugnot -gas-wanted 62754000 -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 59288ugnot -gas-wanted 59288000 -memo "" gnoswap_admin
	@echo

deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 75702ugnot -gas-wanted 75702000 -memo "" gnoswap_admin
	@echo

deploy-governance:
	$(info ************ deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance -pkgpath gno.land/r/gnoswap/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 65504ugnot -gas-wanted 65504000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker -pkgpath gno.land/r/gnoswap/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 79392ugnot -gas-wanted 79392000 -memo "" gnoswap_admin
	@echo

deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/xgns -pkgpath gno.land/r/gnoswap/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 43100ugnot -gas-wanted 43100000 -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad -pkgpath gno.land/r/gnoswap/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 70776ugnot -gas-wanted 70776000 -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool -pkgpath gno.land/r/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 80470ugnot -gas-wanted 80470000 -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position -pkgpath gno.land/r/gnoswap/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 54524ugnot -gas-wanted 54524000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee -pkgpath gno.land/r/gnoswap/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 41976ugnot -gas-wanted 41976000 -memo "" gnoswap_admin
	@echo

deploy-referral:
	$(info ************ deploy referral ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/referral -pkgpath gno.land/r/gnoswap/referral -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40930ugnot -gas-wanted 40930000 -memo "" gnoswap_admin
	@echo

deploy-halt-realm:
	$(info ************ deploy r/halt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/halt -pkgpath gno.land/r/gnoswap/halt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 45358ugnot -gas-wanted 45358000 -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router -pkgpath gno.land/r/gnoswap/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 34680ugnot -gas-wanted 34680000 -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker -pkgpath gno.land/r/gnoswap/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 129246ugnot -gas-wanted 129246000 -memo "" gnoswap_admin
	@echo

deploy-bar:
	$(info ************ deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/bar -pkgpath gno.land/r/gnoswap/test_token/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40590ugnot -gas-wanted 40590000 -memo "" gnoswap_admin
	@echo

deploy-baz:
	$(info ************ deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/baz -pkgpath gno.land/r/gnoswap/test_token/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40940ugnot -gas-wanted 40940000 -memo "" gnoswap_admin
	@echo

deploy-foo:
	$(info ************ deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/foo -pkgpath gno.land/r/gnoswap/test_token/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40794ugnot -gas-wanted 40794000 -memo "" gnoswap_admin
	@echo

deploy-obl:
	$(info ************ deploy obl ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/obl -pkgpath gno.land/r/gnoswap/test_token/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40942ugnot -gas-wanted 40942000 -memo "" gnoswap_admin
	@echo

deploy-qux:
	$(info ************ deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/qux -pkgpath gno.land/r/gnoswap/test_token/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40594ugnot -gas-wanted 40594000 -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/usdc -insecure-password-stdin=true -pkgpath gno.land/r/gnoswap/test_token/usdc -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 40364ugnot -gas-wanted 40364000 -memo "" gnoswap_admin
	@echo

deploy-governance-v1:
	$(info ************ deploy governance-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance/v1 -pkgpath gno.land/r/gnoswap/gov/governance/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 178614ugnot -gas-wanted 178614000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker-v1:
	$(info ************ deploy gov staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker/v1 -pkgpath gno.land/r/gnoswap/gov/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 142880ugnot -gas-wanted 142880000 -memo "" gnoswap_admin
	@echo

deploy-launchpad-v1:
	$(info ************ deploy launchpad-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad/v1 -pkgpath gno.land/r/gnoswap/launchpad/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 125068ugnot -gas-wanted 125068000 -memo "" gnoswap_admin
	@echo

deploy-pool-v1:
	$(info ************ deploy pool-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool/v1 -pkgpath gno.land/r/gnoswap/pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 151554ugnot -gas-wanted 151554000 -memo "" gnoswap_admin
	@echo

deploy-position-v1:
	$(info ************ deploy position-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position/v1 -pkgpath gno.land/r/gnoswap/position/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 133920ugnot -gas-wanted 133920000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee-v1:
	$(info ************ deploy protocol_fee-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee/v1 -pkgpath gno.land/r/gnoswap/protocol_fee/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 93054ugnot -gas-wanted 93054000 -memo "" gnoswap_admin
	@echo

deploy-router-v1:
	$(info ************ deploy router-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router/v1 -pkgpath gno.land/r/gnoswap/router/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 122194ugnot -gas-wanted 122194000 -memo "" gnoswap_admin
	@echo

deploy-staker-v1:
	$(info ************ deploy staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker/v1 -pkgpath gno.land/r/gnoswap/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 213030ugnot -gas-wanted 213030000 -memo "" gnoswap_admin
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
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/$(CONTRACT)/$(VERSION) -pkgpath gno.land/r/gnoswap/$(CONTRACT)/$(VERSION) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 2000000ugnot -gas-wanted 200000000 -memo "" gnoswap_admin
	@echo

upgrade-contract-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
	$(info ************ upgrade implementation of $(CONTRACT)-$(VERSION) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/$(CONTRACT) -func UpgradeImpl -args "gno.land/r/gnoswap/$(CONTRACT)/$(VERSION)" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 2000000ugnot -gas-wanted 200000000 -memo "" gnoswap_admin
	@echo