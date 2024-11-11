

include init.mk # run initialization 


MAX_UINT64 := 18446744073709551615
TX_EXPIRE := 9999999999

TOMORROW_MIDNIGHT := $(shell (gdate -ud 'tomorrow 00:00:00' +%s))
INCENTIVE_END := $(shell expr $(TOMORROW_MIDNIGHT) + 7776000) # 7776000 SECONDS = 90 DAY

# jar royal raise broken expect slight actress hunt pony swallow bird subway whisper this alone romance assume label live issue palm canal priority warrior
# gnokey add addr01 -index 1 -recover
# gnokey add addr02 -index 2 -recover
# gnokey add addr03 -index 3 -recover
# gnokey add addr04 -index 4 -recover
# gnokey add addr05 -index 5 -recover
ADDR_01 := g1y22llljkrtnd3mzxlz83lkl92wtu03cdwespp9
ADDR_02 := g1nkczmtgu0qu6ys9mmznsh2rmwls6s74qf92679
ADDR_03 := g10wqdp77afxlrn5nhx7p2wpmuq9q0v6mpemvazr
ADDR_04 := g1865hx9674689ff268s2wux8tltj3traapgvjyz
ADDR_05 := g1qw7y0kqcqk3jumd48yzpcw7y2jmmqe8xrv063u

# POOL
# gnot:gns:0.3%

# GRC20
# foo, bar, baz, qux, obl, gns, usdc, (+wugnot)

.PHONY: test-init
test-init: test-transfer-grc20 test-pool internal-tier external-incentive mint-and-stake

.PHONY: test-pool
test-pool: approve-creation-fee create-internal-pool create-internal-and-external-pool create-external-pool 

.PHONY: internal-tier
internal-tier: set-pool-tier

.PHONY: external-incentive
external-incentive: create-external-incentive

.PHONY: mint-and-stake
mint-and-stake: wugnot-gns-3000 bar-foo-3000 baz-qux-3000 gns-obl-3000 wugnot-usdc-3000 baz-foo-500 foo-qux-500 gns-foo-500 bar-foo-10000 baz-qux-10000


# 5 pools
.PHONY: create-internal-pool
create-internal-pool: internal-01-foo-bar-3000 internal-02-baz-qux-3000 internal-03-obl-gns-3000 internal-04-usdc-wugnot-3000 # gnot:gns:0.3% is 5th pool

# 3 pools
.PHONY: create-internal-and-external-pool
create-internal-and-external-pool: internal-and-external-01-foo-baz-500 internal-and-external-02-foo-qux-500 internal-and-external-03-foo-gns-500

# 2 pools
.PHONY: create-external-pool
create-external-pool: external-01-foo-bar-10000 external-02-baz-qux-10000


# mint and stake
.PHONY: wugnot-gns-3000
wugnot-gns-3000: addr01-mint-and-stake-to-wugnot-gns-3000 addr02-mint-and-stake-to-wugnot-gns-3000 addr03-mint-and-stake-to-wugnot-gns-3000 addr04-mint-and-stake-to-wugnot-gns-3000 addr05-mint-and-stake-to-wugnot-gns-3000

.PHONY: bar-foo-3000
bar-foo-3000: addr01-mint-and-stake-to-bar-foo-3000 addr02-mint-and-stake-to-bar-foo-3000 addr03-mint-and-stake-to-bar-foo-3000 addr04-mint-and-stake-to-bar-foo-3000 addr05-mint-and-stake-to-bar-foo-3000

.PHONY: baz-qux-3000
baz-qux-3000: addr01-mint-and-stake-to-baz-qux-3000 addr02-mint-and-stake-to-baz-qux-3000 addr03-mint-and-stake-to-baz-qux-3000 addr04-mint-and-stake-to-baz-qux-3000 addr05-mint-and-stake-to-baz-qux-3000

.PHONY: gns-obl-3000
gns-obl-3000: addr01-mint-and-stake-to-gns-obl-3000 addr02-mint-and-stake-to-gns-obl-3000 addr03-mint-and-stake-to-gns-obl-3000 addr04-mint-and-stake-to-gns-obl-3000 addr05-mint-and-stake-to-gns-obl-3000

