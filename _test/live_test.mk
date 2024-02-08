# Test Mnemonic
# source bonus chronic canvas draft south burst lottery vacant surface solve popular case indicate oppose farm nothing bullet exhibit title speed wink action roast

# Test Accounts
# gnokey add -recover=true -index 10 gsa
# gnokey add -recover=true -index 11 lp01
# gnokey add -recover=true -index 12 lp02
# gnokey add -recover=true -index 13 tr01

ADDR_GSA := g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4
ADDR_LP01 := g1jqpr8r5akez83kp7ers0sfjyv2kgx45qa9qygd
ADDR_LP02 := g126yz2f34qdxaqxelmky40dym379q0vw3yzhyrq
ADDR_TR01 := g1wgdjecn5lylgvujzyspfzvhjm6qn4z8xqyyxdn

ADDR_POOL := g15z32w7txv6lw259xzhzzmwtwmcjjc0m6dqzh6f
ADDR_POS := g10wwa53xgu4397kvzz7akxar9370zjdpwux5th9
ADDR_STAKER := g1puv9dz470prjshjm9qyg25dyfvrgph2kvjph68
ADDR_ROUTER := g1pjtpgjpsn4hjfv2n4mpz8cczdn32jkpsqwxuav
ADDR_GOV := g1kmat25auuqf0h5qvd4q7s707r8let5sky4tr76

TX_EXPIRE := 9999999999

NOW := $(shell date +%s)
INCENTIVE_START := $(shell expr $(NOW) + 140) # GIVE ENOUTH TIME TO EXECUTE PREVIOUS TXS
INCENTIVE_END := $(shell expr $(NOW) + 140 + 7776000) # 7776000 SECONDS = 90 DAY

MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))
GNOLAND_RPC_URL ?= localhost:26657
CHAINID ?= dev
ROOT_DIR:=$(shell dirname $(MAKEFILE))/..

.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'

.PHONY: all
all: wait deploy faucet approve pool-setup position-mint staker-stake router-swap staker-unstake done

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-baz deploy-qux deploy-wugnot deploy-gns deploy-obl deploy-gnft deploy-const deploy-gov deploy-pool deploy-position deploy-staker deploy-router deploy-grc20_wrapper 

.PHONY: faucet
faucet: faucet-lp01 faucet-lp02 faucet-tr01 faucet-gsa

.PHONY: approve
approve: approve-test1 approve-lp01 approve-lp02 approve-tr01 approve-gsa

.PHONY: pool-setup
pool-setup: pool-init pool-create

.PHONY: position-mint
position-mint: wrap mint-01 mint-02 mint-03

.PHONY: staker-stake
staker-stake: create-external-incentive stake-token-1 stake-token-2

.PHONY: router-swap
router-swap: set-protocol-fee swap-exact-in-single swap-exact-out-multi collect-fee-lp01 collect-fee-lp02

.PHONY: staker-unstake
staker-unstake: unstake-token-1 burn-token-1 # burn-token-2


wait:
	$(shell sleep 10)

# Deploy Tokens
deploy-foo:
	$(info ************ [FOO] deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/foo -pkgpath gno.land/r/demo/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-bar:
	$(info ************ [BAR] deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/bar -pkgpath gno.land/r/demo/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-baz:
	$(info ************ [BAZ] deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/baz -pkgpath gno.land/r/demo/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-qux:
	$(info ************ [QUX] deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/qux -pkgpath gno.land/r/demo/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-wugnot:
	$(info ************ [WUGNOT] deploy wugnot ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/wugnot -pkgpath gno.land/r/demo/wugnot -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gns:
	$(info ************ [GNS] deploy staking reward ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/gns -pkgpath gno.land/r/demo/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-obl:
	$(info ************ [OBL] deploy external staking reward ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/obl -pkgpath gno.land/r/demo/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gnft:
	$(info ************ [GNFT] deploy lp token ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/gnft -pkgpath gno.land/r/demo/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Deploy Contracts
deploy-const:
	$(info ************ [CONST] deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/consts -pkgpath gno.land/r/demo/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gov:
	$(info ************ [GOV] deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov -pkgpath gno.land/r/demo/gov -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-pool:
	$(info ************ [POOL] deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/demo/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-position:
	$(info ************ [POSITION] deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/demo/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-staker:
	$(info ************ [STAKER] deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/demo/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-router:
	$(info ************ [ROUTER] deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/demo/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-grc20_wrapper:
	$(info ************ [GRC20 Wrapper] deploy grc20_wrapper ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/grc20_wrapper_test -pkgpath gno.land/r/demo/grc20_wrapper -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Facuet Tokens
faucet-lp01:
	$(info ************ [FAUCET] foo & bar & baz & qux to lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

faucet-lp02:
	$(info ************ [FAUCET] foo & bar & baz & qux to lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

faucet-tr01:
	$(info ************ [FAUCET] foo & bar & baz & qux to tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -args $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -args $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -args $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -args $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

faucet-gsa:
	$(info ************ [FAUCET] foo & bar & baz & qux & gns & obl to gsa ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Faucet -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Approve Tokens
approve-test1:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot & gns from test1 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

approve-lp01:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from lp01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

approve-lp02:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from lp02 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

approve-tr01:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from tr01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

approve-gsa:
	$(info ************ [APPROVE] from gsa (gns to pool // wugnot, obl to staker) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_STAKER) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Approve -args $(ADDR_STAKER) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Pool
pool-init:
	$(info ************ [POOL] init pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func InitManual -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

pool-create:
	$(info ************ [POOL] create pools ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/wugnot" -args "gno.land/r/demo/bar" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Position
wrap:
	$(info ************ [WUGNOT] wrap test1, lp01, lp02, tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Deposit -send "10000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Deposit -send "10000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Deposit -send "10000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Deposit -send "10000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo


mint-01:
	$(info ************ [POSITION - 1] mint gnot & bar // tick range 4000 ~ 6000 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/wugnot" -args "gno.land/r/demo/bar" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-02:
	$(info ************ [POSITION - 2] mint bar & baz // tick range 4000 ~ 6000 // by lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

mint-03:
	$(info ************ [POSITION - 3] mint baz & qux // tick range 4000 ~ 6000 // by lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

mint-04:
	$(info ************ [POSITION - 4] mint bar & baz // tick range 7000 ~ 8000 [ UPPER RANGE ] // by lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 7000 -args 8000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


# Staker
create-external-incentive:
	$(info ************ [STAKER] create external incentive ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func CreateExternalIncentive -args "gno.land/r/demo/bar:gno.land/r/demo/baz:100" -args "gno.land/r/demo/obl" -args 10000000 -args $(INCENTIVE_START) -args $(INCENTIVE_END)-insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

stake-token-1:
	$(info ************ [STAKER] stake gnft tokenId 1)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

stake-token-2:
	$(info ************ [STAKER] stake gnft tokenId 2)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args "2" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


# Swap
set-protocol-fee:
	$(info ************ [POOL] Set Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func SetFeeProtocol -args 6 -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

swap-exact-in-single:
	$(info ************ [ROUTER] Swap 123_456 BAR to BAZ // singlePath  ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 123456  -args "EXACT_IN" -args "gno.land/r/demo/bar:gno.land/r/demo/baz:100" -args "100" -args 200000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

swap-exact-out-multi:
	$(info ************ [ROUTER] Swap NATIVE ugnot to 987_654 QUX // multiPath ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/wugnot" -args "gno.land/r/demo/qux" -args 987654  -args "EXACT_OUT" -args "gno.land/r/demo/wugnot:gno.land/r/demo/bar:100*POOL*gno.land/r/demo/bar:gno.land/r/demo/baz:100*POOL*gno.land/r/demo/baz:gno.land/r/demo/qux:100" -args "100" -args 654321 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

collect-fee-lp01:
	$(info ************ [POSITION] Collect swap fee at position of tokenId 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

collect-fee-lp02:
	$(info ************ [POSITION] Collect swap fee at position of tokenId 2 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func CollectFee -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


## Staker // Unstake
unstake-token-1:
	$(info ************ [STAKER] unstake gnft tokenId 1 ************)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

unstake-token-2:
	$(info ************ [STAKER] unstake gnft tokenId 2 ************)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

burn-token-1:
	$(info ************ [POSITION] Burn tokenId 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Burn -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid  $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null

burn-token-2:
	$(info ************ [POSITION] Burn tokenId 2 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Burn -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid  $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	

### can not test staker EndExternalIncentive
### it needs to wait for 90 days ( which we can't skip it in makefiles )

done:
	@echo "" | gnokey maketx send -send 1ugnot -to $(ADDR_GOV) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null



## ETC
# gno time.Now returns last block time, not actual time
# so to skip time, we need new block
skip-time:
	$(info > SKIP 3 BLOCKS)
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo