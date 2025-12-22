package emission

import (
	"strconv"
	"testing"

	"gno.land/p/nt/avl"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

func getAdminAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_ADMIN.String())
	return addr
}

func getStakerAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_STAKER.String())
	return addr
}

func getGovAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_GOVERNANCE.String())
	return addr
}

func getGovStakerAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	return addr
}

func getDevOpsAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_DEVOPS.String())
	return addr
}

func getCommunityPoolAddr() address {
	addr, _ := access.GetAddress(prbac.ROLE_COMMUNITY_POOL.String())
	return addr
}

func getAdminRealm() testing.Realm {
	return testing.NewUserRealm(getAdminAddr())
}

func getStakerRealm() testing.Realm {
	return testing.NewUserRealm(getStakerAddr())
}

func getGovRealm() testing.Realm {
	return testing.NewUserRealm(getGovAddr())
}

func getGovStakerRealm() testing.Realm {
	return testing.NewUserRealm(getGovStakerAddr())
}

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
	lastExecutedTimestamp = 0
	distributionStartTimestamp = 0
}