.PHONY: wugnot-usdc-3000
wugnot-usdc-3000: addr01-mint-and-stake-to-wugnot-usdc-3000 addr02-mint-and-stake-to-wugnot-usdc-3000 addr03-mint-and-stake-to-wugnot-usdc-3000 addr04-mint-and-stake-to-wugnot-usdc-3000 addr05-mint-and-stake-to-wugnot-usdc-3000

.PHONY: baz-foo-500
baz-foo-500: addr01-mint-and-stake-to-baz-foo-500 addr02-mint-and-stake-to-baz-foo-500 addr03-mint-and-stake-to-baz-foo-500 addr04-mint-and-stake-to-baz-foo-500 addr05-mint-and-stake-to-baz-foo-500

.PHONY: foo-qux-500
foo-qux-500: addr01-mint-and-stake-to-foo-qux-500 addr02-mint-and-stake-to-foo-qux-500 addr03-mint-and-stake-to-foo-qux-500 addr04-mint-and-stake-to-foo-qux-500 addr05-mint-and-stake-to-foo-qux-500

.PHONY: gns-foo-500
gns-foo-500: addr01-mint-and-stake-to-gns-foo-500 addr02-mint-and-stake-to-gns-foo-500 addr03-mint-and-stake-to-gns-foo-500 addr04-mint-and-stake-to-gns-foo-500 addr05-mint-and-stake-to-gns-foo-500

.PHONY: bar-foo-10000
bar-foo-10000: addr01-mint-and-stake-to-bar-foo-10000 addr02-mint-and-stake-to-bar-foo-10000 addr03-mint-and-stake-to-bar-foo-10000 addr04-mint-and-stake-to-bar-foo-10000 addr05-mint-and-stake-to-bar-foo-10000

.PHONY: baz-qux-10000
baz-qux-10000: addr01-mint-and-stake-to-baz-qux-10000 addr02-mint-and-stake-to-baz-qux-10000 addr03-mint-and-stake-to-baz-qux-10000 addr04-mint-and-stake-to-baz-qux-10000 addr05-mint-and-stake-to-baz-qux-10000




test-transfer-grc20:
	$(info ********** test-transfer-grc20 **********)

	# addr01
	@echo "" | gnokey maketx send -send 2000000000ugnot -to $(ADDR_01) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Transfer -args $(ADDR_01) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# addr02
	@echo "" | gnokey maketx send -send 2000000000ugnot -to $(ADDR_02) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Transfer -args $(ADDR_02) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# addr03
	@echo "" | gnokey maketx send -send 2000000000ugnot -to $(ADDR_03) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Transfer -args $(ADDR_03) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# addr04
	@echo "" | gnokey maketx send -send 2000000000ugnot -to $(ADDR_04) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Transfer -args $(ADDR_04) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# addr05
	@echo "" | gnokey maketx send -send 2000000000ugnot -to $(ADDR_05) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" test1 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Transfer -args $(ADDR_05) -args "2000000000" -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


