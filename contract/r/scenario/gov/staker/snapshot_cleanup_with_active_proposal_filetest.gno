// check snapshot cleanup logic with active proposal protection
//
// Scenario:
// 1. Delegate GNS and create delegation history snapshots
// 2. Wait for sufficient voting weight smoothing periods
// 3. Create a proposal (creates snapshot reference)
// 4. Wait for more time (for cleanup eligibility)
// 5. Cleanup old snapshots that don't affect active proposal
// 6. Verify proposal is still accessible after cleanup

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

	"gno.land/r/gnoswap/gov/governance"
	_ "gno.land/r/gnoswap/gov/governance/v1"

	gs "gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	"gno.land/r/gnoswap/gns"
)

var t *testing.T
var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr = testutils.TestAddress("alice")

	currentBlockTime = int64(2)
)

func main(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()

	setupDelegation(cur)
	firstDelegationTime := time.Now().Unix()

	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)

	addMoreDelegation(cur)

	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)

	proposalId := createProposal(cur)
	proposalCreatedAt, err := governance.GetProposalCreatedAt(proposalId)
	if err != nil {
		panic(err)
	}
	expectedActiveSnapshot := proposalCreatedAt - config.VotingWeightSmoothingDuration
	oldestActiveSnapshotTime, hasActive, err := governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	uassert.True(t, hasActive)
	uassert.Equal(t, expectedActiveSnapshot, oldestActiveSnapshotTime)
	historySize := governance.GetProposals().Size()

	testing.SkipHeights(int64(maxSmoothingPeriod) / currentBlockTime * 3)
	currentTime := time.Now().Unix()

	validCleanupThreshold := currentTime - maxSmoothingPeriod

	beforeDelegationAmount, _ := gs.GetTotalDelegationAmountAtSnapshot(1234783890)
	uassert.Equal(t, int64(1_500_000_000), beforeDelegationAmount)
	safeCleanupTime := firstDelegationTime - 100
	if safeCleanupTime < validCleanupThreshold {
		testing.SkipHeights(30 * 60 * 60 * 24 * 365)
		cleanupTime := int64(1234783890 + 5)
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		// Cleanup must not implicitly prune even this one expired proposal.
		uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-018]", func() {
			gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), cleanupTime, aliceAddr)
		})
		processed, hasMore := governance.PruneInactiveProposals(cross(cur), 1)
		uassert.Equal(t, 1, processed)
		uassert.False(t, hasMore)
		cleanupSnapshots(cur, cleanupTime)
	}

	afterDelegationAmount, _ := gs.GetTotalDelegationAmountAtSnapshot(1234783890)
	uassert.Equal(t, int64(0), afterDelegationAmount)

	verifyProposalAccessible(cur, proposalId)
	uassert.Equal(t, historySize, governance.GetProposals().Size())

	verifyTotalDelegation(cur)
}

func setupDelegation(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross(cur), aliceAddr, 2_000_000_000)

	gns.Approve(cross(cur), govStakerAddr, 1_000_000_000)
	gs.Delegate(cross(cur), aliceAddr, 1_000_000_000, "")
}

func addMoreDelegation(cur realm) {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gns.Approve(cross(cur), govStakerAddr, 500_000_000)
	gs.Delegate(cross(cur), aliceAddr, 500_000_000, "")
}

func createProposal(cur realm) int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross(cur), "Test Proposal for Snapshot Protection", "This proposal tests snapshot protection during cleanup")
	return proposalId
}

func cleanupSnapshots(cur realm, cleanupTime int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), cleanupTime, aliceAddr)
}

func verifyProposalAccessible(cur realm, proposalId int64) {
	status, err := governance.GetProposalStatusByProposalId(proposalId)
	uassert.NoError(t, err)
	uassert.Equal(t, "rejected", status)
}

func verifyTotalDelegation(cur realm) {
	totalDelegated := gs.GetTotalDelegated()
	uassert.Equal(t, int64(1_500_000_000), totalDelegated)
}
