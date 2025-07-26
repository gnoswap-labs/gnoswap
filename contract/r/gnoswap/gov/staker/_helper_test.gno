package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/json"
	"gno.land/p/demo/testutils"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"
)

// contract Paths
const (
	GNS_PATH    string      = "gno.land/r/gnoswap/v1/gns"
	WUGNOT_ADDR std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"
)

var (
	admin, _             = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	protocolFeeAddr, _   = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr, _     = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	devOpsAddr, _        = access.GetAddress(prbac.ROLE_DEVOPS.String())

	fooPath  string = "gno.land/r/onbloc/foo"
	barPath  string = "gno.land/r/onbloc/bar"
	bazPath  string = "gno.land/r/onbloc/baz"
	quxPath  string = "gno.land/r/onbloc/qux"
	oblPath  string = "gno.land/r/onbloc/obl"
	usdcPath string = "gno.land/r/onbloc/usdc"

	ugnotDenom string = "ugnot"
	ugnotPath  string = "ugnot"
	wugnotPath string = "gno.land/r/demo/wugnot"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	realmPrefix = "/gno.land/r/gnoswap/v1/gov/staker"
)

// Realms to mock frames
var (
	adminRealm  = std.NewUserRealm(admin)
	userRealm   = std.NewUserRealm(testutils.TestAddress("alice"))
	user2Realm  = std.NewUserRealm(testutils.TestAddress("bob"))
	user3Realm  = std.NewUserRealm(testutils.TestAddress("charlie"))
	invalidAddr = testutils.TestAddress("invalid")

	posRealm    = std.NewCodeRealm("gno.land/r/gnoswap/v1/position")
	rouRealm    = std.NewCodeRealm("gno.land/r/gnoswap/v1/router")
	stakerRealm = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")
)

func makeFakeAddress(name string) std.Address {
	return testutils.TestAddress(name)
}

func ugnotTransfer(t *testing.T, from, to std.Address, amount uint64) {
	t.Helper()

	testing.SetRealm(std.NewUserRealm(from))
	testing.SetOriginSend(std.Coins{{ugnotDenom, int64(amount)}})
	banker := std.NewBanker(std.BankerTypeRealmSend)

	banker.SendCoins(from, to, std.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr std.Address) uint64 {
	t.Helper()

	banker := std.NewBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf(ugnotDenom))
}

func ugnotMint(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	testing.IssueCoins(addr, std.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBurn(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.RemoveCoin(addr, ugnotDenom, amount)
}

func ugnotFaucet(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	// faucet address is admin
	testing.SetOriginCaller(admin)

	if ugnotBalanceOf(t, admin) < amount {
		ugnotMint(t, admin, ugnotPath, int64(amount))
		testing.SetOriginSend(std.Coins{{ugnotPath, int64(amount)}})
	}
	ugnotTransfer(t, admin, to, amount)
}

func ugnotDeposit(t *testing.T, addr std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(addr))
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(addr, WUGNOT_ADDR, std.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit(cross)
}

func unmarshal(data string) *json.Node {
	return json.Must(json.Unmarshal([]byte(data)))
}
