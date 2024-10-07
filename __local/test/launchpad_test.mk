# make -f __local/test/launchpad.mk init init-test launchpad-test

ADDR_GSA := g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c
ADDR_REGISTER := g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5

ADDR_LP01 := g1qf5863trkaq447zr2xdmql83g0twzl37dm9qqt
ADDR_LP02 := g1ta0w7j4f586kwqu584z5h5sjurzywz3na7qg0a

ADDR_TR01 := g14m6fj3t8005u77ku6zyzazq9vd9hwhl00ppt8j # use this as project's recipient for testing launchpad

ADDR_POOL := g126swhfaq2vyvvjywevhgw7lv9hg8qan93dasu8
ADDR_POSITION := g1vsm68lq9cpn7x507s6gh59anmx86kxfhzyszu2
ADDR_ROUTER := g1cnz5gm2l09pm2k6rknjjar9a2w53fdhk4yjzy5
ADDR_STAKER := g14fclvfqynndp0l6kpyxkpgn4sljw9rr96hz46l
ADDR_PROTOCOL_FEE := g1397dea8xlfv5858xzhsly7k998xm2zlvrm93t2

ADDR_GOV_STAKER := g1gt2xzjcmhp2t08yh0nkmc3q822sr87t5n92rm0
ADR_GOV_GOV := g1eudq5dvx9sem5ascp0etlpk3kpxylz8kcy8cf5

ADDR_LAUNCHPAD := g1qslhn7vn69e09zwmz5hlz0273v3c33u5z8d9j7

## TOKENS
ADDR_GNS := g1ttcyeq0u5f6npysfxvew7tzucvwqy0qjp04p95
ADDR_GNFT := g1rn4pederer0qlw2f7k72ddywde6pv3v3vl69nc

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
deploy-libraries: deploy-uint256 deploy-int256 deploy-consts deploy-package-pool deploy-common 

.PHONY: deploy-base-tokens
deploy-base-tokens: deploy-gns deploy-usdc deploy-gnft

.PHONY: deploy-test-tokens
deploy-test-tokens: deploy-foo deploy-bar deploy-baz deploy-qux deploy-obl 

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-xgns deploy-emission deploy-pool deploy-position deploy-staker deploy-router deploy-community_pool deploy-protocol_fee deploy-gov-staker deploy-gov-governance deploy-launchpad 

### TEST AFTER INIT
.PHONY: init-test
init-test: test-pool-create test-position-mint test-stake-token 

.PHONY: test-pool-create
test-pool-create: pool-create-bar-baz pool-create-foo-qux

.PHONY: test-position-mint
test-position-mint: mint-gns-gnot 

.PHONY: test-stake-token
test-stake-token: stake-token-1 

## TEST GOV
.PHONY: gov-test
gov-test: gov-staker gov-propose-proposals gov-propose-cancel # gov-vote gov-execute

.PHONY: gov-staker
gov-staker: delegate-1 delegate-2 redelegate undelegate collect-undelegated collect-gov-reward

.PHONY: gov-propose-proposals
gov-propose-proposals: propose-text propose-community propose-param

.PHONY: gov-propose-cancel
gov-propose-cancel: cancel-text

.PHONY: gov-vote
gov-toe: vote-community vote-param

.PHONY: gov-execute
gov-execute: execute-community execute-param

## TEST LAUNCHPAD
.PHONY: launchpad-test
launchpad-test: launchpad-create-project # launchpad-deposit launchpad-collect-protocol launchpad-collect-reward # use return value from create-project(project_id) to deposit, collect-protocol, collect-reward

# wait chain to start
wait:
	$(info ************ [ETC] wait 1 seconds for chain to start ************)
	$(shell sleep 1)
	@echo


# send ugnot to necessary accounts
send-ugnot-must:
	$(info ************ send ugnot to necessary accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_PROTOCOL_FEE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_REGISTER) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_TR01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo


# deploy test grc20 tokens
deploy-foo:
	$(info ************ deploy foo ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/foo -pkgpath gno.land/r/onbloc/foo -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-bar:
	$(info ************ deploy bar ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/bar -pkgpath gno.land/r/onbloc/bar -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-baz:
	$(info ************ deploy baz ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/baz -pkgpath gno.land/r/onbloc/baz -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-qux:
	$(info ************ deploy qux ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/qux -pkgpath gno.land/r/onbloc/qux -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-obl:
	$(info ************ deploy obl ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/obl -pkgpath gno.land/r/onbloc/obl -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


# deploy base tokens
deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/gns -pkgpath gno.land/r/gnoswap/v2/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/gnft -pkgpath gno.land/r/gnoswap/v2/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-usdc:
	$(info ************ deploy usdc ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/onbloc/usdc -pkgpath gno.land/r/onbloc/usdc -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


# deploy packages
deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/uint256 -pkgpath gno.land/p/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/int256 -pkgpath gno.land/p/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-package-pool:
	$(info ************ deploy package pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/gnoswap/pool -pkgpath gno.land/p/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


# deploy common realms
deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/consts -pkgpath gno.land/r/gnoswap/v2/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/common -pkgpath gno.land/r/gnoswap/v2/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


# deploy gnoswap realms
deploy-xgns:
	$(info ************ deploy xgns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/xgns -pkgpath gno.land/r/gnoswap/v2/gov/xgns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo
	
deploy-emission:
	$(info ************ deploy emission ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/emission -pkgpath gno.land/r/gnoswap/v2/emission -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/gnoswap/v2/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/gnoswap/v2/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/gnoswap/v2/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/gnoswap/v2/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-community_pool:
	$(info ************ deploy community_pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/community_pool -pkgpath gno.land/r/gnoswap/v2/community_pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-protocol_fee:
	$(info ************ deploy protocol_fee ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/protocol_fee -pkgpath gno.land/r/gnoswap/v2/protocol_fee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gov-staker:
	$(info ************ deploy gov/staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/staker -pkgpath gno.land/r/gnoswap/v2/gov/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-gov-governance:
	$(info ************ deploy gov/governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov/governance -pkgpath gno.land/r/gnoswap/v2/gov/governance -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

deploy-launchpad:
	$(info ************ deploy launchpad ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/launchpad -pkgpath gno.land/r/gnoswap/v2/launchpad -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

# Register
register-token:
	$(info ************ deploy register_gnodev ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5/register_gnodev -pkgpath gno.land/r/g1er355fkjksqpdtwmhf5penwa82p0rhqxkkyhk5/v2/register_gnodev -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" register
	@echo

# default pool create
pool-create-gns-wugnot-default:
	$(info ************ create default pool (GNS:WUGNOT:0.03%) ************)
	# APPROVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin


	# tick 0 ≈ x1 ≈ 79228162514264337593543950337
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/demo/wugnot" -args "gno.land/r/gnoswap/v2/gns" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

# test pool create
pool-create-bar-baz:
	$(info ************ create pool bar:baz ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/baz" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

pool-create-foo-qux:
	$(info ************ create pool foo:qux ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219 ≈ 79188560314459151373725315960
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/foo" -args "gno.land/r/onbloc/qux" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

mint-gns-gnot:
	$(info ************ mint position(1) to gns:wugnot // gnoswap_admin ************)
	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

	# APPROVE WUGNOT TO POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/position -func Mint -send "20000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-49980" -args "49980" -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

	# Set-Token-Uri
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gnft -func SetTokenURILast -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

stake-token-1:
	$(info ************ stake token 1 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gnft -func Approve -args $(ADDR_STAKER) -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


delegate-1:
	$(info ************ delegate 1_000_000_000 to self // gnoswap_admin ************)
	# APPROVE FIRST
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_GOV_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

	# DELEGATE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func Delegate -args $(ADDR_GSA) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

delegate-2:
	$(info ************ delegate 1_500_000_000 to lp_01 // gnoswap_admin ************)
	# APPROVE FIRST
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_GOV_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

	# DELEGATE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func Delegate -args $(ADDR_LP01) -args 1500000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

redelegate:
	$(info ************ redelegate 1_000_000_000 from lp_01 to self // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func Redelegate -args $(ADDR_LP01) -args $(ADDR_GSA) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

undelegate:
	$(info ************ undelegate 1_000_000_000 from self // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func Undelegate -args $(ADDR_GSA) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

collect-undelegated:
	$(info ************ collect undelegated // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func CollectUndelegated -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

collect-gov-reward:
	# GRC20 TRANSFER TO PF
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_PROTOCOL_FEE) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo ""

	$(info ************ collect reward // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/staker -func CollectReward -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


propose-text:
	$(info ************ propose text // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func ProposeText -args "title_for_text" -args "desc_for_text" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

cancel-text:
	$(info ************ cancel text // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Cancel -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


propose-community:
	$(info ************ propose community pool spend // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func ProposeCommunityPoolSpend -args "title_for_spend" -args "desc_for_spend" -args $(ADDR_GSA) -args "gno.land/r/gnoswap/v2/gns" -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

vote-community:
	$(info ************ vote community pool spend // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Vote -args 2 -args true -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

execute-community:
	$(info ************ execute community pool spend // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Execute -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


propose-param:
	$(info ************ propose param change // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func ProposeParameterChange -args "title param change" -args "desc param change" -args "2" -args "gno.land/r/gnoswap/v2/gns*EXE*SetAvgBlockTimeInMs*EXE*123*GOV*gno.land/r/gnoswap/v2/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/v2/gns,g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c,905" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

vote-param:
	$(info ************ vote param change // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Vote -args 3 -args true -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

execute-param:
	$(info ************ execute param change // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Execute -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo

gov-reconfigure:
	$(info ************ change governance config // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gov/governance -func Reconfigure -args 123 -args 456 -args 789 -args 1234 -args 5678 -args 9012 -args 3456 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo


## LAUNCHPAD
launchpad-create-project:
	## APPROVE 
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_LAUNCHPAD) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

	## CREATE PROJECT
	$(info ************ create project // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/launchpad -func CreateProject -args "gno.land/r/onbloc/obl" -args $(ADDR_TR01) -args 1000000000 -args "" -args "" -args 10 -args 20 -args 70 -args $(shell echo $$(($(shell date +%s) + 10))) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

launchpad-deposit:
	## APPROVE 
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_LAUNCHPAD) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

	## DEPOSIT TO PROJECT ( tier 30 )
	$(info ************ deposit to project // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/launchpad -func DepositGns -args "gno.land/r/onbloc/obl:69:30" -args 1000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

launchpad-collect-protocol:
	$(info ************ collect protocol fee by projects recipients // tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/launchpad -func CollectProtocolFee -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_tr01

launchpad-collect-reward:
	$(info ************ collect reward bt project id // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/launchpad -func CollectRewardByProjectId -args "gno.land/r/onbloc/obl:69" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin

## TRANSFER FOR QA
ADDR_ROH := g16a7etgm9z2r653ucl36rj0l2yqcxgrz2jyegzx
transfer-roh:
	$(info ************ TO roh account // transfer COIN(ugnot), GRC20(bar, baz, foo, obl, qux, usdc) ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_ROH) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_ROH) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo ""

ADDR_TEST1 := g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
transfer-test1:
	$(info ************ TO test1 account // transfer COIN(ugnot), GRC20(bar, baz, foo, obl, qux, usdc) ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to $(ADDR_TEST1) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_TEST1) -args "1000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin
	@echo ""