package emission

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/avl"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

var (
	adminRealm     = std.NewUserRealm(consts.ADMIN)
	stakerRealm    = std.NewCodeRealm(consts.STAKER_PATH)
	govRealm       = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
	govStakerRealm = std.NewCodeRealm(consts.GOV_STAKER_PATH)
)

func resetObject(t *testing.T) {
	t.Helper()

	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), 7500)
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), 2000)
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), 500)
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), 0)

	distributedToStaker = 0
	distributedToDevOps = 0
	distributedToCommunityPool = 0
	distributedToGovStaker = 0
	accuDistributedToStaker = 0
	accuDistributedToDevOps = 0
	accuDistributedToCommunityPool = 0
	accuDistributedToGovStaker = 0
}

func gnsBalance(t *testing.T, addr std.Address) uint64 {
	t.Helper()

	return gns.BalanceOf(a2u(addr))
}
