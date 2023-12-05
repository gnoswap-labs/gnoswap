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

ADDR_POOL := g1ee305k8yk0pjz443xpwtqdyep522f9g5r7d63w
ADDR_POS := g1htpxzv2dkplvzg50nd8fswrneaxmdpwn459thx
ADDR_STAKER := g13h5s9utqcwg3a655njen0p89txusjpfrs3vxp8
ADDR_ROUTER := g1ernz3lj85hnn3ucug73ymgkhqdv2lg8e4yd48e
ADDR_GOV := g1wj5lwwmkru3ky6dh2zztanrcj2ups8g0pfe8cu

TX_EXPIRE := 9999999999

NOW := $(shell date +%s)
INCENTIVE_START := $(shell expr $(NOW) + 120)
INCENTIVE_END := $(shell expr $(NOW) + 7776000) # 90 DAY

MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))
GNOLAND_RPC_URL ?= localhost:26657
CHAINID ?= dev
ROOT_DIR:=$(shell dirname $(MAKEFILE))/..

.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'

.PHONY: all
all: deploy faucet approve pool-setup position-mint 

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-baz deploy-qux deploy-wugnot deploy-gns deploy-obl deploy-gnft deploy-gov deploy-pool deploy-position deploy-staker deploy-router deploy-grc20_wrapper 

.PHONY: faucet
faucet: faucet-lp01 faucet-lp02 faucet-tr01 faucet-gsa

.PHONY: approve
approve: approve-lp01 approve-lp02 approve-tr01 approve-gsa

.PHONY: pool-setup
pool-setup: pool-init pool-create

.PHONY: position-mint
position-mint: mint-01 mint-02 mint-03 mint-rest

# Deploy Tokens
# [GRC20] FOO, BAR, BAZ, QUX: Token Pair for Pool
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
	@echo

faucet-lp02:
	$(info ************ [FAUCET] foo & bar & baz & qux & wugnot to lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

faucet-tr01:
	$(info ************ [FAUCET] foo & bar & baz & qux & wugnot to tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func FaucetL -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
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
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

approve-lp02:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from lp02 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

approve-tr01:
	$(info ************ [APPROVE] foo & bar & baz & qux & wugnot from tr01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
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
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gnot" -args "gno.land/r/bar" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/baz" -args "gno.land/r/qux" -args 100 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gnot" -args "gno.land/r/bar" -args 500 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/bar" -args "gno.land/r/baz" -args 500 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/baz" -args "gno.land/r/qux" -args 500 -args 101729702841318637793976746270 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo


# Position
mint-01:
	$(info ************ [POSITION - 1] mint gnot & bar // tick range 4000 ~ 6000 // by lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gnot" -args "gno.land/r/bar" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "10000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

mint-02:
	$(info ************ [POSITION - 2] mint bar & baz // tick range 4000 ~ 6000 // by lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

mint-03:
	$(info ************ [POSITION - 3] mint baz & qux // tick range 4000 ~ 6000 // by lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/baz" -args "gno.land/r/qux" -args 100 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

mint-rest:
	$(info ************ [POSITION - 4,5,6] ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/bar" -args "gnot" -args 500 -args -6000 -args -4000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "10000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/bar" -args "gno.land/r/baz" -args 500 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/baz" -args "gno.land/r/qux" -args 500 -args 4000 -args 6000 -args 10000000 -args 10000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


# Staker
create-external-incentive:
	$(info ************ [STAKER] create external incentive ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func CreateExternalIncentive -args "gno.land/r/bar:gnot:100" -args "gno.land/r/obl" -args 10000000000 -args $(INCENTIVE_START) -args $(INCENTIVE_END)-insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

stake-token-1:
	$(info ************ [STAKER] stake gnft tokenId 1)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnft -func Approve -args $(ADDR_STAKER) -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

stake-token-2:
	$(info ************ [STAKER] stake gnft tokenId 2)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnft -func Approve -args $(ADDR_STAKER) -args "2" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func StakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


# Swap
set-protocol-fee:
	$(info ************ [POOL] Set Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func SetFeeProtocol -args 6 -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

swap-exact-in-single:
	$(info ************ [ROUTER] Swap 123_456 BAR to BAZ // singlePath  ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/router -func SwapRoute -args "gno.land/r/bar" -args "gno.land/r/baz" -args 123456  -args "EXACT_IN" -args "gno.land/r/bar:gno.land/r/baz:100" -args "100" -args 200000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

swap-exact-out-multi:
	$(info ************ [ROUTER] Swap NATIVE ugnot to 987_654 QUX // multiPath ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/router -func SwapRoute -args "gnot" -args "gno.land/r/qux" -args 987654  -args "EXACT_OUT" -args "gnot:gno.land/r/bar:100*POOL*gno.land/r/bar:gno.land/r/baz:100*POOL*gno.land/r/baz:gno.land/r/qux:100,gnot:gno.land/r/bar:500*POOL*gno.land/r/bar:gno.land/r/baz:500*POOL*gno.land/r/baz:gno.land/r/qux:500" -args "40,60" -args 654321 -send 100000000ugnot -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo

collect-lp01:
	$(info ************ [POSITION] Collect swap fee at position of tokenId 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Collect -args 1 -args $(ADDR_LP01) -args 1000000 -args 1000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

collect-lp02:
	$(info ************ [POSITION] Collect swap fee at position of tokenId 2 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Collect -args 2 -args $(ADDR_LP02) -args 1000000 -args 1000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo


## Staker // Unstake
unstake-token-1:
	$(info ************ [STAKER] unstake gnft tokenId 1 ************)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func UnstakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

unstake-token-2:
	$(info ************ [STAKER] unstake gnft tokenId 2 ************)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func UnstakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

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