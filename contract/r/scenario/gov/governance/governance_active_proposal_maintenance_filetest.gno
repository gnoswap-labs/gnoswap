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

// The production cap is currently 200. Three extra proposals let this
// scenario exercise small batches before a full-cap batch without duplicate
// fixtures.
const maintenanceBacklog = 203

func main(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	delegateGnsToAdmin(cur)
	testing.SkipHeights(config.VotingWeightSmoothingDuration/currentBlockTime + 1)
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()
	governance.Reconfigure(cross(cur), 1, 1, maxSmoothingPeriod, 50, 0, 1, 1)
	shortConfig, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	for i := 0; i < maintenanceBacklog; i++ {
		governance.ProposeText(cross(cur), "stale", "stale")
		testing.SkipHeights((shortConfig.VotingStartDelay+shortConfig.VotingPeriod)/currentBlockTime + 1)
	}

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

	assertInvalidPruneLimit(cur, -1)
	assertInvalidPruneLimit(cur, 0)
	assertInvalidPruneLimit(cur, 201)
	uassert.Equal(t, historySize, governance.GetProposals().Size())

	// Invalid arguments must not hide or mutate the stale first index entry.
	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.Equal(t, int64(0), snapshotTime)
	uassert.False(t, hasActive)
	uassert.ErrorContains(t, err, "[GNOSWAP-GOVERNANCE-018]")

	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	uassert.AbortsContains(t, cur, "unauthorized", func() {
		_, _ = governance.PruneInactiveProposals(cross(cur), 1)
	})

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	cleanupThreshold := time.Now().Unix() - maxSmoothingPeriod
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-018]", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), cleanupThreshold, adminAddr)
	})

	processed, hasMore := governance.PruneInactiveProposals(cross(cur), 1)
	uassert.Equal(t, 1, processed)
	uassert.True(t, hasMore)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 2)
	uassert.Equal(t, 2, processed)
	uassert.True(t, hasMore)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 200)
	uassert.Equal(t, 200, processed)
	uassert.False(t, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.True(t, hasActive)
	uassert.Equal(t, expectedActiveSnapshot, snapshotTime)
	uassert.Equal(t, historySize, governance.GetProposals().Size())

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

	testing.SkipHeights((activeConfig.VotingStartDelay+activeConfig.VotingPeriod)/currentBlockTime + 2)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 1)
	uassert.Equal(t, 1, processed)
	uassert.False(t, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), snapshotTime)
	uassert.False(t, hasActive)
	uassert.Equal(t, historySize, governance.GetProposals().Size())
}

func assertInvalidPruneLimit(cur realm, limit int) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-001]", func() {
		_, _ = governance.PruneInactiveProposals(cross(cur), limit)
	})
}

func delegateGnsToAdmin(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), adminAddr, delegatedAmount, "")
}
