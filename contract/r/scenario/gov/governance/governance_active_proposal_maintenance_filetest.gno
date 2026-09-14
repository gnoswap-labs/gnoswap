// admin maintenance removes one inactive proposal from the active snapshot index

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

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

func main(cur realm) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()

	delegateGnsToAdminAndUser(cur)
	testing.SkipHeights(maxSmoothingPeriod/currentBlockTime + 1)

	// Keep the first backlog small, while making every lifecycle boundary
	// reachable in a few simulated blocks.
	governance.Reconfigure(cross(cur), 1, 1, maxSmoothingPeriod, 50, 0, 1, 1)
	staleConfig, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}

	firstID := governance.ProposeText(cross(cur), "stale-first", "stale-first")
	expireProposal(staleConfig)
	secondID := governance.ProposeText(cross(cur), "stale-second", "stale-second")
	expireProposal(staleConfig)

	// Give voting and execution windows room for the five-second test blocks.
	governance.Reconfigure(cross(cur), 5, 10, maxSmoothingPeriod, 50, 0, 5, 30)
	executableConfig, err := governance.GetLatestConfig()
	uassert.NoError(t, err)
	executableID := governance.ProposeCommunityPoolSpend(
		cross(cur),
		"passed executable",
		"passed executable",
		adminAddr,
		"gno.land/r/gnoswap/gns.GNS",
		1,
	)
	testing.SkipHeights(executableConfig.VotingStartDelay/currentBlockTime + 1)
	governance.Vote(cross(cur), executableID, true)
	testing.SkipHeights((executableConfig.VotingPeriod+executableConfig.ExecutionDelay)/currentBlockTime + 1)
	status, err := governance.GetProposalStatusByProposalId(executableID)
	uassert.NoError(t, err)
	println("[EXPECTED] executable before expiry:", executableID, status)

	// Use a longer voting period for the second proposer so it remains active
	// while the passed executable proposal reaches its expiry.
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	governance.Reconfigure(cross(cur), 1, 100, maxSmoothingPeriod, 50, 0, 1, 1)
	activeConfig, err := governance.GetLatestConfig()
	if err != nil {
		panic(err)
	}
	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	activeID := governance.ProposeText(cross(cur), "active", "active")
	activeStatus, err := governance.GetProposalStatusByProposalId(activeID)
	uassert.NoError(t, err)
	println("[EXPECTED] active proposal initially:", activeID, activeStatus)

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	assertActiveProposal(cur, activeID, activeConfig)
	assertMissingProposal(cur, 9999)
	assertUnauthorizedRemoval(cur, executableID)

	// The target ID is not required to be the first index entry.
	governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), secondID)
	println("[EXPECTED] removed non-head index entry:", secondID)
	assertStaleHead(cur, firstID)

	maxSmoothingThreshold := time.Now().Unix() - maxSmoothingPeriod
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-018]", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), maxSmoothingThreshold, adminAddr)
	})
	println("[EXPECTED] cleanup with stale index rejected")

	governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), firstID)
	println("[EXPECTED] removed head index entry:", firstID)
	executableCreatedAt, err := governance.GetProposalCreatedAt(executableID)
	uassert.NoError(t, err)
	snapshotTime, hasActive, err := governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] executable snapshot:", hasActive, snapshotTime == executableCreatedAt-executableConfig.VotingWeightSmoothingDuration)

	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-001]", func() {
		governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), executableID)
	})
	println("[EXPECTED] executable proposal protected")

	voteWeight, err := governance.GetYeaByProposalId(executableID)
	uassert.NoError(t, err)
	println("[EXPECTED] executable history before expiry:", governance.ExistsProposal(executableID), governance.ExistsVotingInfo(executableID, adminAddr), voteWeight, governance.GetProposals().Size())

	testing.SkipHeights(executableConfig.ExecutionWindow/currentBlockTime + 1)
	status, err = governance.GetProposalStatusByProposalId(executableID)
	uassert.NoError(t, err)
	println("[EXPECTED] executable after expiry:", executableID, status)
	assertStaleHead(cur, executableID)
	governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), executableID)
	println("[EXPECTED] removed expired executable:", executableID)

	activeCreatedAt, err := governance.GetProposalCreatedAt(activeID)
	uassert.NoError(t, err)
	expectedActiveSnapshot := activeCreatedAt - activeConfig.VotingWeightSmoothingDuration
	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] active snapshot:", hasActive, snapshotTime == expectedActiveSnapshot)

	uassert.AbortsContains(t, cur, "active proposal requires data", func() {
		gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot+1, adminAddr)
	})
	println("[EXPECTED] unsafe active snapshot cleanup rejected")
	gs.CleanStakerDelegationSnapshotByAdmin(cross(cur), expectedActiveSnapshot, adminAddr)
	println("[EXPECTED] active snapshot cleanup succeeded")

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] active snapshot after cleanup:", hasActive, snapshotTime == expectedActiveSnapshot)
	delegated, exists := gs.GetTotalDelegationAmountAtSnapshot(expectedActiveSnapshot)
	println("[EXPECTED] delegation at active snapshot:", delegated, exists)

	testing.SkipHeights(activeConfig.VotingPeriod/currentBlockTime + 1)
	status, err = governance.GetProposalStatusByProposalId(activeID)
	uassert.NoError(t, err)
	println("[EXPECTED] active proposal after voting:", activeID, status)
	governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), activeID)
	println("[EXPECTED] removed final index entry:", activeID)

	snapshotTime, hasActive, err = governance.GetOldestActiveProposalSnapshotTime()
	uassert.NoError(t, err)
	println("[EXPECTED] empty snapshot:", snapshotTime, hasActive)
	println("[EXPECTED] final proposal history:", governance.GetProposals().Size())
	println("[EXPECTED] executable history after removal:", governance.ExistsProposal(executableID), governance.ExistsVotingInfo(executableID, adminAddr), governance.GetProposals().Size())
}

