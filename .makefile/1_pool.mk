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

MAKEFILE := 1_pool.mk

.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'


.PHONY: all
all: gnot deploy faucet approve pool basic swap-without-protocol-fee swap-wit-protocol-fee

.PHONY: gnot
gnot: gnot-gsa gnot-lp01 gnot-tr01

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-pool

.PHONY: faucet
faucet: faucet-lp01 faucet-tr01

.PHONY: approve
approve: approve-lp01 approve-tr01

.PHONY: pool
pool: pool-init pool-create

.PHONY: basic
basic: basic-mint basic-burn basic-collect

.PHONY: swap-without-protocol-fee
swap-without-protocol-fee: swap-setup swap-without-protocol-fee-0-1-10000 swap-without-protocol-fee-0-1-5000 swap-without-protocol-fee-0-1-1000 swap-without-protocol-fee-1-0-16000

.PHONY: swap-wit-protocol-fee
swap-wit-protocol-fee: set-protocol-fee swap-with-protocol-fee-0-1-200000 swap-with-protocol-fee-1-0-200000 collect-protocol-fee burn-collect-after-swap

## GNOT
gnot-gsa:
	$(info ************ [GNOT] transfer 100gnot to Gnoswap Admin ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_GSA) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

gnot-lp01:
	$(info ************ [GNOT] transfer 100gnot to lp01 ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_LP01) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

gnot-tr01:
	$(info ************ [GNOT] transfer 100gnot to tr01 ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_TR01) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


## DEPLOY
deploy-foo:
	$(info ************ [DEPLOY] deploy grc20 foo (token0) ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../.base/foo -pkgpath gno.land/r/foo -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-bar:
	$(info ************ [DEPLOY] deploy grc20 bar (token1) ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../.base/bar -pkgpath gno.land/r/bar -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-pool:
	$(info ************ [DEPLOY] deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../pool -pkgpath gno.land/r/pool -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


## FAUCET
faucet-lp01:
	$(info ************ [FAUCET] foo & bar to lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo


faucet-tr01:
	$(info ************ [FAUCET] foo & bar to tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo


## APPROVE
approve-lp01:
	$(info ************ [APPROVE] foo & bar from lp01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
# SELF APPROVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_LP01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_LP01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

approve-tr01:
	$(info ************ [APPROVE] foo & bar from tr01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
# SELF APPROVE
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_TR01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_TR01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo


## POOL
pool-init: 
	$(info ************ [POOL] init ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Init -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

pool-create: 
	$(info ************ [POOL] create ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args foo -args bar -args 500 -args 130621891405341611593710811006 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


## BASIC
basic-mint:
	$(info ************ [BASIC] Mint 9000 ~ 11000 // 1000 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Mint -args foo -args bar -args 500 -args $(ADDR_LP01) -args 9000 -args 11000 -args 1000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

basic-burn:
	$(info ************ [BASIC] Burn 9000 ~ 11000 // 1000 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Burn -args foo -args bar -args 500 -args 9000 -args 11000 -args 1000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

basic-collect:
	$(info ************ [BASIC] Collect 9000 ~ 11000 // 1000 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Collect -args foo -args bar -args 500 -args $(ADDR_LP01) -args 9000 -args 11000 -args 50000000 -args 50000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


## SWAP WITHOUT PROTOCOL FEE
swap-setup:
	$(info ************ [SWAP] Setup - Mint 9000 ~ 11000 // 50000000 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Mint -args foo -args bar -args 500 -args $(ADDR_LP01) -args 9000 -args 11000 -args 50000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-without-protocol-fee-0-1-10000:
	$(info ************ [SWAP] (#1) 10000token0 > token1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args true -args 10000 -args 4295128740 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-without-protocol-fee-0-1-5000:
	$(info ************ [SWAP] (#2) 5000token0 > token1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args true -args 5000 -args 4295128740 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-without-protocol-fee-0-1-1000:
	$(info ************ [SWAP] (#3) 1000token0 > token1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args true -args 1000 -args 4295128740 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-without-protocol-fee-1-0-16000:
	$(info ************ [SWAP] (#4) 16000token1 > token0 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args false -args 16000 -args 1461446703485210103287273052203988822378723970341 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


# SWAP WITH PROTOCOL FEE
set-protocol-fee:
	$(info ************ [SWAP] Set Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func SetFeeProtocol -args 6 -args 8 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-gsa-balance
	@echo

swap-with-protocol-fee-0-1-200000:
	$(info ************ [SWAP] (#5) 200000token0 > token1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args true -args 200000 -args 4295128740 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-with-protocol-fee-1-0-200000:
	$(info ************ [SWAP] (#6) 200000token1 > token0 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args false -args 200000 -args 1461446703485210103287273052203988822378723970341 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

collect-protocol-fee:
	$(info ************ [SWAP] Collect Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CollectProtocol -args foo -args bar -args 500 -args $(ADDR_GSA) -args 100000 -args 100000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-gsa-balance
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

burn-collect-after-swap:
	$(info ************ [SWAP] Burn Collect After Swap ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Burn -args foo -args bar -args 500 -args 9000 -args 11000 -args 50000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Collect -args foo -args bar -args 500 -args $(ADDR_LP01) -args 9000 -args 11000 -args 50000000 -args 50000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


## ETC
print-all-balance:
	$(info > ALL BALANCES)
	@echo pool_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo pool_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo lp01_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo lp01_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo tr01_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo tr01_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo

print-pool-balance:
	$(info ************ [BALANCE] pool ************)
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo Token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-gsa-balance:
	$(info ************ [BALANCE] Gnoswap Admin ************)
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_GSA)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo Token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_GSA)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-lp01-balance:
	$(info ************ [BALANCE] lp01 ************)
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo Token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-tr01-balance:
	$(info ************ [BALANCE] tr01 ************)
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo Token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo