package governance

import (
	"chain/banker"
	"testing"

	"gno.land/p/onbloc/json"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

var (
	admin, _ = access.GetAddress(prbac.ROLE_ADMIN.String())

	fooPath string = "gno.land/r/onbloc/foo"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	quxPath string = "gno.land/r/onbloc/qux"

	oblPath string = "gno.land/r/onbloc/obl"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"
)

// Realms to mock frames
var (
	adminRealm = testing.NewUserRealm(admin)

	posPath  = "gno.land/r/gnoswap/position"
	posRealm = testing.NewCodeRealm(posPath)

	routerPath = "gno.land/r/gnoswap/router"
	rouRealm   = testing.NewCodeRealm(routerPath)

	stakerPath = "gno.land/r/gnoswap/staker"
	stkRealm   = testing.NewCodeRealm(stakerPath)

	govPath  = "gno.land/r/gnoswap/v1/gov/governance"
	govRealm = testing.NewCodeRealm(govPath)

	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	launchpadAddr, _     = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
)

/* HELPER */
func ugnotBalanceOf(addr address) uint64 {
	testBanker := banker.NewBanker(banker.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf("ugnot"))
}

func unmarshal(data string) *json.Node {
	return json.Must(json.Unmarshal([]byte(data)))
}