func expireProposal(config governance.Config) {
	testing.SkipHeights((config.VotingStartDelay+config.VotingPeriod)/currentBlockTime + 1)
}

func assertMissingProposal(cur realm, proposalID int64) {
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-012]", func() {
		governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), proposalID)
	})
	println("[EXPECTED] missing proposal rejected:", proposalID)
}

func assertUnauthorizedRemoval(cur realm, proposalID int64) {
	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	uassert.AbortsContains(t, cur, "unauthorized", func() {
		governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), proposalID)
	})
	println("[EXPECTED] unauthorized maintenance rejected")
	testing.SetRealm(testing.NewUserRealm(adminAddr))
}

func assertStaleHead(cur realm, proposalID int64) {
	snapshotTime, hasActive, err := governance.GetOldestActiveProposalSnapshotTime()
	uassert.ErrorContains(t, err, "[GNOSWAP-GOVERNANCE-018]")
	uassert.ErrorContains(t, err, ufmt.Sprintf("proposalID: %d", proposalID))
	println("[EXPECTED] stale head:", proposalID, snapshotTime, hasActive)
}

func assertActiveProposal(cur realm, proposalID int64, config governance.Config) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-001]", func() {
		governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), proposalID)
	})
	println("[EXPECTED] upcoming proposal protected")

	testing.SkipHeights(config.VotingStartDelay/currentBlockTime + 1)
	status, err := governance.GetProposalStatusByProposalId(proposalID)
	uassert.NoError(t, err)
	println("[EXPECTED] active proposal status:", proposalID, status)
	uassert.AbortsContains(t, cur, "[GNOSWAP-GOVERNANCE-001]", func() {
		governance.RemoveInactiveProposalFromIndexByAdmin(cross(cur), proposalID)
	})
	println("[EXPECTED] active proposal protected")
}

func delegateGnsToAdminAndUser(cur realm) {
	delegatedAmount := int64(1_000_000_000)
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), adminAddr, delegatedAmount, "")

	gns.Transfer(cross(cur), nonAdminAddr, delegatedAmount)
	testing.SetRealm(testing.NewUserRealm(nonAdminAddr))
	gns.Approve(cross(cur), govStakerAddr, delegatedAmount)
	gs.Delegate(cross(cur), nonAdminAddr, delegatedAmount, "")
	testing.SetRealm(testing.NewUserRealm(adminAddr))
}

// Output:
// [EXPECTED] executable before expiry: 3 executable
// [EXPECTED] active proposal initially: 4 upcoming
// [EXPECTED] upcoming proposal protected
// [EXPECTED] active proposal status: 4 active
// [EXPECTED] active proposal protected
// [EXPECTED] missing proposal rejected: 9999
// [EXPECTED] unauthorized maintenance rejected
// [EXPECTED] removed non-head index entry: 2
// [EXPECTED] stale head: 1 0 false
// [EXPECTED] cleanup with stale index rejected
// [EXPECTED] removed head index entry: 1
// [EXPECTED] executable snapshot: true true
// [EXPECTED] executable proposal protected
// [EXPECTED] executable history before expiry: true true 1000000000 4
// [EXPECTED] executable after expiry: 3 expired
// [EXPECTED] stale head: 3 0 false
// [EXPECTED] removed expired executable: 3
// [EXPECTED] active snapshot: true true
// [EXPECTED] unsafe active snapshot cleanup rejected
// [EXPECTED] active snapshot cleanup succeeded
// [EXPECTED] active snapshot after cleanup: true true
// [EXPECTED] delegation at active snapshot: 2000000000 true
// [EXPECTED] active proposal after voting: 4 rejected
// [EXPECTED] removed final index entry: 4
// [EXPECTED] empty snapshot: 0 false
// [EXPECTED] final proposal history: 4
// [EXPECTED] executable history after removal: true true 4
