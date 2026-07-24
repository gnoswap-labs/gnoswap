# Load environment-specific configuration
ENV ?= default
include scripts/config/$(ENV).mk

# All realms under contract/r/gnoswap/test_token/ (each subdir with gnomod.toml)
TEST_TOKEN_NAMES := atom atone btc dai eth photon sol trx usdc usdt

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
deploy-test-tokens: $(addprefix deploy-,$(TEST_TOKEN_NAMES))

.PHONY: deploy-libraries
deploy-libraries: deploy-uint256 deploy-int256 deploy-consts deploy-rbac deploy-gnsmath deploy-store deploy-version_manager deploy-utils deploy-deps-tokens-grc721

.PHONY: deploy-base-contracts
deploy-base-contracts: deploy-access deploy-rbac-realm deploy-halt-realm deploy-referral deploy-gns deploy-emission deploy-common deploy-community_pool deploy-gnft deploy-xgns

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-protocol_fee deploy-pool deploy-position deploy-router deploy-staker deploy-gov-staker deploy-governance deploy-launchpad

.PHONY: deploy-gnoswap-impl-v1
deploy-gnoswap-impl-v1: deploy-protocol_fee-v1 deploy-pool-v1 deploy-position-v1 deploy-router-v1 deploy-staker-v1 deploy-gov-staker-v1 deploy-governance-v1 deploy-launchpad-v1

# ---------------------------------------------------------------------------
# Gas configuration
#
# `gas-wanted` is always derived as `gas-fee * GAS_WANTED_FACTOR`.
# To change the multiplier, edit GAS_WANTED_FACTOR only.
# Per-contract gas-fee values (in ugnot) are defined below.
# ---------------------------------------------------------------------------
GAS_WANTED_FACTOR := 1000

# gas-fee: libraries (p/gnoswap)
GAS_FEE_GNSMATH         := 336860
GAS_FEE_INT256          := 268860
GAS_FEE_CONSTS          := 540000
GAS_FEE_RBAC            := 199200
GAS_FEE_UINT256         := 900000
GAS_FEE_STORE           := 219680
GAS_FEE_VERSION_MANAGER := 251490
GAS_FEE_UTILS           := 300000

# gas-fee: base contracts (r/gnoswap)
GAS_FEE_RBAC_REALM      := 300000
GAS_FEE_ACCESS          := 203450
GAS_FEE_COMMON          := 1140150
GAS_FEE_COMMUNITY_POOL  := 377100
GAS_FEE_EMISSION        := 470660
GAS_FEE_GNFT            := 444660
GAS_FEE_GNS             := 567770
GAS_FEE_GOVERNANCE      := 585000
GAS_FEE_GOV_STAKER      := 595440
GAS_FEE_XGNS            := 323250
GAS_FEE_LAUNCHPAD       := 530820
GAS_FEE_POOL            := 603530
GAS_FEE_POSITION        := 408930
GAS_FEE_PROTOCOL_FEE    := 314820
GAS_FEE_REFERRAL        := 306980
GAS_FEE_HALT            := 340190
GAS_FEE_ROUTER          := 290100
GAS_FEE_STAKER          := 969350

# gas-fee: test tokens
GAS_FEE_ATOM            := 304430
GAS_FEE_ATONE           := 307050
GAS_FEE_BTC             := 305960
GAS_FEE_DAI             := 305250
GAS_FEE_ETH             := 307070
GAS_FEE_PHOTON          := 306000
GAS_FEE_SOL             := 304460
GAS_FEE_TRX             := 305250
GAS_FEE_USDC            := 302730
GAS_FEE_USDT            := 305250

# gas-fee: implementation v1
GAS_FEE_GOVERNANCE_V1   := 1650000
GAS_FEE_GOV_STAKER_V1   := 1245000
GAS_FEE_LAUNCHPAD_V1    := 1080000
GAS_FEE_POOL_V1         := 1350000
GAS_FEE_POSITION_V1     := 1004400
GAS_FEE_PROTOCOL_FEE_V1 := 697910
GAS_FEE_ROUTER_V1       := 1470000
GAS_FEE_STAKER_V1       := 1980000