approve-creation-fee:	
	$(info ********** approve-creation-fee **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-01-foo-bar-3000:
	$(info ********** internal-01-foo-bar-3000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-02-baz-qux-3000:
	$(info ********** internal-02-baz-qux-3000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-03-obl-gns-3000:
	$(info ********** internal-03-obl-gns-3000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-04-usdc-wugnot-3000:
	$(info ********** internal-04-usdc-wugnot-3000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/demo/wugnot" -args "gno.land/r/onbloc/usdc" -args 3000 -args 79228162514264337593543950337 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


internal-and-external-01-foo-baz-500:
	$(info ********** internal-and-external-01-foo-baz-500 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args 79198956514273546913544869736 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-and-external-02-foo-qux-500:
	$(info ********** internal-and-external-02-foo-qux-500 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/foo" -args "gno.land/r/onbloc/qux" -args 500 -args 79198956514273546913544869736 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

internal-and-external-03-foo-gns-500:
	$(info ********** internal-and-external-03-foo-gns-500 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args 79198956514273546913544869736 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

external-01-foo-bar-10000:
	$(info ********** external-01-foo-bar-10000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo

external-02-baz-qux-10000:
	$(info ********** external-02-baz-qux-10000 **********)
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/pool -func CreatePool -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args 79188560314459151373725315960 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


set-pool-tier:
	$(info ********** set-pool-tier **********)
	# gns:gnot:0.3% is pool tier 1
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000" -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:3000" -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/gnoswap/v2/gns:gno.land/r/onbloc/obl:3000" -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/demo/wugnot:gno.land/r/onbloc/usdc:3000" -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500" -args 3 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500" -args 1 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func SetPoolTierByAdmin -args "gno.land/r/gnoswap/v2/gns:gno.land/r/onbloc/foo:500" -args 2 -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo
	

create-external-incentive:
	$(info ********** create-external-incentive **********)
	# approve deposit gns
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null

	# for pool with internal + external
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func CreateExternalIncentive -args "gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500" -args "gno.land/r/onbloc/foo" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func CreateExternalIncentive -args "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:500" -args "gno.land/r/onbloc/qux" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func CreateExternalIncentive -args "gno.land/r/gnoswap/v2/gns:gno.land/r/onbloc/foo:500" -args "gno.land/r/gnoswap/v2/gns" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	# for pool only external
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func CreateExternalIncentive -args "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:10000" -args "gno.land/r/onbloc/foo" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_STAKER) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 9000000 -memo "" gnoswap_admin > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func CreateExternalIncentive -args "gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000" -args "gno.land/r/onbloc/baz" -args 1000000000 -args $(TOMORROW_MIDNIGHT) -args $(INCENTIVE_END) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" gnoswap_admin > /dev/null
	@echo


addr01-mint-and-stake-to-wugnot-gns-3000:
	$(info ********** addr01-mint-and-stake-to-wugnot-gns-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-wugnot-gns-3000:
	$(info ********** addr02-mint-and-stake-to-wugnot-gns-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-wugnot-gns-3000:
	$(info ********** addr03-mint-and-stake-to-wugnot-gns-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-wugnot-gns-3000:
	$(info ********** addr04-mint-and-stake-to-wugnot-gns-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-wugnot-gns-3000:
	$(info ********** addr05-mint-and-stake-to-wugnot-gns-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/gnoswap/v2/gns" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-bar-foo-3000:
	$(info ********** addr01-mint-and-stake-to-bar-foo-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-bar-foo-3000:
	$(info ********** addr02-mint-and-stake-to-bar-foo-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-bar-foo-3000:
	$(info ********** addr03-mint-and-stake-to-bar-foo-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-bar-foo-3000:
	$(info ********** addr04-mint-and-stake-to-bar-foo-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-bar-foo-3000:
	$(info ********** addr05-mint-and-stake-to-bar-foo-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-baz-qux-3000:
	$(info ********** addr01-mint-and-stake-to-baz-qux-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-baz-qux-3000:
	$(info ********** addr02-mint-and-stake-to-baz-qux-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-baz-qux-3000:
	$(info ********** addr03-mint-and-stake-to-baz-qux-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-baz-qux-3000:
	$(info ********** addr04-mint-and-stake-to-baz-qux-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-baz-qux-3000:
	$(info ********** addr05-mint-and-stake-to-baz-qux-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-gns-obl-3000:
	$(info ********** addr01-mint-and-stake-to-gns-obl-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-gns-obl-3000:
	$(info ********** addr02-mint-and-stake-to-gns-obl-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-gns-obl-3000:
	$(info ********** addr03-mint-and-stake-to-gns-obl-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-gns-obl-3000:
	$(info ********** addr04-mint-and-stake-to-gns-obl-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-gns-obl-3000:
	$(info ********** addr05-mint-and-stake-to-gns-obl-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/obl -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/obl" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-wugnot-usdc-3000:
	$(info ********** addr01-mint-and-stake-to-wugnot-usdc-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-wugnot-usdc-3000:
	$(info ********** addr02-mint-and-stake-to-wugnot-usdc-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-wugnot-usdc-3000:
	$(info ********** addr03-mint-and-stake-to-wugnot-usdc-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-wugnot-usdc-3000:
	$(info ********** addr04-mint-and-stake-to-wugnot-usdc-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-wugnot-usdc-3000:
	$(info ********** addr05-mint-and-stake-to-wugnot-usdc-3000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/demo/wugnot -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/usdc -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -send "100000000ugnot" -args "gno.land/r/onbloc/usdc" -args "gnot" -args 3000 -args "-120" -args "120" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-baz-foo-500:
	$(info ********** addr01-mint-and-stake-to-baz-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-baz-foo-500:
	$(info ********** addr02-mint-and-stake-to-baz-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-baz-foo-500:
	$(info ********** addr03-mint-and-stake-to-baz-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-baz-foo-500:
	$(info ********** addr04-mint-and-stake-to-baz-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-baz-foo-500:
	$(info ********** addr05-mint-and-stake-to-baz-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-foo-qux-500:
	$(info ********** addr01-mint-and-stake-to-foo-qux-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-foo-qux-500:
	$(info ********** addr02-mint-and-stake-to-foo-qux-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-foo-qux-500:
	$(info ********** addr03-mint-and-stake-to-foo-qux-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-foo-qux-500:
	$(info ********** addr04-mint-and-stake-to-foo-qux-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-foo-qux-500:
	$(info ********** addr05-mint-and-stake-to-foo-qux-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/qux" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-gns-foo-500:
	$(info ********** addr01-mint-and-stake-to-gns-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-gns-foo-500:
	$(info ********** addr02-mint-and-stake-to-gns-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-gns-foo-500:
	$(info ********** addr03-mint-and-stake-to-gns-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-gns-foo-500:
	$(info ********** addr04-mint-and-stake-to-gns-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-gns-foo-500:
	$(info ********** addr05-mint-and-stake-to-gns-foo-500 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/gns -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/gnoswap/v2/gns" -args "gno.land/r/onbloc/foo" -args 500 -args "-100" -args "100" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo


addr01-mint-and-stake-to-bar-foo-10000:
	$(info ********** addr01-mint-and-stake-to-bar-foo-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-bar-foo-10000:
	$(info ********** addr02-mint-and-stake-to-bar-foo-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-bar-foo-10000:
	$(info ********** addr03-mint-and-stake-to-bar-foo-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-bar-foo-10000:
	$(info ********** addr04-mint-and-stake-to-bar-foo-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-bar-foo-10000:
	$(info ********** addr05-mint-and-stake-to-bar-foo-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/bar -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/foo -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/bar" -args "gno.land/r/onbloc/foo" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo

addr01-mint-and-stake-to-baz-qux-10000:
	$(info ********** addr01-mint-and-stake-to-baz-qux-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr01 > /dev/null
	@echo

addr02-mint-and-stake-to-baz-qux-10000:
	$(info ********** addr02-mint-and-stake-to-baz-qux-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr02 > /dev/null
	@echo

addr03-mint-and-stake-to-baz-qux-10000:
	$(info ********** addr03-mint-and-stake-to-baz-qux-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr03 > /dev/null
	@echo

addr04-mint-and-stake-to-baz-qux-10000:
	$(info ********** addr04-mint-and-stake-to-baz-qux-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr04 > /dev/null
	@echo

addr05-mint-and-stake-to-baz-qux-10000:
	$(info ********** addr05-mint-and-stake-to-baz-qux-10000 **********)
	# approve
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/baz -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/onbloc/qux -func Approve -args $(ADDR_POOL) -args $(MAX_UINT64) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null

	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo "" | gnokey maketx call -pkgpath gno.land/r/gnoswap/v2/staker -func MintAndStake -args "gno.land/r/onbloc/baz" -args "gno.land/r/onbloc/qux" -args 10000 -args "-200" -args "200" -args 100000000 -args 100000000 -args 0 -args 0 -args $(TX_EXPIRE) -insecure-password-stdin=true -remote $(GNOLAND_RPC_URL) -broadcast=true -chainid $(CHAINID) -gas-fee 1ugnot -gas-wanted 100000000 -memo "" addr05 > /dev/null
	@echo

