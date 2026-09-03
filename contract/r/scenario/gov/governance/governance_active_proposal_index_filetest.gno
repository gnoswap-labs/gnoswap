// active proposal index avoids scanning archived proposal history

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	gns "gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

const archivedProposalCount = 1000

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
)

func main(cur realm) {
	delegateGnsToAdmin(cur)

	config := governance.GetLatestConfig()
	testing.SkipHeights(config.VotingWeightSmoothingDuration / 2)

	println("[SCENARIO] create and cancel archived proposals")
	for i := 0; i < archivedProposalCount; i++ {
		proposalID := governance.ProposeCommunityPoolSpend(cross(cur), "archived", "archived", adminAddr, "gno.land/r/gnoswap/gns.GNS", 100)
		governance.Cancel(cross(cur), proposalID)
	}
	println("[INFO] archived proposals:", archivedProposalCount)

	activeProposalID := governance.ProposeCommunityPoolSpend(cross(cur), "active", "active", adminAddr, "gno.land/r/gnoswap/gns.GNS", 100)
	_, hasActive := governance.GetOldestActiveProposalSnapshotTime()

	println("[INFO] active proposal id:", activeProposalID)
	println("[EXPECTED] proposal history:", governance.GetProposals().Size())
	println("[EXPECTED] oldest active snapshot exists:", hasActive)
}

func delegateGnsToAdmin(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), adminAddr, delegatedAmount, "")
}

// Output:
// [SCENARIO] create and cancel archived proposals
// [INFO] archived proposals: 1000
// [INFO] active proposal id: 1001
// [EXPECTED] proposal history: 1001
// [EXPECTED] oldest active snapshot exists: true
