# make -f __local/test/emission_test.mk init init-test

ADDR_GSA := g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
ADDR_REGISTER := g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5

ADDR_GOV := g1cu4dufdlzu0l9pekkqhw6mjnrxkp3z7ykst09d
ADDR_POOL := g148tjamj80yyrm309z7rk690an22thd2l3z8ank
ADDR_POSITION := g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5
ADDR_ROUTER := g1lm2l7tf49h3mykesct7rhfml30yx8dw5xrval7
ADDR_STAKER := g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
ADDR_PROTOCOL_FEE := g1f7wpek7q67tkns27sw495u5yuu3a5wwjxw5l6l

ADDR_GNS := g1jgqwaa2le3yr63d533fj785qkjspumzv22ys5m
ADDR_GNFT := g1wxv2rdfn53qc84nt3nn646f9yh3nly8lm7j89t

ADDR_WUGNOT := g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6


MAX_UINT64 := 18446744073709551615
TX_EXPIRE := 9999999999

MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))

GNOLAND_RPC_URL ?= http://localhost:26657
CHAINID ?= dev

# GNOLAND_RPC_URL ?= https://dev.rpc.gnoswap.io:443
# CHAINID ?= dev.gnoswap

ROOT_DIR:=$(shell dirname $(MAKEFILE))/../../


## INIT
.PHONY: init
init: wait send-ugnot-must deploy-libraries deploy-base-tokens deploy-gnoswap-realms deploy-test-tokens register-token pool-create-gns-wugnot-default

.PHONY: deploy-libraries
deploy-libraries: deploy-uint256 deploy-int256  deploy-consts deploy-package-pool deploy-common 

.PHONY: deploy-base-tokens
deploy-base-tokens: deploy-gns deploy-usdc deploy-gnft

.PHONY: deploy-test-tokens
deploy-test-tokens: deploy-foo deploy-bar deploy-baz deploy-qux deploy-obl 

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-xgns deploy-emission deploy-pool deploy-position deploy-staker deploy-router deploy-community_pool deploy-protocol_fee deploy-gov-staker deploy-gov-governance 

### TEST AFTER INIT
.PHONY: init-test
init-test: test-pool-create test-position-mint test-stake-token 

.PHONY: test-pool-create
test-pool-create: pool-create-bar-baz pool-create-foo-qux

.PHONY: test-position-mint
test-position-mint: mint-gns-gnot 

.PHONY: test-stake-token
test-stake-token: stake-token-1 

.PHONY: test-collect-reward
test-collect-reward: collect-reward-1

.PHONY: test-unstake-token
test-unstake-token: unstake-token-1

.PHONY: test-burn-position
test-burn-position: burn-position-1



# wait chain to start
wait:
	$(info ************ [ETC] wait 1 seconds for chain to start ************)
	$(shell sleep 1)
	@echo


# send ugnot to necessary accounts
send-ugnot-must:
	$(info ************ send ugnot to necessary accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_PROTOCOL_FEE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_REGISTER) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo


# deploy test grc20 tokens
deploy-foo:
	$(info ************ deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/foo -pkgpath gno.land/r/onbloc/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-bar:
	$(info ************ deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/bar -pkgpath gno.land/r/onbloc/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-baz:
	$(info ************ deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/baz -pkgpath gno.land/r/onbloc/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-qux:
	$(info ************ deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/qux -pkgpath gno.land/r/onbloc/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-obl:
	$(info ************ deploy obl ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/obl -pkgpath gno.land/r/onbloc/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy base tokens
deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/v1/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/v1/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/usdc -pkgpath gno.land/r/onbloc/usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy packages
deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-package-pool:
	$(info ************ deploy package pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/pool -pkgpath gno.land/p/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy common realms
deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/consts -pkgpath gno.land/r/gnoswap/v1/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/common -pkgpath gno.land/r/gnoswap/v1/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy gnoswap realms
deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/xgns -pkgpath gno.land/r/gnoswap/v1/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo
	
deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/emission -pkgpath gno.land/r/gnoswap/v1/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/gnoswap/v1/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/gnoswap/v1/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/gnoswap/v1/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/gnoswap/v1/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/community_pool -pkgpath gno.land/r/gnoswap/v1/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/protocol_fee -pkgpath gno.land/r/gnoswap/v1/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-gov-staker:
	$(info ************ deploy gov/staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/staker -pkgpath gno.land/r/gnoswap/v1/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-gov-governance:
	$(info ************ deploy gov/governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/governance -pkgpath gno.land/r/gnoswap/v1/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

# Register
register-token:
	$(info ************ deploy register_gnodev ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5/register_gnodev -pkgpath gno.land/r/g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5/v2/register_gnodev -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" register > /dev/null
	@echo

# default pool create
pool-create-gns-wugnot-default:
	$(info ************ set pool creation fee to 0uGNS for testing ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func SetPoolCreationFee -args 0 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo 


	$(info ************ create default pool (GNS:WUGNOT:0.03%) ************)
	# tick 0 ≈ x1 ≈ 79228162514264337593543950337
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/demo/wugnot" -args "gno.land/r/gnoswap/v1/gns" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

# test pool create
pool-create-bar-baz:
	$(info ************ create pool bar:baz ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-foo-qux:
	$(info ************ create pool foo:qux ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/foo" -args "gno.land/r/onbloc/qux" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-gns-gnot:
	$(info ************ mint position(1) to gns:wugnot // gnoswap_admin ************)
	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# APPROVE WUGNOT TO POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -send "20000000ugnot" -args "gno.land/r/gnoswap/v1/gns" -args "gnot" -args 3000 -args "-49980" -args "49980" -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# Set-Token-Uri
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-1:
	$(info ************ stake token 1 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func Approve -args $(ADDR_STAKER) -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

## test collect reward
collect-reward-1:
	$(info ************ collect reward 1 // gnoswap_admin (internal) ************)
	# approve reward token(gns) to STAKER
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func CollectReward -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

## test unstake token
unstake-token-1:
	$(info ************ unstake token 1 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func UnstakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

## test position burn
burn-position-1:
	$(info ************ decrease entire liquidity(==burn) from position 1 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func DecreaseLiquidity -args 1 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


set-pool-tier-1-bar-baz:
	$(info ************ set pool tier 2 bar:baz // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func SetPoolTier -args "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100" -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-2:
	$(info ************ stake token 2 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func Approve -args $(ADDR_STAKER) -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func StakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

set-pool-tier-3-foo-qux:
	$(info ************ set pool tier 3 foo:qux // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func SetPoolTier -args "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:100" -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-3:
	$(info ************ stake token 3 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func Approve -args $(ADDR_STAKER) -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func StakeToken -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# CREATE EXTERNAL INCENTIVE DEPOSIT
external-deposit-approve:
	$(info ************ approve gns to staker // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null




## TRANSFER FOR QA
ADDR_ROH := g16a7etgm9z2r653ucl36rj0l2yqcxgrz2jyegzx
transfer-roh:
	$(info ************ TO roh account // transfer COIN(ugnot), GRC20(bar, baz, foo, obl, qux, usdc) ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_ROH) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo ""

ADDR_TEST1 := g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
transfer-test1:
	$(info ************ TO test1 account // transfer COIN(ugnot), GRC20(bar, baz, foo, obl, qux, usdc) ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_TEST1) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo ""