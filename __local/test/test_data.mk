ADDR_GSA := g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq
ADDR_FCL := g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906
ADDR_IRA := g1jms5fx2raq4qfkq3502mfh25g54nyl5qeuvz5y

ADDR_LABS := g1yr0dpfgthph7y6mepdx8afuec4q3ga2lg8tjt0
ADDR_LP01 := g1qf5863trkaq447zr2xdmql83g0twzl37dm9qqt
ADDR_LP02 := g1ta0w7j4f586kwqu584z5h5sjurzywz3na7qg0a
ADDR_TR01 := g14m6fj3t8005u77ku6zyzazq9vd9hwhl00ppt8j

ADDR_GOV := g1kmat25auuqf0h5qvd4q7s707r8let5sky4tr76
ADDR_POOL := g15z32w7txv6lw259xzhzzmwtwmcjjc0m6dqzh6f
ADDR_POSITION := g10wwa53xgu4397kvzz7akxar9370zjdpwux5th9
ADDR_ROUTER := g1pjtpgjpsn4hjfv2n4mpz8cczdn32jkpsqwxuav
ADDR_STAKER := g1puv9dz470prjshjm9qyg25dyfvrgph2kvjph68
ADDR_GNS := g1zs77uvf8mxzq5k6lu2g8l8fzm6fvf79zkp6cgg
ADDR_GNFT := g1mpsh77gemyy7ku2hu40c4t4w0ntegp4rg6m4cr
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
ROOT_DIR:=$(shell dirname $(MAKEFILE))/../../


## INIT
.PHONY: init
init: wait send-ugnot-must deploy-libraries deploy-base-tokens deploy-gnoswap-realms deploy-test-tokens register-token pool-create-gns-wugnot-default

.PHONY: deploy-libraries
deploy-libraries: deploy-uint256 deploy-int256 deploy-consts deploy-common deploy-package-pool

.PHONY: deploy-base-tokens
deploy-base-tokens: deploy-gns deploy-usdc deploy-gnft

.PHONY: deploy-test-tokens
deploy-test-tokens: deploy-foo deploy-bar deploy-baz deploy-qux deploy-obl deploy-test01-07

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-gov deploy-pool deploy-position deploy-router deploy-staker


### TEST AFTER INIT
.PHONY: init-test
init-test: test-send-ugnot test-grc20-transfer test-pool-create test-position-mint test-increase-decrease test-create-external-incentive test-stake-token test-swap # test-collect-fee test-unstake-token test-burn-position

.PHONY: test-grc20-transfer
test-grc20-transfer: transfer-foo transfer-bar transfer-baz transfer-qux transfer-obl

.PHONY: test-pool-create
test-pool-create: pool-create-bar-baz pool-create-baz-qux pool-create-qux-foo pool-create-foo-gns pool-create-gns-wugnot

.PHONY: test-position-mint
test-position-mint: mint-bar-baz mint-baz-qux mint-qux-foo mint-foo-gns mint-gns-gnot

.PHONY: test-increase-decrease
test-increase-decrease: increase-liquidity-position-01 decrease-liquidity-position-01 increase-liquidity-position-09 decrease-liquidity-position-09

.PHONY: test-create-external
test-create-external-incentive: create-external-incentive

.PHONY: test-stake-token
test-stake-token: stake-token-1-5 stake-token-6 stake-token-7 stake-token-8 stake-token-9 stake-token-10 mint-and-stake

.PHONY: test-swap
test-swap: swap-exact-in-single-bar-to-baz swap-exact-in-single-baz-to-bar swap-exact-in-single-foo-to-gns swap-exact-out-single-foo-to-gns swap-exact-in-multi-foo-to-gns-to-wugnot

.PHONY: test-collect-fee
test-collect-fee: collect-fee-position-1-5 collect-fee-position-6 

.PHONY: test-unstake-token
test-unstake-token: unstake-token-1-5 unstake-token-6 unstake-token-7 unstake-token-8

