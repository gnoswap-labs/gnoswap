# make -f __local/test/test_data.mk init init-test

ADDR_GSA := g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d

ADDR_LP01 := g1qf5863trkaq447zr2xdmql83g0twzl37dm9qqt
ADDR_LP02 := g1ta0w7j4f586kwqu584z5h5sjurzywz3na7qg0a
ADDR_TR01 := g14m6fj3t8005u77ku6zyzazq9vd9hwhl00ppt8j

ADDR_REGISTER := g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5


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

# INCENTIVE_START
# TOMORROW_MIDNIGHT := $(shell date +%s) # DEV
TOMORROW_MIDNIGHT := $(shell (gdate -ud 'tomorrow 00:00:00' +%s))
INCENTIVE_END := $(shell expr $(TOMORROW_MIDNIGHT) + 7776000) # 7776000 SECONDS = 90 DAY


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
init-test:  test-send-ugnot test-grc20-transfer test-pool-create test-position-mint test-increase-decrease test-create-external-incentive test-stake-token test-swap # test-collect-fee test-unstake-token test-burn-position

.PHONY: test-grc20-transfer
test-grc20-transfer: transfer-foo transfer-bar transfer-baz transfer-qux transfer-obl

.PHONY: test-pool-create
test-pool-create: pool-create-bar-baz pool-create-baz-qux pool-create-qux-foo pool-create-foo-gns pool-create-gns-wugnot

.PHONY: test-position-mint
test-position-mint: mint-bar-baz mint-baz-qux mint-qux-foo mint-gns-gnot mint-gns-foo

.PHONY: test-increase-decrease
test-increase-decrease: increase-liquidity-position-01 decrease-liquidity-position-01

.PHONY: test-create-external
test-create-external-incentive: create-external-incentive create-external-incentive-2 create-external-incentive-3

.PHONY: test-stake-token
test-stake-token: stake-token-8 stake-token-9 mint-and-stake

.PHONY: test-swap
test-swap: swap-exact-in-single-bar-to-baz swap-exact-in-single-baz-to-bar


# .PHONY: test-collect-fee
# test-collect-fee: collect-fee-position-1

# .PHONY: test-unstake-token
# test-unstake-token: unstake-token-1-5 unstake-token-6 unstake-token-7 unstake-token-8

# .PHONY: test-burn-position
# test-burn-position: burn-position-1 burn-position-2 burn-position-6 burn-position-7



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


