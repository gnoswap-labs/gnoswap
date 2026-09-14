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
	println("[INFO] proposal history before maintenance:", historySize)

	snapshotTime, hasActive, err := governance.GetOldestActiveProposalSnapshotTime()
	println("[EXPECTED] stale snapshot:", snapshotTime, hasActive)
	uassert.ErrorContains(t, err, "[GNOSWAP-GOVERNANCE-018]")

	assertInvalidPruneLimit(cur, -1)
	assertInvalidPruneLimit(cur, 0)
	assertInvalidPruneLimit(cur, 201)
	println("[EXPECTED] history after invalid limits:", governance.GetProposals().Size())

	// Invalid arguments must not hide or mutate the stale first index entry.
	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	println("[EXPECTED] stale snapshot after invalid limits:", snapshotTime, hasActive)
	uassert.ErrorContains(t, err, "[GNOSWAP-GOVERNANCE-018]")

	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	uassert.AbortsContains(t, cur, "unauthorized", func() {
		_, _ = governance.PruneInactiveProposals(cross(cur), 1)
	})
	println("[EXPECTED] unauthorized maintenance rejected")

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	cleanupThreshold := time.Now().Unix() - maxSmoothingPeriod
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-018]", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), cleanupThreshold, adminAddr)
	})
	println("[EXPECTED] cleanup with stale index rejected")

	processed, hasMore := governance.PruneInactiveProposals(cross(cur), 1)
	println("[EXPECTED] limit 1:", processed, hasMore)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 2)
	println("[EXPECTED] limit 2:", processed, hasMore)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 200)
	println("[EXPECTED] limit 200:", processed, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] retained snapshot:", hasActive, snapshotTime == expectedActiveSnapshot)
	println("[EXPECTED] history after maintenance:", governance.GetProposals().Size())

	testing.SkipHeights(activeConfig.VotingStartDelay/currentBlockTime + 2)
	status, err := governance.GetProposalStatusByProposalId(activeProposalID)
	uassert.NoError(t, err)
	println("[EXPECTED] status before cleanup:", status)

	uassert.AbortsContains(t, cur, "active proposal requires data", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot+1, adminAddr)
	})
	println("[EXPECTED] unsafe cleanup cutoff rejected")
	gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot, adminAddr)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] retained snapshot after cleanup:", hasActive, snapshotTime == expectedActiveSnapshot)
	println("[EXPECTED] history after cleanup:", governance.GetProposals().Size())

	testing.SkipHeights((activeConfig.VotingStartDelay+activeConfig.VotingPeriod)/currentBlockTime + 2)
	processed, hasMore = governance.PruneInactiveProposals(cross(cur), 1)
	println("[EXPECTED] terminal batch:", processed, hasMore)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] empty snapshot:", snapshotTime, hasActive)
	println("[EXPECTED] final proposal history:", governance.GetProposals().Size())
}

func assertInvalidPruneLimit(cur realm, limit int) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-001]", func() {
		_, _ = governance.PruneInactiveProposals(cross(cur), limit)
	})
	println("[EXPECTED] rejected limit:", limit)
}

func delegateGnsToAdmin(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), adminAddr, delegatedAmount, "")
}

// Output:
// [INFO] proposal history before maintenance: 204
// [EXPECTED] stale snapshot: 0 false
// [EXPECTED] rejected limit: -1
// [EXPECTED] rejected limit: 0
// [EXPECTED] rejected limit: 201
// [EXPECTED] history after invalid limits: 204
// [EXPECTED] stale snapshot after invalid limits: 0 false
// [EXPECTED] unauthorized maintenance rejected
// [EXPECTED] cleanup with stale index rejected
// [EXPECTED] limit 1: 1 true
// [EXPECTED] limit 2: 2 true
// [EXPECTED] limit 200: 200 false
// [EXPECTED] retained snapshot: true true
// [EXPECTED] history after maintenance: 204
// [EXPECTED] status before cleanup: active
// [EXPECTED] unsafe cleanup cutoff rejected
// [EXPECTED] retained snapshot after cleanup: true true
// [EXPECTED] history after cleanup: 204
// [EXPECTED] terminal batch: 1 false
// [EXPECTED] empty snapshot: 0 false
// [EXPECTED] final proposal history: 204
