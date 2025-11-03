// Gov/Staker contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	govStaker "gno.land/r/gnoswap/gov/staker"

	_ "gno.land/r/gnoswap/gov/staker/test"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	govStakerV1Path   = "gno.land/r/gnoswap/gov/staker/v1"
	govStakerTestPath = "gno.land/r/gnoswap/gov/staker/test"
)

func main() {
	println("[SCENARIO] 1. Initialize gov/staker contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade gov/staker contract to test version")
	testGovStakerUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := govStaker.GetImplementationPackagePath()

	if currentVersion != govStakerV1Path {
		testing.SetRealm(adminRealm)
		govStaker.UpgradeImpl(cross, govStakerV1Path)
		currentVersion = govStaker.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Gov/Staker initialized with v1: %s\n", currentVersion)
	if currentVersion != govStakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testGovStakerUpgrade() {
	// Verify current version is v1
	currentVersion := govStaker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govStakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading gov/staker contract to test version")
	testing.SetRealm(adminRealm)
	govStaker.UpgradeImpl(cross, govStakerTestPath)

	currentVersion = govStaker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Gov/Staker upgraded to: %s\n", currentVersion)
	if currentVersion != govStakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := govStaker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != govStakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test Delegate - should panic with test implementation message
	ufmt.Println("[INFO] Testing Delegate function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Delegate not supported", func() {
		govStaker.Delegate(cross, adminAddr, 1000, "")
	})
	ufmt.Println("[EXPECTED] Delegate panics correctly")

	// Test Undelegate - should panic with test implementation message
	ufmt.Println("[INFO] Testing Undelegate function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Undelegate not supported", func() {
		govStaker.Undelegate(cross, adminAddr, 1000)
	})
	ufmt.Println("[EXPECTED] Undelegate panics correctly")

	// Test CollectReward - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectReward function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectReward not supported", func() {
		govStaker.CollectReward(cross)
	})
	ufmt.Println("[EXPECTED] CollectReward panics correctly")

	// Test Redelegate - should panic with test implementation message
	ufmt.Println("[INFO] Testing Redelegate function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: Redelegate not supported", func() {
		govStaker.Redelegate(cross, adminAddr, adminAddr, 1000)
	})
	ufmt.Println("[EXPECTED] Redelegate panics correctly")

	// Test CollectUndelegatedGns - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectUndelegatedGns function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectUndelegatedGns not supported", func() {
		govStaker.CollectUndelegatedGns(cross)
	})
	ufmt.Println("[EXPECTED] CollectUndelegatedGns panics correctly")

	// Test CollectRewardFromLaunchPad - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectRewardFromLaunchPad function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectRewardFromLaunchPad not supported", func() {
		govStaker.CollectRewardFromLaunchPad(cross, adminAddr)
	})
	ufmt.Println("[EXPECTED] CollectRewardFromLaunchPad panics correctly")

	// Test SetAmountByProjectWallet - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetAmountByProjectWallet function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetAmountByProjectWallet not supported", func() {
		govStaker.SetAmountByProjectWallet(cross, adminAddr, 1000, true)
	})
	ufmt.Println("[EXPECTED] SetAmountByProjectWallet panics correctly")

	// Test CleanStakerDelegationSnapshotByAdmin - should panic with test implementation message
	ufmt.Println("[INFO] Testing CleanStakerDelegationSnapshotByAdmin function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CleanStakerDelegationSnapshotByAdmin not supported", func() {
		govStaker.CleanStakerDelegationSnapshotByAdmin(cross, 100)
	})
	ufmt.Println("[EXPECTED] CleanStakerDelegationSnapshotByAdmin panics correctly")

	// Test SetUnDelegationLockupPeriodByAdmin - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetUnDelegationLockupPeriodByAdmin function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetUnDelegationLockupPeriodByAdmin not supported", func() {
		govStaker.SetUnDelegationLockupPeriodByAdmin(cross, 100)
	})
	ufmt.Println("[EXPECTED] SetUnDelegationLockupPeriodByAdmin panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize gov/staker contract with v1
// [EXPECTED] Gov/Staker initialized with v1: gno.land/r/gnoswap/gov/staker/v1
//
// [SCENARIO] 2. Upgrade gov/staker contract to test version
// [INFO] Current version: gno.land/r/gnoswap/gov/staker/v1
// [INFO] Upgrading gov/staker contract to test version
// [EXPECTED] Gov/Staker upgraded to: gno.land/r/gnoswap/gov/staker/test
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/gov/staker/test
// [INFO] Testing Delegate function panics correctly
// [EXPECTED] Delegate panics correctly
// [INFO] Testing Undelegate function panics correctly
// [EXPECTED] Undelegate panics correctly
// [INFO] Testing CollectReward function panics correctly
// [EXPECTED] CollectReward panics correctly
// [INFO] Testing Redelegate function panics correctly
// [EXPECTED] Redelegate panics correctly
// [INFO] Testing CollectUndelegatedGns function panics correctly
// [EXPECTED] CollectUndelegatedGns panics correctly
// [INFO] Testing CollectRewardFromLaunchPad function panics correctly
// [EXPECTED] CollectRewardFromLaunchPad panics correctly
// [INFO] Testing SetAmountByProjectWallet function panics correctly
// [EXPECTED] SetAmountByProjectWallet panics correctly
// [INFO] Testing CleanStakerDelegationSnapshotByAdmin function panics correctly
// [EXPECTED] CleanStakerDelegationSnapshotByAdmin panics correctly
// [INFO] Testing SetUnDelegationLockupPeriodByAdmin function panics correctly
// [EXPECTED] SetUnDelegationLockupPeriodByAdmin panics correctly
