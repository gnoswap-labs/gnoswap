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
all: deploy approve pool-setup position-setup done

.PHONY: deploy
deploy: deploy-grc20s deploy-gnft deploy-gov deploy-pool deploy-position deploy-staker deploy-router deploy-grc20_wrapper 

.PHONY: approve
approve: approve-test1

.PHONY: pool-setup
pool-setup: pool-init pool-create

.PHONY: position-setup
position-setup: position-mint

# Deploy Tokens
deploy-grc20s:
	$(info ************ [GRC20] deploy tokens ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/wugnot -pkgpath gno.land/r/wugnot -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/bar -pkgpath gno.land/r/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/baz -pkgpath gno.land/r/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/foo -pkgpath gno.land/r/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/fred -pkgpath gno.land/r/fred -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/gns -pkgpath gno.land/r/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/obl -pkgpath gno.land/r/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/qux -pkgpath gno.land/r/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st1 -pkgpath gno.land/r/st1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st2 -pkgpath gno.land/r/st2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st3 -pkgpath gno.land/r/st3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st4 -pkgpath gno.land/r/st4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st5 -pkgpath gno.land/r/st5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st11 -pkgpath gno.land/r/st11 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st22 -pkgpath gno.land/r/st22 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st33 -pkgpath gno.land/r/st33 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st44 -pkgpath gno.land/r/st44 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/st55 -pkgpath gno.land/r/st55 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/testtokena -pkgpath gno.land/r/testtokena -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/testtokenb -pkgpath gno.land/r/testtokenb -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_setup/testtokenc -pkgpath gno.land/r/testtokenc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	
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


# Approve Tokens
approve-test1:
	$(info ************ [APPROVE] grc20 tokens from test1 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/wugnot -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/baz -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/fred -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gns -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/obl -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/qux -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st1 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st2 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st3 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st4 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st5 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st11 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st22 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st33 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st44 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/st55 -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/testtokena -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/testtokenb -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/testtokenc -func Approve -args $(ADDR_POOL) -args 500000000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null	
	@echo


# Pool
pool-init:
	$(info ************ [POOL] init pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func InitManual -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

pool-create:
	$(info ************ [POOL] create pools ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gnot" -args "gno.land/r/bar" -args 100 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/baz" -args "gno.land/r/foo" -args 100 -args 177166786517138269218369076073 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/gns" -args "gnot" -args 100 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/gns" -args "gno.land/r/qux" -args 100 -args 250553947533412109193337304115 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st2" -args 100 -args 78636203513782394569765110859 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st2" -args 3000 -args 79816596014554786537349811406 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st3" -args 500 -args 114963330138887223051344675935 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st3" -args 10000 -args 114127195240248353140234912719 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st4" -args 100 -args 96223355229883343171379415442 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st4" -args 3000 -args 94577818186581255193903899028 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st5" -args 500 -args 105553452024597856248239970211 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st1" -args "gno.land/r/st5" -args 10000 -args 104060055720203537188615070492 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st3" -args 100 -args 114951834955391683882956380297 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st3" -args 3000 -args 113575045994529217799398739318 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st4" -args 500 -args 93744538858360434067702382727 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st4" -args 10000 -args 98639408880844237329631226990 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st5" -args 100 -args 107046870051799045081314970900 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st2" -args "gno.land/r/st5" -args 3000 -args 103303220962225903261255492424 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st3" -args "gno.land/r/st4" -args 500 -args 65597741190543616110355062640 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st3" -args "gno.land/r/st4" -args 10000 -args 64634091399937790156998403932 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st3" -args "gno.land/r/st5" -args 100 -args 71936706074190924971728256808 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st3" -args "gno.land/r/st5" -args 3000 -args 71238766072602061195894228565 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st4" -args "gno.land/r/st5" -args 500 -args 87350341247483919659585300674 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st4" -args "gno.land/r/st5" -args 10000 -args 86446650220495278410339891092 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null


	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st22" -args 100 -args 78632271998467896963137734028 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st22" -args 3000 -args 79816596014554786537349811406 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st33" -args 500 -args 114951834955391683882956380297 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st33" -args 10000 -args 114127195240248353140234912719 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st44" -args 100 -args 96223355229883343171379415442 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st44" -args 3000 -args 94577818186581255193903899028 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st55" -args 500 -args 105553452024597856248239970211 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st11" -args "gno.land/r/st55" -args 10000 -args 104060055720203537188615070492 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st33" -args 100 -args 105553452024597856248239970211 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st33" -args 3000 -args 113575045994529217799398739318 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st44" -args 500 -args 93744538858360434067702382727 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st44" -args 10000 -args 98639408880844237329631226990 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st55" -args 100 -args 107036166435155529528362134687 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st22" -args "gno.land/r/st55" -args 3000 -args 103303220962225903261255492424 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st33" -args "gno.land/r/st44" -args 500 -args 65597741190543616110355062640 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st33" -args "gno.land/r/st44" -args 10000 -args 64634091399937790156998403932 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st33" -args "gno.land/r/st55" -args 100 -args 71936706074190924971728256808 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st33" -args "gno.land/r/st55" -args 3000 -args 71238766072602061195894228565 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st44" -args "gno.land/r/st55" -args 500 -args 87350341247483919659585300674 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args "gno.land/r/st44" -args "gno.land/r/st55" -args 10000 -args 86446650220495278410339891092 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Position
position-mint:
	$(info ************ [POSITION] MINT ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gnot" -args "gno.land/r/bar" -args 100 -args 5932 -args 7932 -args 1000000000 -args 10000000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "1000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/bar" -args "gno.land/r/baz" -args 100 -args 5932 -args 7932 -args 1000000000 -args 10000000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/baz" -args "gno.land/r/foo" -args 100 -args 15096 -args 17096 -args 1000000000 -args 10000000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/gns" -args "gnot" -args 100 -args -1000 -args 1000 -args 1000000000 -args 1000000000 -args 0 -args 0 -args $(TX_EXPIRE) -send "1000000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/gns" -args "gno.land/r/qux" -args 100 -args 22028 -args 24028 -args 1000000000 -args 1000000000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st2" -args 100 -args -14016 -args 2080 -args 40000000000 -args 186543000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st2" -args 3000 -args 1560 -args 14640 -args 160000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st3" -args 500 -args -6420 -args 9680 -args 150000000000 -args 1492690000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st3" -args 10000 -args 8600 -args 21800 -args 850000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st4" -args 100 -args -9976 -args 6120 -args 20000000000 -args 139685000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st4" -args 3000 -args 4920 -args 18000 -args 180000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st5" -args 500 -args -8130 -args 7970 -args 350000000000 -args 2943960000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st1" -args "gno.land/r/st5" -args 10000 -args 6800 -args 20000 -args 650000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st3" -args 100 -args -6420 -args 9676 -args 80000000000 -args 797115000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st3" -args 3000 -args 8580 -args 21660 -args 120000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st4" -args 500 -args -10500 -args 5600 -args 90000000000 -args 595920000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st4" -args 10000 -args 5800 -args 18800 -args 110000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st5" -args 100 -args -7846 -args 8248 -args 170000000000 -args 1468390000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st2" -args "gno.land/r/st5" -args 3000 -args 6720 -args 19800 -args 30000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st3" -args "gno.land/r/st4" -args 500 -args -17640 -args -1540 -args 10000000000 -args 32406000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st3" -args "gno.land/r/st4" -args 10000 -args -2600 -args 10400 -args 190000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st3" -args "gno.land/r/st5" -args 100 -args -15796 -args 300 -args 250000000000 -args 975796000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st3" -args "gno.land/r/st5" -args 3000 -args -720 -args 12360 -args 750000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st4" -args "gno.land/r/st5" -args 500 -args -11910 -args 4180 -args 5000000000 -args 28808800000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st4" -args "gno.land/r/st5" -args 10000 -args 3200 -args 16200 -args 195000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null


	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st22" -args 100 -args -14014 -args 2080 -args 20000000000 -args 93281000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st22" -args 3000 -args 1560 -args 14640 -args 16000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st33" -args 500 -args -6420 -args 9670 -args 15000000000 -args 149269000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st33" -args 10000 -args 8600 -args 21800 -args 85000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st44" -args 100 -args -9978 -args 6114 -args 2000000000 -args 13968500000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st44" -args 3000 -args 4920 -args 18000 -args 18000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st55" -args 500 -args -8130 -args 7970 -args 35000000000 -args 294396000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st11" -args "gno.land/r/st55" -args 10000 -args 6800 -args 20000 -args 65000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st33" -args 100 -args -6420 -args 9674 -args 8000000000 -args 79745300000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st33" -args 3000 -args 8580 -args 21660 -args 12000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st44" -args 500 -args -10500 -args 5600 -args 900000000000 -args 5959200000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st44" -args 10000 -args 5800 -args 18800 -args 1100000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st55" -args 100 -args -7848 -args 8248 -args 17000000000 -args 146986000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st22" -args "gno.land/r/st55" -args 3000 -args 6720 -args 19800 -args 30000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st33" -args "gno.land/r/st44" -args 500 -args -17640 -args -1550 -args 10000000000 -args 32406000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st33" -args "gno.land/r/st44" -args 10000 -args -2600 -args 10400 -args 19000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st33" -args "gno.land/r/st55" -args 100 -args -15794 -args 300 -args 25000000000 -args 97589400000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st33" -args "gno.land/r/st55" -args 3000 -args -720 -args 12360 -args 75000000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st44" -args "gno.land/r/st55" -args 500 -args -11910 -args 4180 -args 15000000000 -args 86476200000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args "gno.land/r/st44" -args "gno.land/r/st55" -args 10000 -args 3200 -args 16200 -args 17500000000 -args 0 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


done:
	$(info ************ [DONE] send 1ugnot to gov ************)
	@echo "" | gnokey maketx send -send 1ugnot -to $(ADDR_GOV) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

