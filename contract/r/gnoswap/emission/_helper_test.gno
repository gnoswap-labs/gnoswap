package emission

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/avl"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/access"
	_ "gno.land/r/gnoswap/v1/rbac" // initialize rbac package
)

var (
	adminAddr, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _    = access.GetAddress(prbac.ROLE_STAKER.String())
	govAddr, _       = access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _     = access.GetAddress(prbac.ROLE_DEVOPS.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	adminRealm       = std.NewUserRealm(adminAddr)
	stakerRealm      = std.NewUserRealm(stakerAddr)
	govRealm         = std.NewUserRealm(govAddr)
	govStakerRealm   = std.NewUserRealm(govStakerAddr)
)

func resetObject(t *testing.T) {
	t.Helper()

	distributionBpsPct = avl.NewTree()
	distributionBpsPct.Set(strconv.Itoa(LIQUIDITY_STAKER), int64(7500))
	distributionBpsPct.Set(strconv.Itoa(DEVOPS), int64(2000))
	distributionBpsPct.Set(strconv.Itoa(COMMUNITY_POOL), int64(500))
	distributionBpsPct.Set(strconv.Itoa(GOV_STAKER), int64(0))

	distributedToStaker = 0
	distributedToDevOps = 0
	distributedToCommunityPool = 0
	distributedToGovStaker = 0
	accuDistributedToStaker = 0
	accuDistributedToDevOps = 0
	accuDistributedToCommunityPool = 0
	accuDistributedToGovStaker = 0

	// Reset emission-specific variables
	leftGNSAmount = 0
	lastExecutedHeight = 0
}
