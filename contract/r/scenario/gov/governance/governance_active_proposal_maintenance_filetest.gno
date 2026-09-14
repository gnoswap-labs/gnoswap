// bounded public maintenance keeps stale active-index entries from blocking cleanup

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"
	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var t *testing.T

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	nonAdminAddr  = testutils.TestAddress("maintenance-user")

	currentBlockTime = int64(5)
)

// The production cap is currently 200. One extra proposal keeps this scenario
// small while proving that a second public call is required for overflow.
const maintenanceBacklog = 201

func main(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	println("[SCENARIO] 1. Prepare delegation and short lifecycle")
	delegateGnsToAdmin(cur)
	testing.SkipHeights(config.VotingWeightSmoothingDuration/currentBlockTime + 1)
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()
	governance.Reconfigure(cross(cur), 1, 1, maxSmoothingPeriod, 50, 0, 1, 1)
	shortConfig, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	println("[SCENARIO] 2. Build a bounded stale proposal backlog")
	for i := 0; i < maintenanceBacklog; i++ {
		governance.ProposeText(cross(cur), "stale", "stale")
		testing.SkipHeights((shortConfig.VotingStartDelay+shortConfig.VotingPeriod)/currentBlockTime + 1)
	}

	println("[SCENARIO] 3. Add one active proposal and observe maintenance error")
	governance.Reconfigure(cross(cur), 1, 100, maxSmoothingPeriod, 50, 0, 1, 1)
	activeConfig, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	activeProposalID := governance.ProposeCommunityPoolSpend(
		cross(cur),
		"retained",
		"retained",
		adminAddr,
		"gno.land/r/gnoswap/gns.GNS",
		1,
	)
	activeCreatedAt, err := governance.GetProposalCreatedAt(activeProposalID)
	if err != nil {
		panic(err)
	}
	expectedActiveSnapshot := activeCreatedAt - activeConfig.VotingWeightSmoothingDuration
	historySize := governance.GetProposals().Size()

	snapshotTime, hasActive, err := governance.GetOldestActiveProposalSnapshotTime()
	uassert.Equal(t, int64(0), snapshotTime)
	uassert.False(t, hasActive)
	uassert.ErrorContains(t, err, "[GNOSWAP-GOVERNANCE-018]")

	println("[SCENARIO] 4. Enforce roles and bounded public progress")
	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	uassert.AbortsContains(t, cur, "unauthorized", func() {
		_, _ = governance.PruneInactiveProposals(cross(cur))
	})

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	cleanupThreshold := time.Now().Unix() - maxSmoothingPeriod
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-018]", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), cleanupThreshold, adminAddr)
	})

	processed, hasMore := governance.PruneInactiveProposals(cross(cur))
	uassert.True(t, processed > 0)
	if hasMore {
		processed, hasMore = governance.PruneInactiveProposals(cross(cur))
		uassert.True(t, processed > 0)
	}
	uassert.False(t, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.True(t, hasActive)
	uassert.Equal(t, expectedActiveSnapshot, snapshotTime)
	uassert.Equal(t, historySize, governance.GetProposals().Size())

	println("[SCENARIO] 5. Preserve active retention, then allow safe cleanup")
	testing.SkipHeights(activeConfig.VotingStartDelay/currentBlockTime + 2)
	status, err := governance.GetProposalStatusByProposalId(activeProposalID)
	uassert.NoError(t, err)
	uassert.Equal(t, "active", status)

	uassert.AbortsContains(t, cur, "active proposal requires data", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot+1, adminAddr)
	})
	gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot, adminAddr)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.True(t, hasActive)
	uassert.Equal(t, expectedActiveSnapshot, snapshotTime)
	uassert.Equal(t, historySize, governance.GetProposals().Size())

	println("[SCENARIO] 6. Prune terminal proposal and observe empty index")
	testing.SkipHeights((activeConfig.VotingStartDelay+activeConfig.VotingPeriod)/currentBlockTime + 2)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur))
	uassert.True(t, processed > 0)
	uassert.False(t, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), snapshotTime)
	uassert.False(t, hasActive)
	uassert.Equal(t, historySize, governance.GetProposals().Size())
}

func delegateGnsToAdmin(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), adminAddr, delegatedAmount, "")
}

// Output:
// [SCENARIO] 1. Prepare delegation and short lifecycle
// [SCENARIO] 2. Build a bounded stale proposal backlog
// [SCENARIO] 3. Add one active proposal and observe maintenance error
// [SCENARIO] 4. Enforce roles and bounded public progress
// [SCENARIO] 5. Preserve active retention, then allow safe cleanup
// [SCENARIO] 6. Prune terminal proposal and observe empty index
