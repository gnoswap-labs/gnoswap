package v1

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/onbloc/json"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoland/wugnot"

	"gno.land/r/gnoswap/access"
)

// contract Paths
const (
	GNS_PATH    string  = "gno.land/r/gnoswap/gns"
	WUGNOT_ADDR address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"
	GOV_STAKER_PKG_PATH = "gno.land/r/gnoswap/gov/staker"
)

var (
	admin             = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr        = access.MustGetAddress(prbac.ROLE_STAKER.String())
	communityPoolAddr = access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	govStakerAddr     = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm    = testing.NewUserRealm(govStakerAddr)

	protocolFeeAddr   = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr     = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())

	devOpsAddr        = access.MustGetAddress(prbac.ROLE_DEVOPS.String())

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	fooPath  string = "gno.land/r/onbloc/foo"
	barPath  string = "gno.land/r/onbloc/bar"
	bazPath  string = "gno.land/r/onbloc/baz"
	quxPath  string = "gno.land/r/onbloc/qux"
	oblPath  string = "gno.land/r/onbloc/obl"
	usdcPath string = "gno.land/r/onbloc/usdc"

	ugnotDenom string = "ugnot"
	ugnotPath  string = "ugnot"
	wugnotPath string = "gno.land/r/gnoland/wugnot"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	realmPrefix = "/gno.land/r/gnoswap/gov/staker"
)

// Realms to mock frames
var (
	adminRealm  = testing.NewUserRealm(admin)
	userRealm   = testing.NewUserRealm(testutils.TestAddress("alice"))
	user2Realm  = testing.NewUserRealm(testutils.TestAddress("bob"))
	user3Realm  = testing.NewUserRealm(testutils.TestAddress("charlie"))
	invalidAddr = testutils.TestAddress("invalid")

	posRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/position")
	rouRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")
)

func makeFakeAddress(name string) address {
	return testutils.TestAddress(name)
}

func ugnotTransfer(t *testing.T, from, to address, amount uint64) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(from))
	testing.SetOriginSend(chain.Coins{{ugnotDenom, int64(amount)}})
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)

	banker_.SendCoins(from, to, chain.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr address) uint64 {
	t.Helper()

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	coins := banker_.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf(ugnotDenom))
}

func ugnotMint(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	testing.IssueCoins(addr, chain.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBurn(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	banker_.RemoveCoin(addr, ugnotDenom, amount)
}

func ugnotFaucet(t *testing.T, to address, amount uint64) {
	t.Helper()
	// faucet address is admin
	testing.SetOriginCaller(admin)

	if ugnotBalanceOf(t, admin) < amount {
		ugnotMint(t, admin, ugnotPath, int64(amount))
		testing.SetOriginSend(chain.Coins{{ugnotPath, int64(amount)}})
	}
	ugnotTransfer(t, admin, to, amount)
}

func ugnotDeposit(t *testing.T, addr address, amount uint64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(addr))
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(addr, WUGNOT_ADDR, chain.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit(cross)
}

func unmarshal(data string) *json.Node {
	return json.Must(json.Unmarshal([]byte(data)))
}
