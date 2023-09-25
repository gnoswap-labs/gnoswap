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

TX_EXPIRE := 9999999999

NOW := $(shell date +%s)


MAKEFILE := phase_v1.mk


.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'

.PHONY: all
all: deploy faucet approve pool-setup position-mint pool-swap

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-gnos deploy-gnft deploy-gov deploy-pool deploy-position

.PHONY: faucet
faucet: faucet-lp01 faucet-lp02 faucet-tr01

.PHONY: approve
approve: approve-lp01 approve-lp02 approve-tr01

.PHONY: pool-setup
pool-setup: pool-init pool-create

.PHONY: position-mint
position-mint: mint-01  mint-02

.PHONY: pool-swap-zero-to-one
pool-swap: set-protocol-fee swap-01-200000 collect-protocol-fee

.PHONY: pool-swap-one-to-zero
pool-swap: swap-10-300000 collect-protocol-fee

# Deploy Tokens
# [GRC20] FOO, BAR: Token Pair for Pool
# [GRC20] GNOS: Default Staking Reward
# [GRC20] OBL: External Staking Reward
# [GRC721] GNFT: LP Token
deploy-foo:
	$(info ************ [FOO] deploy token0 ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../_setup/foo -pkgpath gno.land/r/foo -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-bar:
	$(info ************ [BAR] deploy token1 ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../_setup/bar -pkgpath gno.land/r/bar -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gnos:
	$(info ************ [GNOS] deploy staking reward ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../_setup/gnos -pkgpath gno.land/r/gnos -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gnft:
	$(info ************ [GNFT] deploy lp token ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../_setup/gnft -pkgpath gno.land/r/gnft -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Deploy Contracts
deploy-gov:
	$(info ************ [GOV] deploy governance ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../gov -pkgpath gno.land/r/gov -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-pool:
	$(info ************ [POOL] deploy pool ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../pool -pkgpath gno.land/r/pool -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-position:
	$(info ************ [POSITION] deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../position -pkgpath gno.land/r/position -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


# Facuet Tokens
faucet-lp01:
	$(info ************ [FAUCET] foo & bar to lp01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

faucet-lp02:
	$(info ************ [FAUCET] foo & bar to lp02 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

faucet-tr01:
	$(info ************ [FAUCET] foo & bar to tr01 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func FaucetL -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo


# Approve Tokens
approve-lp01:
	$(info ************ [APPROVE] foo & bar from lp01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_LP01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_LP01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo

approve-lp02:
	$(info ************ [APPROVE] foo & bar from lp02 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_LP02) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_LP02) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@echo

approve-tr01:
	$(info ************ [APPROVE] foo & bar from tr01 to pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_POOL) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/foo -func Approve -args $(ADDR_TR01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/bar -func Approve -args $(ADDR_TR01) -args 50000000000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@echo


# Pool
pool-init:
	$(info ************ [POOL] init pool ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func InitManual -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

pool-create:
	$(info ************ [POOL] create pool ( foo & bar & 500 ) ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CreatePool -args foo -args bar -args 500 -args 130621891405341611593710811006 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


# Position
mint-01:
	$(info ************ [POSITION] mint foo & bar // tick range 9000 ~ 11000 // by lp01   ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args foo -args bar -args 500 -args 9000 -args 11000 -args 1000000 -args 1000000 -args 1 -args 1 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


mint-02:
	$(info ************ [POSITION] mint foo & bar // tick range 9100 ~ 12000 // by lp02   ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args foo -args bar -args 500 -args 9100 -args 12000 -args 2000000 -args 2000000 -args 1 -args 1 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp02 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo


# Pool // Swap
set-protocol-fee:
	$(info ************ [POOL] Set Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func SetFeeProtocol -args 6 -args 8 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

swap-01-200000:
	$(info ************ [POOL] swap 200000token0 > token1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args true -args 200000 -args 4295128740 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

swap-10-300000:
	$(info ************ [POOL] swap 300000token1 > token0 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func Swap -args foo -args bar -args 500 -args $(ADDR_TR01) -args false -args 300000 -args 1461446703485210103287273052203988822378723970341 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" tr01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

collect-protocol-fee:
	$(info ************ [POOL] Collect Protocol Fee ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/pool -func CollectProtocol -args foo -args bar -args 500 -args $(ADDR_GSA) -args 100000 -args 100000 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-gsa-balance
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

## ETC
# gno time.Now returns last block time, not actual time
# so to skip time, we need new block
# currently test3 creates new block every 5 seconds
skip-time:
	$(info > SKIP 3 BLOCKS)
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

print-all-balance:
	$(info > BALANCES)
	@echo pool_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo pool_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_POOL)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo lp01_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo lp01_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo lp02_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_LP02)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo lp02_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_LP02)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
	@echo tr01_token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo tr01_token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_TR01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-lp01-reward:
	$(info ************ [REWARD] lp01 ************)
	@echo GNOS: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnos\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo OBL: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/obl\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-lp02-reward:
	$(info ************ [REWARD] lp02 ************)
	@echo GNOS: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnos\nBalanceOf(\"$(ADDR_LP02)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo OBL: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/obl\nBalanceOf(\"$(ADDR_LP02)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

print-gsa-balance:
	$(info ************ [BALANCE] Gnoswap Admin ************)
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/foo\nBalanceOf(\"$(ADDR_GSA)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo Token1: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/bar\nBalanceOf(\"$(ADDR_GSA)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo