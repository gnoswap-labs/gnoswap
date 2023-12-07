# Test Mnemonic
# source bonus chronic canvas draft south burst lottery vacant surface solve popular case indicate oppose farm nothing bullet exhibit title speed wink action roast

# Test Accounts
# gnokey add -recover=true -index 10 gsa
# gnokey add -recover=true -index 11 lp01
ADDR_GSA := g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4
ADDR_LP01 := g1jqpr8r5akez83kp7ers0sfjyv2kgx45qa9qygd

ADDR_POOL := g1ee305k8yk0pjz443xpwtqdyep522f9g5r7d63w
ADDR_POS := g1htpxzv2dkplvzg50nd8fswrneaxmdpwn459thx
ADDR_STAKER := g13h5s9utqcwg3a655njen0p89txusjpfrs3vxp8
ADDR_ROUTER := g1ernz3lj85hnn3ucug73ymgkhqdv2lg8e4yd48e
ADDR_GOV := g1wj5lwwmkru3ky6dh2zztanrcj2ups8g0pfe8cu

TX_EXPIRE := 9999999999

MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))
GNOLAND_RPC_URL ?= localhost:26657
CHAINID ?= dev
ROOT_DIR:=$(shell dirname $(MAKEFILE))/..

.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'

.PHONY: all
all: deploy faucet approve pool-setup position-mint done

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-baz deploy-qux deploy-fred deploy-thud deploy-wugnot deploy-gns deploy-obl deploy-gnft deploy-gov deploy-pool deploy-position deploy-staker deploy-router deploy-grc20_wrapper 

.PHONY: faucet
faucet: faucet-lp01 faucet-gsa

.PHONY: approve
approve: approve-lp01 approve-gsa

.PHONY: pool-setup
pool-setup: pool-init pool-create

.PHONY: position-mint
position-mint: mint-01 mint-02 mint-03 mint-04 mint-05

# Deploy Tokens
# [GRC20] FOO, BAR, BAZ, QUX: Token Pair for Pool
# [GRC20] FRED, THUD: Dummy Token
# [GRC20] WUGNOT: Wrapped GRC20 for native ugnot
# [GRC20] GNS: Default Staking Reward
# [GRC20] OBL: External Staking Reward
# [GRC721] GNFT: LP Token
deploy-foo:
	$(info ************ [FOO] deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/foo -pkgpath gno.land/r/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-bar:
	$(info ************ [BAR] deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/bar -pkgpath gno.land/r/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-baz:
	$(info ************ [BAZ] deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/baz -pkgpath gno.land/r/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-qux:
	$(info ************ [QUX] deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/qux -pkgpath gno.land/r/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-fred:
	$(info ************ [QUX] deploy fred ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/fred -pkgpath gno.land/r/fred -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-thud:
	$(info ************ [QUX] deploy thud ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/thud -pkgpath gno.land/r/thud -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-wugnot:
	$(info ************ [WUGNOT] deploy wugnot ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/wugnot -pkgpath gno.land/r/wugnot -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gns:
	$(info ************ [GNS] deploy staking reward ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/gns -pkgpath gno.land/r/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-obl:
	$(info ************ [OBL] deploy external staking reward ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/obl -pkgpath gno.land/r/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gnft:
	$(info ************ [GNFT] deploy lp token ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/gnft -pkgpath gno.land/r/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Deploy Contracts
deploy-gov:
	$(info ************ [GOV] deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov -pkgpath gno.land/r/gov -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-pool:
	$(info ************ [POOL] deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-position:
	$(info ************ [POSITION] deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-staker:
	$(info ************ [STAKER] deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-router:
	$(info ************ [ROUTER] deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-grc20_wrapper:
	$(info ************ [GRC20 Wrapper] deploy grc20_wrapper ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/grc20_wrapper -pkgpath gno.land/r/grc20_wrapper -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Facuet Tokens
faucet-lp01:
	$(info ************ [FAUCET] foo & bar & baz & qux & wugnot to lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gns -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo


faucet-gsa:
	$(info ************ [FAUCET] foo & bar & baz & qux & wugnot & gns to gsa ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gns -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Approve Tokens
approve-lp01:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from lp01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gns -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo


approve-gsa:
	$(info ************ [APPROVE] from gsa (gns to pool, wugnot to staker) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gns -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_STAKER) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Pool
pool-init:
	$(info ************ [POOL] init pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func InitManual -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

pool-create:
	$(info ************ [POOL] create pools ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gnot" -args "gno.land/r/bar" -args 100 -args 112046633483750523682330982 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 112040957517951813098925484553 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/baz" -args "gno.land/r/foo" -args 100 -args 177157928842132501967358423881 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/gns" -args "gnot" -args 100 -args 79228214880679474632347256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/gns" -args "gno.land/r/qux" -args 100 -args 250541420775534450580036817218 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Position
mint-01:
	$(info ************ [POSITION - 1] mint gnot & bar // tick range -132230 ~ -130230 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gnot" -args "gno.land/r/bar" -args 100 -args -132230 -args -130230 -args 1000000000 -args 1000000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "1000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-02:
	$(info ************ [POSITION - 2] mint bar & baz // tick range 5932 ~ 7932 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 5932 -args 7932 -args 1000 -args 999999 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-03:
	$(info ************ [POSITION - 3] mint baz & foo // tick range 15096 ~ 17096 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/baz" -args "gno.land/r/foo" -args 100 -args 15096 -args 17096 -args 1000 -args 999999 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-04:
	$(info ************ [POSITION - 4] mint gns & gnot // tick range -139162 ~ -137162 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/gns" -args "gnot" -args 100 -args -139162 -args -137162 -args 1000000000 -args 1000000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "1000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-05:
	$(info ************ [POSITION - 5] mint gns & qux // tick range 22028 ~ 24028 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/gns" -args "gno.land/r/qux" -args 100 -args 22028 -args 24028 -args 1000 -args 999999 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

done:
	@echo "" | gnokey maketx send -send 1ugnot -to $(ADDR_GOV) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

