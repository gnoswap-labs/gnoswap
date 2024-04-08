ADDR_GSA := g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq
ADD_FCL := g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906
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

NOW := $(shell date +%s)
INCENTIVE_START := $(shell expr $(NOW) + 360) # GIVE ENOUGH TIME TO EXECUTE PREVIOUS TXS
INCENTIVE_END := $(shell expr $(NOW) + 360 + 7776000) # 7776000 SECONDS = 90 DAY


MAKEFILE := $(shell realpath $(firstword $(MAKEFILE_LIST)))

# GNOLAND_RPC_URL ?= localhost:26657
GNOLAND_RPC_URL ?= localhost:36657 # 36657 for gnodev, 26657 for gnoland
CHAINID ?= dev
ROOT_DIR:=$(shell dirname $(MAKEFILE))/../../



.PHONY: deploy-test-tokens
deploy-test-tokens: deploy-foo deploy-bar deploy-baz deploy-qux deploy-obl

.PHONY: deploy-packages
deploy-packages: deploy-uint256 deploy-int256 deploy-package-pool

.PHONY: deploy-common-realms
deploy-common-realms: deploy-consts deploy-common

.PHONY: deploy-base-tokens
deploy-base-tokens: deploy-gns deploy-gnft

.PHONY: deploy-gnoswap-realms
deploy-gnoswap-realms: deploy-gov deploy-pool deploy-position deploy-router deploy-staker

.PHONY: faucet-test-accounts
faucet-test-accounts: faucet-lp01 faucet-lp02 faucet-tr01

# approve-gsa

.PHONY: pool-create
pool-create: pool-create-bar-baz pool-create-baz-qux pool-create-qux-foo pool-create-foo-gns pool-create-gns-wugnot

.PHONY: mint
mint: mint-bar-baz increase-liquidity-position-01 decrease-liquidity-position-01 mint-baz-qux mint-qux-foo mint-foo-gns mint-gns-gnot

# create-external-incentive

.PHONY: stake-token
stake-token: stake-token-1-5 stake-token-6 stake-token-7 stake-token-8 stake-token-9 stake-token-10 mint-and-stake # 11

# set-protocol-fee

.PHONY: swap
swap: swap-exact-in-single-bar-to-baz swap-exact-in-single-baz-to-bar swap-exact-in-multi-foo-to-gns-to-wugnot swap-exact-in-single-foo-to-gns

.PHONY: collect-fee
collect-fee: collect-fee-position-1-5 collect-fee-position-6 collect-fee-position-7 collect-fee-position-8 collect-fee-position-9 collect-fee-position-10 collect-fee-position-11

.PHONY: unstake-token
unstake-token: unstake-token-1-5 unstake-token-6 unstake-token-7 unstake-token-8 unstake-token-9 unstake-token-10 unstake-token-11

.PHONY: all
all: wait send-ugnot deploy-test-tokens deploy-packages deploy-common-realms deploy-base-tokens deploy-gnoswap-realms register-token faucet-test-accounts approve-gsa pool-create mint create-external-incentive stake-token set-protocol-fee swap collect-fee unstake-token


wait:
	$(info ************ [ETC] wait 5 seconds for chain to start ************)
	$(shell sleep 5)
	@echo

# send ugnot to test accounts
send-ugnot:
	$(info ************ send ugnot to test accounts ************)
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # gnoswap admin
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # fee collector
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g1jms5fx2raq4qfkq3502mfh25g54nyl5qeuvz5y -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # internal reward account
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g1yr0dpfgthph7y6mepdx8afuec4q3ga2lg8tjt0 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # gnoswap labs
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g1qf5863trkaq447zr2xdmql83g0twzl37dm9qqt -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # gnoswap lp01
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g1ta0w7j4f586kwqu584z5h5sjurzywz3na7qg0a -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # gnoswap lp02
	@echo "" | gnokey maketx send -send 10000000000ugnot -to g14m6fj3t8005u77ku6zyzazq9vd9hwhl00ppt8j -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" test1 > /dev/null # gnoswap tr01
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