# send ugnot to test accounts
test-send-ugnot:
	$(info ************ send ugnot to test accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
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


# transfer grc20s
transfer-foo:
	$(info ************ transfer foo ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-bar:
	$(info ************ transfer bar ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-baz:
	$(info ************ transfer baz ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-qux:
	$(info ************ transfer qux ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-obl:
	$(info ************ transfer obl ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
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
	
	# tick +10 ≈ x1.00100045012002092370551054045790806412696838378906 ≈ 79267784519130042428790663799
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 500 -args 79267784519130042428790663799 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# tick 46055 ≈ x100.00995593181238518809550441801548004150390625000000 ≈ 792321063670230269303669868814
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 3000 -args 792321063670230269303669868814 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-baz-qux:
	$(info ************ create pool baz:qux ************)
	# tick 23028 ≈ x10.00099779659037757539863378042355179786682128906250 ≈ 250553947533412109193337304115
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 500 -args 250553947533412109193337304115 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-qux-foo:
	$(info ************ create pool qux:foo ************)
	# tick 6932 ≈ x2.00003632383094753777186269871890544891357421875000 ≈ 112046559425783515914356180039
	# tick -6932 ≈ x0.49999091920718774506582349204109050333499908447266 ≈ 56022262241300288188759753413
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/onbloc/foo" -args "gno.land/r/onbloc/qux" -args 500 -args 56022262241300288188759753413 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-foo-gns:
	$(info ************ create pool foo:gns ************)
	# tick 0 ≈ x1 ≈ 79228162514264337593543950337
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gno.land/r/gnoswap/v1/gns" -args "gno.land/r/onbloc/foo"  -args 500 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-gns-wugnot:
	$(info ************ create pool gns:wugnot ************)
	# tick 10 ≈ x1.00100045012002092370551054045790806412696838378906 ≈ 79267784519130042428790663799
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func CreatePool -args "gnot" -args "gno.land/r/gnoswap/v1/gns" -args 100 -args 79267784519130042428790663799 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


## test mint position
mint-bar-baz:
	$(info ************ mint positions(1~5) to bar:baz // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 100 -args "-20" -args 0 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 100 -args 0 -args 10 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 100 -args "-30" -args "-20" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 500 -args 0 -args 20 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 3000 -args 36060 -args 56040 -args 100 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

mint-baz-qux:
	$(info ************ mint position(6) to baz:qux // gnoswap_lp02 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 500 -args 13030 -args 33030 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

mint-qux-foo:
	$(info ************ mint position(7) to qux:foo // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args 5930 -args 7930 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


mint-gns-gnot:
	$(info ************ mint position(8) to gns:wugnot // gnoswap_admin ************)
	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# APPROVE WUGNOT TO POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -send "20000000ugnot" -args "gno.land/r/gnoswap/v1/gns" -args "gnot" -args 3000 -args "-49980" -args "49980" -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


mint-gns-foo:
	$(info ************ mint position(9) to gns:foo // gnoswap_admin ************)
	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func Mint -args "gno.land/r/gnoswap/v1/gns" -args "gno.land/r/onbloc/foo" -args 500 -args -6000 -args 6000 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo



# test increase - decrease
increase-liquidity-position-01:
	$(info ************ increase position(1) liquidity bar:baz:100 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func IncreaseLiquidity  -args 1 -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

decrease-liquidity-position-01:
	$(info ************ decrease position(1) liquidity bar:baz:100 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/position -func DecreaseLiquidity -args 1 -args 10 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


## test create external incentive
create-external-incentive:
	$(info ************ create external incentive [foo] => gns:foo:500 // gnoswap_admin ************)
	# APPROVE REWARD
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	## APROVE GNS (DEPOSIT)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN CREATE EXTERNAL INCENTIVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func CreateExternalIncentive -args "gno.land/r/gnoswap/v1/gns:gno.land/r/onbloc/foo:500" -args "gno.land/r/onbloc/foo" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


create-external-incentive-2:
	$(info ************ create external incentive [gns] => gns:foo:500 // gnoswap_admin ************)
	# APPROVE REWARD ( and DEPOSIT )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo
	
	# THEN CREATE EXTERNAL INCENTIVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func CreateExternalIncentive -args "gno.land/r/gnoswap/v1/gns:gno.land/r/onbloc/foo:500" -args "gno.land/r/gnoswap/v1/gns" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


create-external-incentive-3:
	$(info ************ create external incentive [foo] => gns:foo:500 // gnoswap_lp01 ************)
	# APPROVE REWARD
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	## TRANSFER GNS FROM admin to lp01
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns  -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	## APROVE GNS (DEPOSIT)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN CREATE EXTERNAL INCENTIVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func CreateExternalIncentive -args "gno.land/r/gnoswap/v1/gns:gno.land/r/onbloc/foo:500" -args "gno.land/r/onbloc/foo" -args 500000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


## test stake-token + mint_and_stake
stake-token-8:
	$(info ************ stake token 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func Approve -args $(ADDR_STAKER) -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func StakeToken -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-9:
	$(info ************ stake token 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gnft -func Approve -args $(ADDR_STAKER) -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func StakeToken -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-and-stake:
	$(info ************ mint and stake(10), to same position with lpTokenId 8 (gns:gnot:3000) // gnoswap_admin ************)
	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func MintAndStake -send "20000000ugnot" -args "gno.land/r/gnoswap/v1/gns" -args "gnot" -args 3000 -args "-49980" -args "49980" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

## test swap
swap-gns-to-gnot:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap gns -> gnot, exact_in // gnoswap_admin ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/gnoswap/v1/gns" -args "gno.land/r/demo/wugnot" -args 50000 -args "EXACT_IN" -args "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:3000" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-gnot-to-gns:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap gnot -> gns, exact_in // gnoswap_admin ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/demo/wugnot" -args "gno.land/r/gnoswap/v1/gns" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-bar-to-baz:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap bar -> baz, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 50000 -args "EXACT_IN" -args "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-baz-to-bar:
	$(info ************ swap baz -> bar, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/bar" -args 50000 -args "EXACT_IN" -args "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/onbloc/foo" -args "gno.land/r/gnoswap/v1/gns" -args 50000 -args "EXACT_IN" -args "gno.land/r/onbloc/foo:gno.land/r/gnoswap/v1/gns:500" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-out-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_out // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/onbloc/foo" -args "gno.land/r/gnoswap/v1/gns" -args 50000 -args "EXACT_OUT" -args "gno.land/r/onbloc/foo:gno.land/r/gnoswap/v1/gns:500" -args "100" -args "50000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-multi-foo-to-gns-to-wugnot:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap foo -> gns -> wugnot, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/router -func SwapRoute -args "gno.land/r/onbloc/foo" -args "gno.land/r/demo/wugnot" -args 50000 -args "EXACT_IN" -args "gno.land/r/onbloc/foo:gno.land/r/gnoswap/v1/gns:500*POOL*gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:3000" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo


set-pool-creation-fee:
	$(info ************ set pool creation fee to 100_000_000 uGNS ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/pool -func SetPoolCreationFee -args 100000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null


## ETC
print-fee-collector:
	$(info ************ print fee collector balance ************)
	@printf "BAR "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/bar.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "BAZ "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/baz.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "QUX "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/qux.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "FOO "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/foo.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "GNS "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/gnoswap/v1/gns.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "OBL "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/obl.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "USDC "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/onbloc/usdc.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "WUGNOT "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/wugnot.BalanceOf(\"$(ADDR_PROTOCOL_FEE)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "UGNOT "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="bank/balances/$(ADDR_PROTOCOL_FEE)"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo


## ETC
emission-debug:
	$(info ************ emission debug ************)
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/gnoswap/v1/staker.GetPrintInfo()"' | jq -r '.result.response.ResponseBase.Data' | base64 -d


## TEST
collect-reward-9:
	$(info ************ collect reward 9 // gnoswap_admin (3 externals) ************)
	# approve reward token(foo, gns) to staker
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v1/staker -func CollectReward -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


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