.PHONY: test-burn-position
test-burn-position: burn-position-1 burn-position-2 burn-position-6 burn-position-7



# wait chain to start
wait:
	$(info ************ [ETC] wait 5 seconds ************)
	$(shell sleep 5)
	@echo


# send ugnot to necessary accounts
send-ugnot-must:
	$(info ************ send ugnot to necessary accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_FCL) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_FCL) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo


# send ugnot to test accounts
test-send-ugnot:
	$(info ************ send ugnot to test accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null
	@echo


# deploy test grc20 tokens
deploy-foo:
	$(info ************ deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/foo -pkgpath gno.land/r/demo/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-bar:
	$(info ************ deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/bar -pkgpath gno.land/r/demo/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-baz:
	$(info ************ deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/baz -pkgpath gno.land/r/demo/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-qux:
	$(info ************ deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/qux -pkgpath gno.land/r/demo/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-obl:
	$(info ************ deploy obl ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/obl -pkgpath gno.land/r/demo/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


deploy-test01-07:
	$(info ************ deploy test01-07 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test01 -pkgpath gno.land/r/demo/test01 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test02 -pkgpath gno.land/r/demo/test02 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test03 -pkgpath gno.land/r/demo/test03 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test04 -pkgpath gno.land/r/demo/test04 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test05 -pkgpath gno.land/r/demo/test05 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test06 -pkgpath gno.land/r/demo/test06 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/test07 -pkgpath gno.land/r/demo/test07 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy base tokens
deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gns -pkgpath gno.land/r/demo/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gnft -pkgpath gno.land/r/demo/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/usdc -pkgpath gno.land/r/demo/usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy packages
deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/uint256 -pkgpath gno.land/p/demo/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/int256 -pkgpath gno.land/p/demo/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-package-pool:
	$(info ************ deploy package pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/pool -pkgpath gno.land/p/demo/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy common realms
deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gnoswap/consts -pkgpath gno.land/r/demo/gnoswap/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gnoswap/common -pkgpath gno.land/r/demo/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# deploy gnoswap realms
deploy-gov:
	$(info ************ deploy gov ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov -pkgpath gno.land/r/demo/gov -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/demo/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/demo/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/demo/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/demo/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


# Register
register-token:
	$(info ************ deploy register_gnodev ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/register_gnodev -pkgpath gno.land/r/demo/register_gnodev -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	
	# run grc20-register now
	$(shell sleep 20)
	@echo


# transfer grc20s
transfer-foo:
	$(info ************ transfer foo ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-bar:
	$(info ************ transfer bar ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-baz:
	$(info ************ transfer baz ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-qux:
	$(info ************ transfer qux ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

transfer-obl:
	$(info ************ transfer obl ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Transfer -args $(ADDR_LP01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Transfer -args $(ADDR_LP02) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Transfer -args $(ADDR_TR01) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# default pool create
pool-create-gns-wugnot-default:
	$(info ************ create default pool (GNS:WUGNOT:0.03%) ************)
	# tick 0 ≈ x1 ≈ 79228162514264337593543950337
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/gns" -args "gno.land/r/demo/wugnot" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# test pool create
pool-create-bar-baz:
	$(info ************ create pool bar:baz ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	
	# tick +10 ≈ x1.00100045012002092370551054045790806412696838378906 ≈ 79267784519130042428790663799
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 500 -args 79267784519130042428790663799 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	# tick 46055 ≈ x100.00995593181238518809550441801548004150390625000000 ≈ 792321063670230269303669868814
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 3000 -args 792321063670230269303669868814 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

pool-create-baz-qux:
	$(info ************ create pool baz:qux ************)
	# tick 23028 ≈ x10.00099779659037757539863378042355179786682128906250 ≈ 250553947533412109193337304115
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 500 -args 250553947533412109193337304115 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

pool-create-qux-foo:
	$(info ************ create pool qux:foo ************)
	# tick 6932 ≈ x2.00003632383094753777186269871890544891357421875000 ≈ 112046559425783515914356180039
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/qux" -args "gno.land/r/demo/foo" -args 500 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

pool-create-foo-gns:
	$(info ************ create pool foo:gns ************)
	# tick 6932 ≈ x2.00003632383094753777186269871890544891357421875000 ≈ 112046559425783515914356180039
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 500 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

pool-create-gns-wugnot:
	$(info ************ create pool gns:wugnot ************)
	# tick +10 ≈ x1.00100045012002092370551054045790806412696838378906 ≈ 79267784519130042428790663799
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/gns" -args "gnot" -args 100 -args 79267784519130042428790663799 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


## test mint position
mint-bar-baz:
	$(info ************ mint positions(1~5) to bar:baz // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-20" -args 0 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 0 -args 10 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-30" -args "-20" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 500 -args 0 -args 20 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 3000 -args 36060 -args 56040 -args 100 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

mint-baz-qux:
	$(info ************ mint position(6) to baz:qux // gnoswap_lp02 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 500 -args 13030 -args 33030 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

mint-qux-foo:
	$(info ************ mint position(7) to qux:foo // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/qux" -args "gno.land/r/demo/foo" -args 500 -args 5930 -args 7930 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

mint-foo-gns:
	$(info ************ mint position(8) to foo:gns // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 500 -args "-887270" -args "887270" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-gns-gnot:
	$(info ************ mint position(9~10) to gns:wugnot // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# APPROVE WUGNOT TO POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -send "20000000ugnot" -args "gno.land/r/demo/gns" -args "gnot" -args 3000 -args "-49980" -args "49980" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -send "20000000ugnot" -args "gno.land/r/demo/gns" -args "gnot" -args 100 -args "-50000" -args "50000" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


# test increase - decrease
increase-liquidity-position-01:
	$(info ************ increase position(1) liquidity bar:baz:100 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func IncreaseLiquidity  -args 1 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

decrease-liquidity-position-01:
	$(info ************ decrease position(1) liquidity bar:baz:100 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 1 -args 10 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

increase-liquidity-position-09:
	$(info ************ increase position(9) liquidity gns:wugnot:3000 // gnoswap_admin ************)

	# APPROVE WUGNOT TO POSITION, for wrapping
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func IncreaseLiquidity -send "20000000ugnot" -args 9 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

decrease-liquidity-position-09:
	$(info ************ decrease position(9) liquidity gns:wugnot:3000 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 9 -args 10 -args 0 -args 0 -args $(TX_EXPIRE) -args "true" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_admin > /dev/null
	@echo


## test create external incentive
create-external-incentive:
	$(info ************ create external incentive // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN CREATE EXTERNAL INCENTIVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func CreateExternalIncentive -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "gno.land/r/demo/obl" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


## test stake-token + mint_and_stake
stake-token-1-5:
	$(info ************ stake token 1~5 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

stake-token-6:
	$(info ************ stake token 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

stake-token-7:
	$(info ************ stake token 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

stake-token-8:
	$(info ************ stake token 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-9:
	$(info ************ stake token 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-10:
	$(info ************ stake token 10 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-and-stake:
	$(info ************ mint and stake(11), to same position with lpTokenId 1 // gnoswap_lp02 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func MintAndStake -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-200" -args "190" -args 50000000 -args 50000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo


## test swap
swap-exact-in-single-bar-to-baz:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap bar -> baz, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/bar:gno.land/r/demo/baz:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-baz-to-bar:
	$(info ************ swap baz -> bar, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/baz" -args "gno.land/r/demo/bar" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/baz:gno.land/r/demo/bar:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-out-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_out // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 50000 -args "EXACT_OUT" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "100" -args "50000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-multi-foo-to-gns-to-wugnot:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap foo -> gns -> wugnot, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/wugnot" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500*POOL*gno.land/r/demo/gns:gno.land/r/demo/wugnot:3000" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo


## test collect fee
collect-fee-position-1-5:
	$(info ************ collect fee from position 1~5 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

collect-fee-position-6:
	$(info ************ collect fee from position 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

collect-fee-position-7:
	$(info ************ collect fee from position 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

collect-fee-position-8:
	$(info ************ collect fee from position 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

collect-fee-position-9:
	$(info ************ collect fee from position 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

collect-fee-position-10:
	$(info ************ collect fee from position 10 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

collect-fee-position-11:
	$(info ************ collect fee from position 11 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 11 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

unstake-token-1-5:
	$(info ************ unstake token 1~5 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


## test collect reward
collect-reward-9:
	$(info ************ collect reward 9 // gnoswap_admin ************)

	# approve reward token(gns) to STAKER
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func CollectReward -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


## test unstake token
unstake-token-6:
	$(info ************ unstake token 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

unstake-token-7:
	$(info ************ unstake token 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

unstake-token-8:
	$(info ************ unstake token 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-9:
	$(info ************ unstake token 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-10:
	$(info ************ unstake token 10 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-11:
	$(info ************ unstake token 11 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 11 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp02 > /dev/null
	@echo


## test position burn
burn-position-1:
	$(info ************ decrease entire liquidity(==burn) from position 1 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 1 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 12000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

burn-position-2:
	$(info ************ decrease entire liquidity(==burn) from position 2 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 2 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 12000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

burn-position-6:
	$(info ************ decrease entire liquidity(==burn) from position 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 6 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 12000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

burn-position-7:
	$(info ************ decrease entire liquidity(==burn) from position 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 7 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 12000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


## ETC
print-fee-collector:
	$(info ************ print fee collector balance ************)
	@printf "BAR "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/bar\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "BAZ "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/baz\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "QUX "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/qux\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "FOO "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/foo\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "GNS "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/gns\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "OBL "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/obl\nBalanceOf(\"$(ADDR_FCL)\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "USDC "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/wugnot\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "WUGNOT "
	@curl -s '$(GNOLAND_RPC_URL)/abci_query?path="vm/qeval"&data="gno.land/r/demo/wugnot\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo
	@echo




##
test-pool-create-01-07:
	$(info ************ test creat pool token01 - token07 // gnoswap_admin ************)
	# T1 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 100 -args 79228162514264337593543950336 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 500 -args 79228162514264337593543950336 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 10000 -args 79228162514264337593543950336 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 100 -args 112040957517951813098925484553 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 500 -args 112040957517951813098925484553 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 3000 -args 112040957517951813098925484553 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 100 -args 45741651243340576588381802608 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 500 -args 45741651243340576588381802608 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 10000 -args 45741651243340576588381802608 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 100 -args 39613361802603482359327757997 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 500 -args 39613361802603482359327757997 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 3000 -args 39613361802603482359327757997 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 100 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 500 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 10000 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 100 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 500 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 3000 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo



	# T2 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 100 -args 125268435273034278662106613985 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 500 -args 125268435273034278662106613985 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 10000 -args 125268435273034278662106613985 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 100 -args 42347659051118714933317147195 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 500 -args 42347659051118714933317147195 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 3000 -args 42347659051118714933317147195 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 100 -args 168063893057866390736410267866 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 500 -args 168063893057866390736410267866 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 10000 -args 168063893057866390736410267866 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 100 -args 185803414919609663338769187695 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 500 -args 185803414919609663338769187695 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 3000 -args 185803414919609663338769187695 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 100 -args 201983302084203846042855734064 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 500 -args 201983302084203846042855734064 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 10000 -args 201983302084203846042855734064 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


	# T3 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 100 -args 28928642580389284744729996347 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 500 -args 28928642580389284744729996347 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 3000 -args 28928642580389284744729996347 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 100 -args 56022262241300288188759753413 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 500 -args 56022262241300288188759753413 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 10000 -args 56022262241300288188759753413 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 100 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 500 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 3000 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 100 -args 143919192289106366690228709881 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 500 -args 143919192289106366690228709881 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 10000 -args 143919192289106366690228709881 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo


	# T4 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 100 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 500 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 3000 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 100 -args 209617234798521195396786051541 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 500 -args 209617234798521195396786051541 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 10000 -args 209617234798521195396786051541 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 100 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 500 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 3000 -args 194063811628978436763827156157 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo



	# T5 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 100 -args 33781875895837640503774932014 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 500 -args 33781875895837640503774932014 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 10000 -args 33781875895837640503774932014 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 100 -args 203534321882434658179006309724 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 500 -args 203534321882434658179006309724 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 3000 -args 203534321882434658179006309724 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# T6 START
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 100 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 500 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 10000 -args 35430465601290701888012765807 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo






test-mint-01-07:
	$(info ************ mint token 01-07 // gnoswap_admin ************)
	# APPROVE FISRT
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test01 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test02 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test03 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test04 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test05 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test06 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/test07 -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# T1 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 100 -args "-6932" -args "6932" -args 100000000000 -args 100000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 100 -args "-7420" -args "7986" -args 106201256326 -args 106201256326 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 500 -args "-7880" -args "5980" -args 1000000000000 -args 1000000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 500 -args "-8760" -args "9160" -args 1036028734242 -args 1036028734242 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 10000 -args "-1800" -args "5200" -args 532014600647 -args 532014600647 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test02" -args 10000 -args "-1000" -args "3600" -args 337765756771 -args 337765756771 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 100 -args "-23028" -args "23028" -args 280870166749 -args 280870166749 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 100 -args "-6932" -args "16096" -args 272030146427 -args 272030146427 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 500 -args "4050" -args "10990" -args 146062382463 -args 146062382463 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 500 -args "6910" -args "6950" -args 442046987614 -args 442046987614 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 3000 -args "1980" -args "12540" -args 358642522052 -args 358642522052 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test03" -args 3000 -args "3420" -args "11580" -args 155239074572 -args 155239074572 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 100 -args "-16096" -args "0" -args 562508440213 -args 562508440213 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 100 -args "-13864" -args "-6932" -args 41092857728 -args 41092857728 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 500 -args "-20800" -args "0" -args 327014145787 -args 327014145787 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 500 -args "-13860" -args "-6930" -args 123493078425 -args 123493078425 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 10000 -args "-19400" -args "16000" -args 6470622718 -args 6470622718 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test04" -args 10000 -args "-13600" -args "-9000" -args 23166482059 -args 23166482059 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 100 -args "-17920" -args "-6932" -args 638463861008 -args 638463861008 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 100 -args "-13884" -args "-13846" -args 380023301626 -args 380023301626 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 500 -args "-21970" -args "0" -args 1200510506426 -args 1200510506426 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 500 -args "-20800" -args "-10990" -args 36541253381 -args 36541253381 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 3000 -args "-19440" -args "-10980" -args 220772753729 -args 220772753729 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test05" -args 3000 -args "-21960" -args "0" -args 600856564327 -args 600856564327 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin



	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 100 -args "-23028" -args "-6932" -args 627509361227 -args 627509361227 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 100 -args "-21974" -args "-6932" -args 72179819188 -args 72179819188 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 500 -args "-42050" -args "-13860" -args 100000000000 -args 100000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 500 -args "-21980" -args "-10990" -args 442699863581 -args 442699863581 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 10000 -args "-19400" -args "-13800" -args 356144066864 -args 356144066864 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test06" -args 10000 -args "-23000" -args "-9200" -args 499555550854 -args 499555550854 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 100 -args "13862" -args "20796" -args 821789902092 -args 821789902092 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 100 -args "10986" -args "21974" -args 957614030043 -args 957614030043 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 500 -args "13860" -args "20800" -args 1642023534758 -args 1642023534758 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 500 -args "6930" -args "21970" -args 1382870753552 -args 1382870753552 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 3000 -args "16080" -args "23040" -args 699483794906 -args 699483794906 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test01" -args "gno.land/r/demo/test07" -args 3000 -args "0" -args "24840" -args 364073594326 -args 364073594326 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo




	# T2 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 100 -args "0" -args "16096" -args 313690621950 -args 313690621950 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 100 -args "6930" -args "17040" -args 100000000000 -args 100000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 500 -args "0" -args "40260" -args 11648610111 -args 11648610111 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 500 -args "0" -args "21970" -args 388600909063 -args 388600909063 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 10000 -args "7200" -args "18000" -args 200000000000 -args 200000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test03" -args 10000 -args "2200" -args "16000" -args 253843175539 -args 253843175539 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 100 -args "-17920" -args "-6932" -args 361678156156 -args 361678156156 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 100 -args "-17920" -args "0" -args 6897400538696 -args 6897400538696 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 500 -args "-20800" -args "-10990" -args 100000000000 -args 100000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 500 -args "-16100" -args "-10990" -args 158540649401 -args 158540649401 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 3000 -args "-17940" -args "0" -args 687407748770 -args 687407748770 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test04" -args 3000 -args "-19440" -args "-5580" -args 703271444276 -args 703271444276 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 100 -args "10986" -args "17918" -args 616340242559 -args 616340242559 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 100 -args "0" -args "19460" -args 1199841728611 -args 1199841728611 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 500 -args "13860" -args "179250" -args 38490273803 -args 38490273803 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 500 -args "0" -args "21970" -args 406173323016 -args 406173323016 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 10000 -args "11000" -args "19400" -args 420361932291 -args 420361932291 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test05" -args 10000 -args "8200" -args "22000" -args 443578017685 -args 443578017685 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 100 -args "6932" -args "21974" -args 1000342161660 -args 1000342161660 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 100 -args "6932" -args "20796" -args 2556074500385 -args 2556074500385 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 500 -args "13860" -args "21970" -args 37146250082 -args 37146250082 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 500 -args "10990" -args "17920" -args 3368852140124 -args 3368852140124 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 3000 -args "0" -args "19440" -args 2798672975286 -args 2798672975286 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test06" -args 3000 -args "10140" -args "24000" -args 164120263441 -args 164120263441 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 100 -args "16096" -args "20796" -args 809882085924 -args 809882085924 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 100 -args "10986" -args "21974" -args 1387485384301 -args 1387485384301 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 500 -args "6930" -args "23030" -args 1492431403396 -args 1492431403396 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 500 -args "13860" -args "19460" -args 384840542642 -args 384840542642 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 10000 -args "-887200" -args "887200" -args 649937758546 -args 649937758546 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test02" -args "gno.land/r/demo/test07" -args 10000 -args "11800" -args "25600" -args 652783607869 -args 652783607869 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo



	# T3 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 100 -args "-21974" -args "-17920" -args 909170104638 -args 909170104638 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 100 -args "-21974" -args "-6932" -args 416405203014 -args 416405203014 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 500 -args "-23030" -args "-21970" -args 20000000000 -args 20000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 500 -args "-20800" -args "-16100" -args 430733571690 -args 430733571690 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 3000 -args "-887220" -args "887220" -args 750072176849 -args 750072176849 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test04" -args 3000 -args "-27060" -args "-13200" -args 3769427973319 -args 3769427973319 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 100 -args "-10988" -args "0" -args 31922613274 -args 31922613274 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 100 -args "-21974" -args "0" -args 221643037616 -args 221643037616 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 500 -args "-23030" -args "23030" -args 280887666874 -args 280887666874 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 500 -args "-6940" -args "-6920" -args 29997545352 -args 29997545352 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin

	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 10000 -args "-11000" -args "0" -args 3183059201 -args 3183059201 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test05" -args 10000 -args "-13800" -args "0" -args 201563173011 -args 201563173011 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 100 -args "-17920" -args "-13864" -args 606104542844 -args 606104542844 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 100 -args "-20790" -args "-6930" -args 877649638582 -args 877649638582 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 500 -args "-20790" -args "-6930" -args 877649638582 -args 877649638582 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 500 -args "-16110" -args "-16090" -args 8573842507 -args 8573842507 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 3000 -args "-10980" -args "0" -args 10000000000 -args 10000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test06" -args 3000 -args "-17940" -args "-13860" -args 600527349889 -args 600527349889 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin




	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 100 -args "0" -args "17918" -args 574015775664 -args 574015775664 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 100 -args "11928" -args "11948" -args 403280035 -args 403280035 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 500 -args "6930" -args "13860" -args 79825840230 -args 79825840230 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 500 -args "-887270" -args "16100" -args 175680910214 -args 175680910214 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 10000 -args "11000" -args "18000" -args 100000000000 -args 100000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test03" -args "gno.land/r/demo/test07" -args 10000 -args "5000" -args "18800" -args 1665556973 -args 1665556973 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo





	# T4 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 100 -args "0" -args "21974" -args 483664089532 -args 483664089532 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 100 -args "13864" -args "21974" -args 11999411375 -args 11999411375 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 500 -args "0" -args "20800" -args 2645657104 -args 2645657104 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 500 -args "0" -args "39120" -args 54322073822 -args 54322073822 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 3000 -args "16080" -args "19440" -args 71891586720 -args 71891586720 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test05" -args 3000 -args "10980" -args "24840" -args 467541469014 -args 467541469014 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 100 -args "10986" -args "21974" -args 204753359876 -args 204753359876 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 100 -args "16096" -args "21974" -args 9180447077 -args 9180447077 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 500 -args "6930" -args "21970" -args 165779912631 -args 165779912631 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 500 -args "10990" -args "20800" -args 372926637517 -args 372926637517 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 10000 -args "11000" -args "23000" -args 14883748980 -args 14883748980 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test06" -args 10000 -args "12600" -args "26400" -args 381277210771 -args 381277210771 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 100 -args "0" -args "34014" -args 642255741475 -args 642255741475 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 100 -args "17908" -args "17928" -args 733260702 -args 733260702 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 500 -args "-887270" -args "887270" -args 333313649477 -args 333313649477 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 500 -args "10990" -args "21970" -args 957790886933 -args 957790886933 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 3000 -args "-115200" -args "23040" -args 267051175284 -args 267051175284 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test04" -args "gno.land/r/demo/test07" -args 3000 -args "11040" -args "24840" -args 3079942769102 -args 3079942769102 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo




	# T5 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 100 -args "-19460" -args "-6932" -args 961039539315 -args 961039539315 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 100 -args "-17060" -args "-17040" -args 11000733 -args 11000733 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 500 -args "-6930" -args "0" -args 1000000000000 -args 1000000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 500 -args "-23030" -args "-21970" -args 10000000000 -args 10000000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 10000 -args "-887200" -args "887200" -args 281129241820 -args 281129241820 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test06" -args 10000 -args "-24000" -args "-10200" -args 241450722505 -args 241450722505 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin




	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 100 -args "-69082" -args "115136" -args 65717311961 -args 65717311961 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 100 -args "18860" -args "18880" -args 8065747 -args 8065747 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 500 -args "-6920" -args "93160" -args 4902367586 -args 4902367586 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 500 -args "16100" -args "19460" -args 65376765453 -args 65376765453 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 3000 -args "-50220" -args "144660" -args 787553125 -args 787553125 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test05" -args "gno.land/r/demo/test07" -args 3000 -args "8460" -args "25800" -args 9146541088 -args 9146541088 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo




	# T6 START
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 100 -args "-46056" -args "6930" -args 99999999997 -args 99999999997 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 100 -args "-16108" -args "-16086" -args 1110999996 -args 1110999996 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 500 -args "-20960" -args "-7850" -args 994 -args 994 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 500 -args "-16110" -args "-16090" -args 1111000000 -args 1111000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin


	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 10000 -args "-67200" -args "-7800" -args 1000 -args 1000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/test06" -args "gno.land/r/demo/test07" -args 10000 -args "-887200" -args "887200" -args 123450 -args 123450 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin
	@echo