# gas-fee: generic version deploy/upgrade
GAS_FEE_DEPLOY_VERSION  := 1000000
GAS_FEE_UPGRADE_VERSION := 1000000

# gas-wanted: derived as gas-fee * GAS_WANTED_FACTOR
GAS_WANTED_GNSMATH         := $(shell echo $$(($(GAS_FEE_GNSMATH) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_INT256          := $(shell echo $$(($(GAS_FEE_INT256) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_CONSTS          := $(shell echo $$(($(GAS_FEE_CONSTS) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_RBAC            := $(shell echo $$(($(GAS_FEE_RBAC) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_UINT256         := $(shell echo $$(($(GAS_FEE_UINT256) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_STORE           := $(shell echo $$(($(GAS_FEE_STORE) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_VERSION_MANAGER := $(shell echo $$(($(GAS_FEE_VERSION_MANAGER) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_UTILS           := $(shell echo $$(($(GAS_FEE_UTILS) * $(GAS_WANTED_FACTOR))))

GAS_WANTED_RBAC_REALM      := $(shell echo $$(($(GAS_FEE_RBAC_REALM) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_ACCESS          := $(shell echo $$(($(GAS_FEE_ACCESS) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_COMMON          := $(shell echo $$(($(GAS_FEE_COMMON) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_COMMUNITY_POOL  := $(shell echo $$(($(GAS_FEE_COMMUNITY_POOL) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_EMISSION        := $(shell echo $$(($(GAS_FEE_EMISSION) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_GNFT            := $(shell echo $$(($(GAS_FEE_GNFT) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_GNS             := $(shell echo $$(($(GAS_FEE_GNS) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_GOVERNANCE      := $(shell echo $$(($(GAS_FEE_GOVERNANCE) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_GOV_STAKER      := $(shell echo $$(($(GAS_FEE_GOV_STAKER) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_XGNS            := $(shell echo $$(($(GAS_FEE_XGNS) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_LAUNCHPAD       := $(shell echo $$(($(GAS_FEE_LAUNCHPAD) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_POOL            := $(shell echo $$(($(GAS_FEE_POOL) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_POSITION        := $(shell echo $$(($(GAS_FEE_POSITION) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_PROTOCOL_FEE    := $(shell echo $$(($(GAS_FEE_PROTOCOL_FEE) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_REFERRAL        := $(shell echo $$(($(GAS_FEE_REFERRAL) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_HALT            := $(shell echo $$(($(GAS_FEE_HALT) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_ROUTER          := $(shell echo $$(($(GAS_FEE_ROUTER) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_STAKER          := $(shell echo $$(($(GAS_FEE_STAKER) * $(GAS_WANTED_FACTOR))))

GAS_WANTED_ATOM            := $(shell echo $$(($(GAS_FEE_ATOM) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_ATONE           := $(shell echo $$(($(GAS_FEE_ATONE) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_BTC             := $(shell echo $$(($(GAS_FEE_BTC) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_DAI             := $(shell echo $$(($(GAS_FEE_DAI) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_ETH             := $(shell echo $$(($(GAS_FEE_ETH) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_PHOTON          := $(shell echo $$(($(GAS_FEE_PHOTON) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_SOL             := $(shell echo $$(($(GAS_FEE_SOL) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_TRX             := $(shell echo $$(($(GAS_FEE_TRX) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_USDC            := $(shell echo $$(($(GAS_FEE_USDC) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_USDT            := $(shell echo $$(($(GAS_FEE_USDT) * $(GAS_WANTED_FACTOR))))

GAS_WANTED_GOVERNANCE_V1   := $(shell echo $$(($(GAS_FEE_GOVERNANCE_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_GOV_STAKER_V1   := $(shell echo $$(($(GAS_FEE_GOV_STAKER_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_LAUNCHPAD_V1    := $(shell echo $$(($(GAS_FEE_LAUNCHPAD_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_POOL_V1         := $(shell echo $$(($(GAS_FEE_POOL_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_POSITION_V1     := $(shell echo $$(($(GAS_FEE_POSITION_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_PROTOCOL_FEE_V1 := $(shell echo $$(($(GAS_FEE_PROTOCOL_FEE_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_ROUTER_V1       := $(shell echo $$(($(GAS_FEE_ROUTER_V1) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_STAKER_V1       := $(shell echo $$(($(GAS_FEE_STAKER_V1) * $(GAS_WANTED_FACTOR))))

GAS_WANTED_DEPLOY_VERSION  := $(shell echo $$(($(GAS_FEE_DEPLOY_VERSION) * $(GAS_WANTED_FACTOR))))
GAS_WANTED_UPGRADE_VERSION := $(shell echo $$(($(GAS_FEE_UPGRADE_VERSION) * $(GAS_WANTED_FACTOR))))

deploy-gnsmath:
	$(info ************ deploy gnsmath ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/gnsmath -pkgpath gno.land/p/gnoswap/gnsmath -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GNSMATH)ugnot -gas-wanted $(GAS_WANTED_GNSMATH) -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_INT256)ugnot -gas-wanted $(GAS_WANTED_INT256) -memo "" gnoswap_admin
	@echo

deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/consts -pkgpath gno.land/p/gnoswap/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_CONSTS)ugnot -gas-wanted $(GAS_WANTED_CONSTS) -memo "" gnoswap_admin
	@echo

deploy-rbac:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/rbac -pkgpath gno.land/p/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_RBAC)ugnot -gas-wanted $(GAS_WANTED_RBAC) -memo "" gnoswap_admin
	@echo

deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_UINT256)ugnot -gas-wanted $(GAS_WANTED_UINT256) -memo "" gnoswap_admin
	@echo

deploy-store:
	$(info ************ deploy store ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/store -pkgpath gno.land/p/gnoswap/store -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_STORE)ugnot -gas-wanted $(GAS_WANTED_STORE) -memo "" gnoswap_admin
	@echo

deploy-version_manager:
	$(info ************ deploy version_manager ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/version_manager -pkgpath gno.land/p/gnoswap/version_manager -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_VERSION_MANAGER)ugnot -gas-wanted $(GAS_WANTED_VERSION_MANAGER) -memo "" gnoswap_admin
	@echo

deploy-utils:
	$(info ************ deploy utils ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/utils -pkgpath gno.land/p/gnoswap/utils -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_UTILS)ugnot -gas-wanted $(GAS_WANTED_UTILS) -memo "" gnoswap_admin
	@echo

deploy-rbac-realm:
	$(info ************ deploy rbac ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/rbac -pkgpath gno.land/r/gnoswap/rbac -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_RBAC_REALM)ugnot -gas-wanted $(GAS_WANTED_RBAC_REALM) -memo "" gnoswap_admin
	@echo

deploy-access:
	$(info ************ deploy access ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/access -pkgpath gno.land/r/gnoswap/access -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ACCESS)ugnot -gas-wanted $(GAS_WANTED_ACCESS) -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_COMMON)ugnot -gas-wanted $(GAS_WANTED_COMMON) -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/community_pool -pkgpath gno.land/r/gnoswap/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_COMMUNITY_POOL)ugnot -gas-wanted $(GAS_WANTED_COMMUNITY_POOL) -memo "" gnoswap_admin
	@echo

deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/emission -pkgpath gno.land/r/gnoswap/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_EMISSION)ugnot -gas-wanted $(GAS_WANTED_EMISSION) -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GNFT)ugnot -gas-wanted $(GAS_WANTED_GNFT) -memo "" gnoswap_admin
	@echo

deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GNS)ugnot -gas-wanted $(GAS_WANTED_GNS) -memo "" gnoswap_admin
	@echo

deploy-governance:
	$(info ************ deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance -pkgpath gno.land/r/gnoswap/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GOVERNANCE)ugnot -gas-wanted $(GAS_WANTED_GOVERNANCE) -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker -pkgpath gno.land/r/gnoswap/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GOV_STAKER)ugnot -gas-wanted $(GAS_WANTED_GOV_STAKER) -memo "" gnoswap_admin
	@echo

deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/xgns -pkgpath gno.land/r/gnoswap/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_XGNS)ugnot -gas-wanted $(GAS_WANTED_XGNS) -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad -pkgpath gno.land/r/gnoswap/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_LAUNCHPAD)ugnot -gas-wanted $(GAS_WANTED_LAUNCHPAD) -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool -pkgpath gno.land/r/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_POOL)ugnot -gas-wanted $(GAS_WANTED_POOL) -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position -pkgpath gno.land/r/gnoswap/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_POSITION)ugnot -gas-wanted $(GAS_WANTED_POSITION) -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee -pkgpath gno.land/r/gnoswap/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_PROTOCOL_FEE)ugnot -gas-wanted $(GAS_WANTED_PROTOCOL_FEE) -memo "" gnoswap_admin
	@echo

deploy-referral:
	$(info ************ deploy referral ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/referral -pkgpath gno.land/r/gnoswap/referral -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_REFERRAL)ugnot -gas-wanted $(GAS_WANTED_REFERRAL) -memo "" gnoswap_admin
	@echo

deploy-halt-realm:
	$(info ************ deploy r/halt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/halt -pkgpath gno.land/r/gnoswap/halt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_HALT)ugnot -gas-wanted $(GAS_WANTED_HALT) -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router -pkgpath gno.land/r/gnoswap/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ROUTER)ugnot -gas-wanted $(GAS_WANTED_ROUTER) -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker -pkgpath gno.land/r/gnoswap/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_STAKER)ugnot -gas-wanted $(GAS_WANTED_STAKER) -memo "" gnoswap_admin
	@echo

deploy-atom:
	$(info ************ deploy atom ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atom -pkgpath gno.land/r/gnoswap/test_token/test_atom -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ATOM)ugnot -gas-wanted $(GAS_WANTED_ATOM) -memo "" gnoswap_admin
	@echo

deploy-atone:
	$(info ************ deploy atone ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_atone -pkgpath gno.land/r/gnoswap/test_token/test_atone -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ATONE)ugnot -gas-wanted $(GAS_WANTED_ATONE) -memo "" gnoswap_admin
	@echo

deploy-btc:
	$(info ************ deploy btc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_btc -pkgpath gno.land/r/gnoswap/test_token/test_btc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_BTC)ugnot -gas-wanted $(GAS_WANTED_BTC) -memo "" gnoswap_admin
	@echo

deploy-dai:
	$(info ************ deploy dai ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_dai -pkgpath gno.land/r/gnoswap/test_token/test_dai -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_DAI)ugnot -gas-wanted $(GAS_WANTED_DAI) -memo "" gnoswap_admin
	@echo

deploy-eth:
	$(info ************ deploy eth ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_eth -pkgpath gno.land/r/gnoswap/test_token/test_eth -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ETH)ugnot -gas-wanted $(GAS_WANTED_ETH) -memo "" gnoswap_admin
	@echo

deploy-photon:
	$(info ************ deploy photon ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_photon -pkgpath gno.land/r/gnoswap/test_token/test_photon -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_PHOTON)ugnot -gas-wanted $(GAS_WANTED_PHOTON) -memo "" gnoswap_admin
	@echo

deploy-sol:
	$(info ************ deploy sol ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_sol -pkgpath gno.land/r/gnoswap/test_token/test_sol -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_SOL)ugnot -gas-wanted $(GAS_WANTED_SOL) -memo "" gnoswap_admin
	@echo

deploy-trx:
	$(info ************ deploy trx ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_trx -pkgpath gno.land/r/gnoswap/test_token/test_trx -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_TRX)ugnot -gas-wanted $(GAS_WANTED_TRX) -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdc -pkgpath gno.land/r/gnoswap/test_token/test_usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_USDC)ugnot -gas-wanted $(GAS_WANTED_USDC) -memo "" gnoswap_admin
	@echo

deploy-usdt:
	$(info ************ deploy usdt ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/test_token/test_usdt -pkgpath gno.land/r/gnoswap/test_token/test_usdt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_USDT)ugnot -gas-wanted $(GAS_WANTED_USDT) -memo "" gnoswap_admin
	@echo

deploy-governance-v1:
	$(info ************ deploy governance-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/governance/v1 -pkgpath gno.land/r/gnoswap/gov/governance/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GOVERNANCE_V1)ugnot -gas-wanted $(GAS_WANTED_GOVERNANCE_V1) -memo "" gnoswap_admin
	@echo

deploy-gov-staker-v1:
	$(info ************ deploy gov staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/gov/staker/v1 -pkgpath gno.land/r/gnoswap/gov/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_GOV_STAKER_V1)ugnot -gas-wanted $(GAS_WANTED_GOV_STAKER_V1) -memo "" gnoswap_admin
	@echo

deploy-launchpad-v1:
	$(info ************ deploy launchpad-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/launchpad/v1 -pkgpath gno.land/r/gnoswap/launchpad/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_LAUNCHPAD_V1)ugnot -gas-wanted $(GAS_WANTED_LAUNCHPAD_V1) -memo "" gnoswap_admin
	@echo

deploy-pool-v1:
	$(info ************ deploy pool-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/pool/v1 -pkgpath gno.land/r/gnoswap/pool/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_POOL_V1)ugnot -gas-wanted $(GAS_WANTED_POOL_V1) -memo "" gnoswap_admin
	@echo

deploy-position-v1:
	$(info ************ deploy position-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/position/v1 -pkgpath gno.land/r/gnoswap/position/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_POSITION_V1)ugnot -gas-wanted $(GAS_WANTED_POSITION_V1) -memo "" gnoswap_admin
	@echo

deploy-protocol_fee-v1:
	$(info ************ deploy protocol_fee-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/protocol_fee/v1 -pkgpath gno.land/r/gnoswap/protocol_fee/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_PROTOCOL_FEE_V1)ugnot -gas-wanted $(GAS_WANTED_PROTOCOL_FEE_V1) -memo "" gnoswap_admin
	@echo

deploy-router-v1:
	$(info ************ deploy router-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/router/v1 -pkgpath gno.land/r/gnoswap/router/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_ROUTER_V1)ugnot -gas-wanted $(GAS_WANTED_ROUTER_V1) -memo "" gnoswap_admin
	@echo

deploy-staker-v1:
	$(info ************ deploy staker-v1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/staker/v1 -pkgpath gno.land/r/gnoswap/staker/v1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_STAKER_V1)ugnot -gas-wanted $(GAS_WANTED_STAKER_V1) -memo "" gnoswap_admin
	@echo

deploy-deps-tokens-grc721:
	$(info ************ deploy deps-token-grc721 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/p/gnoswap/deps/tokens/grc721 -pkgpath gno.land/p/gnoswap/deps/grc721 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 104914ugnot -gas-wanted 104914000 -memo "" gnoswap_admin
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
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/contract/r/gnoswap/$(CONTRACT)/$(VERSION) -pkgpath gno.land/r/gnoswap/$(CONTRACT)/$(VERSION) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_DEPLOY_VERSION)ugnot -gas-wanted $(GAS_WANTED_DEPLOY_VERSION) -memo "" gnoswap_admin
	@echo

upgrade-contract-version:
ifndef CONTRACT
	$(error CONTRACT is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
ifndef VERSION
	$(error VERSION is not set. Usage: make upgrade-version CONTRACT=staker VERSION=v2)
endif
	$(info ************ upgrade implementation of $(CONTRACT)-$(VERSION) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/$(CONTRACT) -func UpgradeImpl -args "gno.land/r/gnoswap/$(CONTRACT)/$(VERSION)" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee $(GAS_FEE_UPGRADE_VERSION)ugnot -gas-wanted $(GAS_WANTED_UPGRADE_VERSION) -memo "" gnoswap_admin
	@echo
