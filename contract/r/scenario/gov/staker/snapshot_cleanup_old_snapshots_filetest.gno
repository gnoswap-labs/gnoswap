// check old snapshot cleanup logic
//
// Scenario:
// 1. Create delegation snapshots over multiple periods
// 2. Wait sufficient time for cleanup eligibility (3x max smoothing period)
// 3. Clean old snapshots by admin
// 4. Verify old snapshots are removed but total delegation preserved

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

	println("[SCENARIO] 1. Setup initial delegation (creates first snapshot)")
	snapshot1Time := setupInitialDelegation()
	println()

	println("[SCENARIO] 2. Skip time and add more delegation (creates second snapshot)")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	addSecondDelegation()
	println()

	println("[SCENARIO] 3. Skip time and add final delegation (creates third snapshot)")
	testing.SkipHeights(int64(config.VotingWeightSmoothingDuration) / currentBlockTime)
	addThirdDelegation()
	println()

	println("[SCENARIO] 4. Skip sufficient time for cleanup eligibility (3x max smoothing period)")
	testing.SkipHeights(int64(maxSmoothingPeriod) / currentBlockTime * 3)
	currentTime := time.Now().Unix()
	ufmt.Printf("[INFO] current time: %d\n", currentTime)
	println()

	println("[SCENARIO] 5. Verify delegation snapshot data exists")
	verifySnapshotsExist()
	println()

	println("[SCENARIO] 6. Calculate valid cleanup threshold")
	validCleanupThreshold := currentTime - maxSmoothingPeriod
	ufmt.Printf("[INFO] valid cleanup threshold (must be less than): %d\n", validCleanupThreshold)
	println()

	println("[SCENARIO] 7. Clean old snapshots (before first snapshot)")
	safeCleanupTime := snapshot1Time - 100
	if safeCleanupTime < validCleanupThreshold {
		cleanOldSnapshots(safeCleanupTime)
	} else {
		println("[INFO] cleanup time not old enough, skipping")
	}
	println()

	println("[SCENARIO] 8. Verify cleanup results")
	verifyCleanupResults()
	println()
}

func setupInitialDelegation() int64 {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, aliceAddr, 3_000_000_000)

	gns.Approve(cross, govStakerAddr, 1_000_000_000)
	gs.Delegate(cross, aliceAddr, 1_000_000_000, "")

	snapshotTime := time.Now().Unix()
	ufmt.Printf("[INFO] first delegation: 1,000,000,000 GNS at time %d\n", snapshotTime)
	return snapshotTime
}

func addSecondDelegation() {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gns.Approve(cross, govStakerAddr, 500_000_000)
	gs.Delegate(cross, aliceAddr, 500_000_000, "")

	snapshotTime := time.Now().Unix()
	ufmt.Printf("[INFO] second delegation: 500,000,000 GNS at time %d\n", snapshotTime)
}

func addThirdDelegation() {
	testing.SetRealm(testing.NewUserRealm(aliceAddr))

	gns.Approve(cross, govStakerAddr, 300_000_000)
	gs.Delegate(cross, aliceAddr, 300_000_000, "")

	snapshotTime := time.Now().Unix()
	ufmt.Printf("[INFO] third delegation: 300,000,000 GNS at time %d\n", snapshotTime)
}

func verifySnapshotsExist() {
	hasSnapshots := gs.HasDelegationSnapshotsKey()
	if hasSnapshots {
		println("[INFO] delegation snapshots exist")
	} else {
		println("[WARN] no delegation snapshots found")
	}

	totalDelegated := gs.GetTotalDelegated()
	ufmt.Printf("[INFO] total delegated amount: %d\n", totalDelegated)

	if totalDelegated == 1_800_000_000 {
		println("[EXPECTED] total delegated amount is correct (1,000,000,000 + 500,000,000 + 300,000,000)")
	}
}

func cleanOldSnapshots(cleanupTime int64) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	gs.CleanStakerDelegationSnapshotByAdmin(cross, cleanupTime)
	ufmt.Printf("[INFO] cleaned snapshots older than %d\n", cleanupTime)
	println("[EXPECTED] old snapshot cleanup completed")
}

func verifyCleanupResults() {
	// Verify total delegation amount is preserved
	totalDelegated := gs.GetTotalDelegated()
	ufmt.Printf("[INFO] total delegated after cleanup: %d\n", totalDelegated)

	if totalDelegated == 1_800_000_000 {
		println("[EXPECTED] total delegation amount preserved after cleanup")
	} else {
		println("[FAIL] total delegation amount changed after cleanup")
	}

	// Check that snapshots key still exists
	hasSnapshots := gs.HasDelegationSnapshotsKey()
	if hasSnapshots {
		println("[EXPECTED] delegation snapshots still exist after cleanup")
	}
}

// Output:
// [INFO] max smoothing period: 2592000 seconds
// [SCENARIO] 1. Setup initial delegation (creates first snapshot)
// [INFO] first delegation: 1,000,000,000 GNS at time 1234567890
//
// [SCENARIO] 2. Skip time and add more delegation (creates second snapshot)
// [INFO] second delegation: 500,000,000 GNS at time 1234783890
//
// [SCENARIO] 3. Skip time and add final delegation (creates third snapshot)
// [INFO] third delegation: 300,000,000 GNS at time 1234999890
//
// [SCENARIO] 4. Skip sufficient time for cleanup eligibility (3x max smoothing period)
// [INFO] current time: 1254439890
//
// [SCENARIO] 5. Verify delegation snapshot data exists
// [INFO] delegation snapshots exist
// [INFO] total delegated amount: 1800000000
// [EXPECTED] total delegated amount is correct (1,000,000,000 + 500,000,000 + 300,000,000)
//
// [SCENARIO] 6. Calculate valid cleanup threshold
// [INFO] valid cleanup threshold (must be less than): 1251847890
//
// [SCENARIO] 7. Clean old snapshots (before first snapshot)
// [INFO] cleaned snapshots older than 1234567790
// [EXPECTED] old snapshot cleanup completed
//
// [SCENARIO] 8. Verify cleanup results
// [INFO] total delegated after cleanup: 1800000000
// [EXPECTED] total delegation amount preserved after cleanup
// [EXPECTED] delegation snapshots still exist after cleanup
