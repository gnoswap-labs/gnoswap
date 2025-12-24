package emission

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

var (
	adminAddr, _         = access.GetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr, _        = access.GetAddress(prbac.ROLE_STAKER.String())
	govAddr, _           = access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	govStakerAddr, _     = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _        = access.GetAddress(prbac.ROLE_DEVOPS.String())
	communityPoolAddr, _ = access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())

	adminRealm     = testing.NewUserRealm(adminAddr)
	stakerRealm    = testing.NewUserRealm(stakerAddr)
	govRealm       = testing.NewUserRealm(govAddr)
	govStakerRealm = testing.NewUserRealm(govStakerAddr)
)

func resetObject(t *testing.T) {
	t.Helper()

	distributionBpsPct = make(map[int]int64)
	distributionBpsPct[LIQUIDITY_STAKER] = 7500
	distributionBpsPct[DEVOPS] = 2000
	distributionBpsPct[COMMUNITY_POOL] = 500
	distributionBpsPct[GOV_STAKER] = 0

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
	lastExecutedTimestamp = 0
	distributionStartTimestamp = 0
}
