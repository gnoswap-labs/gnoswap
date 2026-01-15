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

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

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

var (
	adminAddr     = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr = testutils.TestAddress("alice")

	currentBlockTime = int64(2)
)

func main() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	config := governance.GetLatestConfig()
	maxSmoothingPeriod := governance.GetMaxSmoothingPeriod()
	ufmt.Printf("[INFO] max smoothing period: %d seconds\n", maxSmoothingPeriod)

	println("[SCENARIO] 1. Setup: Delegate GNS to create initial snapshots")
	setupDelegation()
	firstDelegationTime := time.Now().Unix()
	ufmt.Printf("[INFO] first delegation time: %d\n", firstDelegationTime)
	println()

	println("[SCENARIO] 2. Skip voting weight smoothing duration")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println()

	println("[SCENARIO] 3. Add more delegation to create additional snapshots")
	addMoreDelegation()
	println()

	println("[SCENARIO] 4. Skip voting weight smoothing duration again")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	println()

	println("[SCENARIO] 5. Create a proposal (this creates a snapshot reference)")
	proposalId := createProposal()
	oldestActiveSnapshotTime, hasActive := governance.GetOldestActiveProposalSnapshotTime()
	if hasActive {
		ufmt.Printf("[INFO] oldest active proposal snapshot time: %d\n", oldestActiveSnapshotTime)
	}
	println()

	println("[SCENARIO] 6. Skip more time for cleanup eligibility (3x smoothing period)")
	testing.SkipHeights(int64(maxSmoothingPeriod) / currentBlockTime * 3)
	currentTime := time.Now().Unix()
	ufmt.Printf("[INFO] current time: %d\n", currentTime)
	println()

	println("[SCENARIO] 7. Calculate valid cleanup threshold")
	validCleanupThreshold := currentTime - maxSmoothingPeriod
	ufmt.Printf("[INFO] valid cleanup threshold (must be less than): %d\n", validCleanupThreshold)
	println()

	println("[SCENARIO] 8. Cleanup snapshots older than first delegation (safe cleanup)")
	beforeDelegationAmount, _ := gs.GetTotalDelegationAmountAtSnapshot(1234783890)
	ufmt.Printf("[INFO] before delegation amount: %d\n", beforeDelegationAmount)
	safeCleanupTime := firstDelegationTime - 100
	if safeCleanupTime < validCleanupThreshold {
		testing.SkipHeights(30 * 60 * 60 * 24 * 365)
		cleanupSnapshots(1234783890 + 5)
	} else {
		println("[INFO] safe cleanup time is not old enough, skipping cleanup test")
	}

	afterDelegationAmount, _ := gs.GetTotalDelegationAmountAtSnapshot(1234783890)
	ufmt.Printf("[INFO] after delegation amount: %d\n", afterDelegationAmount)

	println("[SCENARIO] 9. Verify proposal is still accessible after cleanup")
	verifyProposalAccessible(proposalId)
	println()

	println("[SCENARIO] 10. Verify total delegation preserved")
	verifyTotalDelegation()
	println()
}

func setupDelegation() {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, aliceAddr, 2_000_000_000)

	gns.Approve(cross, govStakerAddr, 1_000_000_000)
	gs.Delegate(cross, aliceAddr, 1_000_000_000, "")

	ufmt.Printf("[INFO] admin delegated 1,000,000,000 GNS to alice\n")
}

func addMoreDelegation() {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gns.Approve(cross, govStakerAddr, 500_000_000)
	gs.Delegate(cross, aliceAddr, 500_000_000, "")

	ufmt.Printf("[INFO] alice delegated additional 500,000,000 GNS\n")
}

func createProposal() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	proposalId := governance.ProposeText(cross, "Test Proposal for Snapshot Protection", "This proposal tests snapshot protection during cleanup")
	ufmt.Printf("[INFO] created proposal ID: %d\n", proposalId)
	return proposalId
}

func cleanupSnapshots(cleanupTime int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gs.CleanStakerDelegationSnapshotByAdmin(cross, cleanupTime)
	ufmt.Printf("[INFO] cleaned snapshots older than %d\n", cleanupTime)
	println("[EXPECTED] snapshot cleanup succeeded")
}

func verifyProposalAccessible(proposalId int64) {
	status, err := governance.GetProposalStatusByProposalId(proposalId)
	if err == nil {
		ufmt.Printf("[EXPECTED] proposal %d status: %s\n", proposalId, status)
		println("[EXPECTED] proposal is still accessible after cleanup")
	} else {
		ufmt.Printf("[FAIL] proposal should still be accessible: %v\n", err)
	}
}

func verifyTotalDelegation() {
	totalDelegated := gs.GetTotalDelegated()
	ufmt.Printf("[INFO] total delegated amount: %d\n", totalDelegated)

	if totalDelegated == 1_500_000_000 {
		println("[EXPECTED] total delegation amount preserved (1,000,000,000 + 500,000,000)")
	} else {
		println("[FAIL] total delegation amount mismatch")
	}
}

// Output:
// [INFO] max smoothing period: 2592000 seconds
// [SCENARIO] 1. Setup: Delegate GNS to create initial snapshots
// [INFO] admin delegated 1,000,000,000 GNS to alice
// [INFO] first delegation time: 1234567890
//
// [SCENARIO] 2. Skip voting weight smoothing duration
//
// [SCENARIO] 3. Add more delegation to create additional snapshots
// [INFO] alice delegated additional 500,000,000 GNS
//
// [SCENARIO] 4. Skip voting weight smoothing duration again
//
// [SCENARIO] 5. Create a proposal (this creates a snapshot reference)
// [INFO] created proposal ID: 1
// [INFO] oldest active proposal snapshot time: 1234913490
//
// [SCENARIO] 6. Skip more time for cleanup eligibility (3x smoothing period)
// [INFO] current time: 1254439890
//
// [SCENARIO] 7. Calculate valid cleanup threshold
// [INFO] valid cleanup threshold (must be less than): 1251847890
//
// [SCENARIO] 8. Cleanup snapshots older than first delegation (safe cleanup)
// [INFO] before delegation amount: 1500000000
// [INFO] cleaned snapshots older than 1234783895
// [EXPECTED] snapshot cleanup succeeded
// [INFO] after delegation amount: 0
// [SCENARIO] 9. Verify proposal is still accessible after cleanup
// [EXPECTED] proposal 1 status: passed
// [EXPECTED] proposal is still accessible after cleanup
//
// [SCENARIO] 10. Verify total delegation preserved
// [INFO] total delegated amount: 1500000000
// [EXPECTED] total delegation amount preserved (1,000,000,000 + 500,000,000)
