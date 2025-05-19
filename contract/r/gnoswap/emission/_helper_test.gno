package emission

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/avl"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"
)

var (
	adminRealm     = std.NewUserRealm(adminAddr)
	stakerRealm    = std.NewCodeRealm(consts.STAKER_PATH)
	govRealm       = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
	govStakerRealm = std.NewCodeRealm(consts.GOV_STAKER_PATH)
)

func resetObject(t *testing.T) {
	t.Helper()

	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(int(LIQUIDITY_STAKER)), 7500)
	distributionBpsPct.Set(strconv.Itoa(int(DEVOPS)), 2000)
	distributionBpsPct.Set(strconv.Itoa(int(COMMUNITY_POOL)), 500)
	distributionBpsPct.Set(strconv.Itoa(int(GOV_STAKER)), 0)

	distributedToStaker = 0
	distributedToDevOps = 0
	distributedToCommunityPool = 0
	distributedToGovStaker = 0
	accuDistributedToStaker = 0
	accuDistributedToDevOps = 0
	accuDistributedToCommunityPool = 0
	accuDistributedToGovStaker = 0
}

func gnsBalance(t *testing.T, addr std.Address) int64 {
	t.Helper()

	return gns.BalanceOf(addr)
}
