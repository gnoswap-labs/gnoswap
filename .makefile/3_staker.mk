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
INCENTIVE_START := $(shell expr $(NOW) + 60)
INCENTIVE_END := $(shell expr $(NOW) + 100)


MAKEFILE := 3_staker.mk

.PHONY: help
help:
	@echo "Available make commands:"
	@cat $(MAKEFILE) | grep '^[a-z][^:]*:' | cut -d: -f1 | sort | sed 's/^/  /'

.PHONY: all
all: gnot deploy faucet approve pool mint staker

.PHONY: gnot
gnot: gnot-gsa gnot-lp01 gnot-lp02 gnot-tr01

.PHONY: deploy
deploy: deploy-foo deploy-bar deploy-pool deploy-gnft deploy-position deploy-gnos deploy-staker

.PHONY: faucet
faucet: faucet-lp01 faucet-lp02 faucet-tr01

.PHONY: approve
approve: approve-lp01 approve-lp02 approve-tr01

.PHONY: pool
pool: pool-init pool-create

.PHONY: mint
mint: mint-01 own-01 approve-01

.PHONY: staker
staker: create-incentive stake-token claim-reward unstake-token withdraw-token 

## GNOT
gnot-gsa:
	$(info ************ [GNOT] transfer 100gnot to gsa ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_GSA) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

gnot-lp01:
	$(info ************ [GNOT] transfer 100gnot to lp01 ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_LP01) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

gnot-lp02:
	$(info ************ [GNOT] transfer 100gnot to lp02 ************)
	@echo "" | gnokey maketx send -send 100000000ugnot -to $(ADDR_LP02) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
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

deploy-gnft:
	$(info ************ [DEPLOY] deploy grc721 gnft (lp token) ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../.base/gnft -pkgpath gno.land/r/gnft -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-position:
	$(info ************ [DEPLOY] deploy position ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../position -pkgpath gno.land/r/position -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-gnos:
	$(info ************ [DEPLOY] deploy grc20 gnos (governance token) ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../.base/gnos -pkgpath gno.land/r/gnos -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo

deploy-staker:
	$(info ************ [DEPLOY] deploy staker ************)
	@echo "" | gnokey maketx addpkg -pkgdir ../staker -pkgpath gno.land/r/staker -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo


## FAUCET
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


## APPROVE
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


## MINT
mint-01:
	$(info ************ [MINT] foo & bar & 500 & 9000 ~ 11000 & 1000 & 1000 & 1 & 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/position -func Mint -args foo -args bar -args 500 -args 9000 -args 11000 -args 1000 -args 1000 -args 1 -args 1 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) print-all-balance
	@echo

own-01:
	$(info ************ [MINT] owner of nft tokenId 1 (should be $(ADDR_LP01)) ************)
	@echo NFT tokenId 1 Owner: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnft\nOwnerOf(\"1\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

approve-01:
	$(info ************ [Approve] approve staker contract to spend tokenId 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnft -func Approve -args $(ADDR_STAKER) -args "1" -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null

	

## STAKER
create-incentive:
	$(info ************ [STAKER] create ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func CreateIncentive -args $(INCENTIVE_START) -args $(INCENTIVE_END) -args $(ADDR_GSA) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gsa > /dev/null
	@echo

stake-token:
	$(info ************ [STAKER] stake nft 1 ************)
	@$(MAKE) -f $(MAKEFILE) skip-time
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func StakeToken -args $(INCENTIVE_START) -args $(INCENTIVE_END) -args $(ADDR_GSA) -args 1 -args 3 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo NFT tokenId 1 Owner: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnft\nOwnerOf(\"1\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo

claim-reward:
	$(info ************ [STAKER] claim reward ************)
	@$(MAKE) -f $(MAKEFILE) print-lp01-reward
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func ClaimReward -args $(INCENTIVE_START) -args $(INCENTIVE_END) -args $(ADDR_GSA) -args 1 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo NFT tokenId 1 Owner: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnft\nOwnerOf(\"1\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@$(MAKE) -f $(MAKEFILE) print-lp01-reward
	@echo

unstake-token:
	$(info ************ [STAKER] unstake nft 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func UnstakeToken -args $(INCENTIVE_START) -args $(INCENTIVE_END) -args $(ADDR_GSA) -args 1 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@$(MAKE) -f $(MAKEFILE) skip-time
	@$(MAKE) -f $(MAKEFILE) skip-time
	@echo

withdraw-token:
	$(info ************ [STAKER] withdraw nft 1 ************)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/staker -func WithdrawToken -args 1 -args $(ADDR_LP01) -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" lp01 > /dev/null
	@echo
	@$(MAKE) -f $(MAKEFILE) own-01
	@echo


## ETC
# gno time.Now returns last block time, not actual time
# so to skip time, we need new block
skip-time:
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx send -send 1ugnot -to g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5 -insecure-password-stdin=true -remote localhost:26657 -broadcast=true -chainid dev -gas-fee 1ugnot -gas-wanted 9000000 -memo "" test1 > /dev/null

print-all-balance:
	$(info ㄴ BALANCES)
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
	@echo Token0: $(shell curl -s 'http://localhost:26657/abci_query?path=%22vm/qeval%22&data=%22gno.land/r/gnos\nBalanceOf(\"$(ADDR_LP01)\")%22' | jq -r ".result.response.ResponseBase.Data" | base64 -d | awk -F'[ ()]' '{print $$2}')
	@echo