# deploy base tokens
deploy-gns:
	$(info ************ deploy gns ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gns -pkgpath gno.land/r/demo/gns -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-gnft:
	$(info ************ deploy gnft ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/demo/gnft -pkgpath gno.land/r/demo/gnft -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

# deploy packages
deploy-uint256:
	$(info ************ deploy uint256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/uint256 -pkgpath gno.land/p/demo/gnoswap/uint256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-int256:
	$(info ************ deploy int256 ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/int256 -pkgpath gno.land/p/demo/gnoswap/int256 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-package-pool:
	$(info ************ deploy package pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/p/demo/gnoswap/pool -pkgpath gno.land/p/demo/gnoswap/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

# deploy common realms
deploy-consts:
	$(info ************ deploy consts ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/consts -pkgpath gno.land/r/gnoswap/consts -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-common:
	$(info ************ deploy common ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/_deploy/r/gnoswap/common -pkgpath gno.land/r/gnoswap/common -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

# deploy gnoswap realms
deploy-gov:
	$(info ************ deploy gov ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/gov -pkgpath gno.land/r/demo/gov -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-pool:
	$(info ************ deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/pool -pkgpath gno.land/r/demo/pool -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-position:
	$(info ************ deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/position -pkgpath gno.land/r/demo/position -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-router:
	$(info ************ deploy router ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/router -pkgpath gno.land/r/demo/router -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

deploy-staker:
	$(info ************ deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/staker -pkgpath gno.land/r/demo/staker -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

# Register // ONLY FOR TESTING
register-token:
	$(info ************ deploy register_gnodev ************)
	@echo "" | gnokey maketx addpkg -pkgdir $(ROOT_DIR)/__local/grc20_tokens/register_gnodev -pkgpath gno.land/r/demo/register_gnodev -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_admin > /dev/null
	@echo

# FAUCET
faucet-lp01:
	$(info ************ facuet lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

faucet-lp02:
	$(info ************ facuet lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

faucet-tr01:
	$(info ************ facuet tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Faucet -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo


approve-gsa:
	$(info ************ approve gsa ************)
	# approve pool creation fee ( to pool )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo


pool-create-bar-baz:
	$(info ************ create pool bar:baz ************)
	# tick -10 ≈ x0.99900054978007157835406815138412639498710632324219
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	# tick +10 ≈ x1.00100045012002092370551054045790806412696838378906
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 500 -args 79267784519130042428790663799 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	# tick 46055 ≈ x100.00995593181238518809550441801548004150390625000000
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 3000 -args 792321063670230269303669868814 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-baz-qux:
	$(info ************ create pool baz:qux ************)
	# tick 23028 ≈ x10.00099779659037757539863378042355179786682128906250
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 500 -args 250553947533412109193337304115 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-qux-foo:
	$(info ************ create pool qux:foo ************)
	# tick 6932 ≈ x2.00003632383094753777186269871890544891357421875000
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/qux" -args "gno.land/r/demo/foo" -args 500 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-foo-gns:
	$(info ************ create pool foo:gns ************)
	# tick 6932 ≈ x2.00003632383094753777186269871890544891357421875000
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 500 -args 112046559425783515914356180039 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

pool-create-gns-wugnot:
	$(info ************ create pool gns:wugnot ************)
	# tick 0 = x1
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/gns" -args "gno.land/r/demo/wugnot" -args 500 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func CreatePool -args "gno.land/r/demo/gns" -args "gnot" -args 100 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo


mint-bar-baz:
	$(info ************ mint positions(1~5) to bar:baz // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-20" -args 0 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args 0 -args 10 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-30" -args "-20" -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 500 -args 0 -args 20 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 3000 -args 36060 -args 56040 -args 100 -args 100 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo


mint-baz-qux:
	$(info ************ mint position(6) to baz:qux // gnoswap_lp02 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/baz" -args "gno.land/r/demo/qux" -args 500 -args 13030 -args 33030 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo


mint-qux-foo:
	$(info ************ mint position(7) to qux:foo // gnoswap_lp01 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/qux" -args "gno.land/r/demo/foo" -args 500 -args 5930 -args 7930 -args 20000000 -args 20000000 -args 0 -args 0 -args $(TX_EXPIRE) -args $(ADDR_LP01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

mint-foo-gns:
	$(info ************ mint position(8) to foo:gns // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 500 -args 5930 -args 7930 -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-gns-gnot:
	$(info ************ mint position(9~10) to gns:wugnot // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# APPROVE WUGNOT TO POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POSITION) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null


	# THEN MINT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -send "20000000ugnot" -args "gno.land/r/demo/gns" -args "gnot" -args 500 -args "-50000" -args "50000" -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func Mint -send "20000000ugnot" -args "gno.land/r/demo/gns" -args "gnot" -args 100 -args "-50000" -args "50000" -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_GSA) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

increase-liquidity-position-01:
	$(info ************ increase position(1) liquidity // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func IncreaseLiquidity  -args 1 -args 20000000 -args 20000000 -args 1 -args 1 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

decrease-liquidity-position-01: # need more gas
	$(info ************ decrease position(1) liquidity // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/position -func DecreaseLiquidity -args 1 -args 10 -args 0 -args 0 -args $(TX_EXPIRE) -args "false" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 20000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

create-external-incentive:
	$(info ************ create external incentive // gnoswap_admin ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/obl -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

	# THEN CREATE EXTERNAL INCENTIVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func CreateExternalIncentive -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "gno.land/r/demo/obl" -args 100000000000000 -args $(INCENTIVE_START) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo


stake-token-1-5:
	$(info ************ stake token 1~5 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

stake-token-6:
	$(info ************ stake token 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

stake-token-7:
	$(info ************ stake token 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

stake-token-8:
	$(info ************ stake token 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-9:
	$(info ************ stake token 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

stake-token-10:
	$(info ************ stake token 10 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gnft -func Approve -args $(ADDR_STAKER) -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func StakeToken -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

mint-and-stake:
	$(info ************ mint and stake(11), to same position with lpTokenId 1 // gnoswap_lp02 ************)

	# APPROVE FISRT
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func MintAndStake -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 100 -args "-200" -args "190" -args 50000000 -args 50000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

set-protocol-fee:
	$(info ************ set (pool) protocol fee // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/pool -func SetFeeProtocol -args 6 -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

swap-exact-in-single-bar-to-baz:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap bar -> baz, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/bar" -args "gno.land/r/demo/baz" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/bar:gno.land/r/demo/baz:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector
	@echo

swap-exact-in-single-baz-to-bar:
	$(info ************ swap baz -> bar, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/bar -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/baz" -args "gno.land/r/demo/bar" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/baz:gno.land/r/demo/bar:100" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

swap-exact-in-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

swap-exact-out-single-foo-to-gns:
	$(info ************ swap foo -> gns, exact_out // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/gns -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/gns" -args "-50000" -args "EXACT_OUT" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500" -args "100" -args "50000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

swap-exact-in-multi-foo-to-gns-to-wugnot:
	@$(MAKE) -f $(MAKEFILE) print-fee-collector

	$(info ************ swap foo -> gns ->wugnot, exact_in // gnoswap_tr01 ************)

	# approve INPUT TOKEN to POOL
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	# approve OUTPUT TOKEN to ROUTER ( as 0.15% fee )
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_ROUTER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_tr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/router -func SwapRoute -args "gno.land/r/demo/foo" -args "gno.land/r/demo/wugnot" -args 50000 -args "EXACT_IN" -args "gno.land/r/demo/foo:gno.land/r/demo/gns:500*POOL*gno.land/r/demo/gns:gno.land/r/demo/wugnot:500" -args "100" -args "1" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 10000000 -memo "" gnoswap_tr01 > /dev/null
	@echo

	@$(MAKE) -f $(MAKEFILE) print-fee-collector

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
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 4 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 5 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

unstake-token-6:
	$(info ************ unstake token 6 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 6 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo

unstake-token-7:
	$(info ************ unstake token 7 // gnoswap_lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 7 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp01 > /dev/null
	@echo

unstake-token-8:
	$(info ************ unstake token 8 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 8 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-9:
	$(info ************ unstake token 9 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 9 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-10:
	$(info ************ unstake token 10 // gnoswap_admin ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 10 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo

unstake-token-11:
	$(info ************ unstake token 11 // gnoswap_lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/staker -func UnstakeToken -args 11 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_lp02 > /dev/null
	@echo




print-fee-collector:
	$(info ************ print fee collector balance ************)
	@printf "Bar "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/bar\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Baz "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/baz\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Qux "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/qux\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Foo "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/foo\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Gns "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/gns\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Obl "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/obl\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo

	@printf "Wugnot "
	@curl -s 'localhost:36657/abci_query?path="vm/qeval"&data="gno.land/r/demo/wugnot\nBalanceOf(\"g18sp3hq6zqfxw88ffgz773gvaqgzjhxy62l9906\")"' | jq -r '.result.response.ResponseBase.Data' | base64 -d
	@echo
	@echo
