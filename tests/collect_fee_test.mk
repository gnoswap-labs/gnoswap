include _info.mk

# Paths for contracts
GNS_PATH := gno.land/r/gnoswap/gns
WUGNOT_PATH := gno.land/r/demo/wugnot
ROUTER_PATH := gno.land/r/gnoswap/v1/router
POSITION_PATH := gno.land/r/gnoswap/v1/position
POOL_PATH := gno.land/r/gnoswap/v1/pool
PROTOCOL_FEE_PATH := gno.land/r/gnoswap/v1/protocol_fee

ADDR_TEST_ADMIN := g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c
ADDR_TEST_USER1 := g16a7etgm9z2r653ucl36rj0l2yqcxgrz2jyegzx

.PHONY: test-wugnot-fee-collection
test-wugnot-fee-collection: setup-test-accounts create-test-pool mint-test-position execute-swaps collect-fees

.PHONY: setup-test-accounts
setup-test-accounts:
	$(info ************ Step 1: Setting up test accounts ************)
	# Send ugnot to test accounts
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_TEST_ADMIN) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx send -send 500000000ugnot -to $(ADDR_TEST_USER1) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" test1
	@echo "" | gnokey maketx send -send 500000000ugnot -to $(ADDR_TEST_ADMIN) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 100000000 -memo "" test1

	# Transfer GNS to test accounts
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Transfer -args $(ADDR_TEST_ADMIN) -args 1000000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "transfer 1_000_000_000 GNS to $(ADDR_GNOSWAP)" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Transfer -args $(ADDR_TEST_USER1) -args 100000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Transfer -args $(ADDR_TEST_ADMIN) -args 100000000 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo

.PHONY: create-test-pool
create-test-pool:
	$(info ************ Step 2: Creating GNS/WUGNOT pool (3000 fee tier) ************)
	# Approve GNS for pool creation fee (100 GNS)
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Approve -args $(ADDR_POOL) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Create pool
	@echo "" | gnokey maketx call -pkgpath $(POOL_PATH) -func CreatePool -args $(GNS_PATH) -args $(WUGNOT_PATH) -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin || true
	@echo

.PHONY: mint-test-position
mint-test-position:
	$(info ************ Step 3: Minting position with native GNOT ************)
	# Wrap some GNOT to WUGNOT first
	@echo "" | gnokey maketx call -pkgpath $(WUGNOT_PATH) -func Deposit -send "100000000ugnot" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Approve GNS for pool contract (Pool needs to transfer GNS from user)
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Approve -args $(ADDR_POOL) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Approve WUGNOT for pool contract
	@echo "" | gnokey maketx call -pkgpath $(WUGNOT_PATH) -func Approve -args $(ADDR_POOL) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Approve WUGNOT to POSITION, to get refund wugnot left after wrap -> mint
	@echo "" | gnokey maketx call -pkgpath $(WUGNOT_PATH) -func Approve -args $(ADDR_POSITION) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Mint position with native GNOT (will be wrapped to WUGNOT internally)
	@echo "" | gnokey maketx call -pkgpath $(POSITION_PATH) -func Mint -send "50000000ugnot" -args $(GNS_PATH) -args "gnot" -args 3000 -args "-887220" -args "887220" -args 50000000 -args 50000000 -args 1 -args 1 -args $(TX_EXPIRE) -args $(ADDR_ADMIN) -args $(ADDR_ADMIN) -args "" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo

.PHONY: execute-swaps
execute-swaps:
	$(info ************ Step 4: Executing swaps to generate fees ************)
	# Approve INPUT TOKEN to POOL for swap
	@echo "" | gnokey maketx call -pkgpath $(GNS_PATH) -func Approve -args $(ADDR_POOL) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Approve OUTPUT TOKEN to ROUTER (as 0.15% fee)
	@echo "" | gnokey maketx call -pkgpath $(WUGNOT_PATH) -func Approve -args $(ADDR_ROUTER) -args $(MAX_APPROVE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Swap 1: GNS -> WUGNOT (exact in)
	@echo "" | gnokey maketx call -pkgpath $(ROUTER_PATH) -func ExactInSwapRoute -args $(GNS_PATH) -args $(WUGNOT_PATH) -args 1000000 -args "$(GNS_PATH):$(WUGNOT_PATH):3000" -args "100" -args "0" -args $(TX_EXPIRE) -args "" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Swap 2: WUGNOT -> GNS (exact in with native input)
	@echo "" | gnokey maketx call -pkgpath $(ROUTER_PATH) -func ExactInSwapRoute -send "1000000ugnot" -args "gnot" -args $(GNS_PATH) -args 1000000 -args "$(WUGNOT_PATH):$(GNS_PATH):3000" -args "100" -args "0" -args $(TX_EXPIRE) -args "" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin

	# Swap 3: Another GNS -> WUGNOT swap to accumulate more fees
	@echo "" | gnokey maketx call -pkgpath $(ROUTER_PATH) -func ExactInSwapRoute -args $(GNS_PATH) -args $(WUGNOT_PATH) -args 500000 -args "$(GNS_PATH):$(WUGNOT_PATH):3000" -args "100" -args "0" -args $(TX_EXPIRE) -args "" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo

.PHONY: collect-fees
collect-fees:
	$(info ************ Step 5: Collecting fees from position ************)
	# Collect fees with unwrap (should receive native GNOT instead of WUGNOT)
	@echo "" | gnokey maketx call -pkgpath $(POSITION_PATH) -func CollectFee -args 1 -args true -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 100000000ugnot -gas-wanted 1000000000 -memo "" gnoswap_admin
	@echo
