// Staker contract upgrade scenario test
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/staker"

	_ "gno.land/r/gnoswap/staker/v1"
	_ "gno.land/r/gnoswap/staker/v2_invalid"
)

var t = &testing.T{}

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
)

const (
	stakerV1Path   = "gno.land/r/gnoswap/staker/v1"
	stakerTestPath = "gno.land/r/gnoswap/staker/v2_invalid"
)

func main() {
	println("[SCENARIO] 1. Initialize staker contract with v1")
	initializeV1()
	println()

	println("[SCENARIO] 2. Upgrade staker contract to test version")
	testStakerUpgrade()
	println()

	println("[SCENARIO] 3. Verify test implementation panics correctly")
	verifyTestImplementation()
	println()
}

func initializeV1() {
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current implementation: %s\n", currentVersion)

	if currentVersion != stakerV1Path {
		ufmt.Println("[INFO] Setting implementation to v1")
		testing.SetRealm(adminRealm)
		staker.UpgradeImpl(cross, stakerV1Path)
		currentVersion = staker.GetImplementationPackagePath()
	}

	ufmt.Printf("[EXPECTED] Staker initialized with v1: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}
}

func testStakerUpgrade() {
	// Verify current version is v1
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != stakerV1Path {
		panic(ufmt.Sprintf("Expected v1, got %s", currentVersion))
	}

	// Upgrade to test version
	ufmt.Println("[INFO] Upgrading staker contract to test version")
	testing.SetRealm(adminRealm)
	staker.UpgradeImpl(cross, stakerTestPath)

	currentVersion = staker.GetImplementationPackagePath()
	ufmt.Printf("[EXPECTED] Staker upgraded to: %s\n", currentVersion)
	if currentVersion != stakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}
}

func verifyTestImplementation() {
	// Verify current version is test version
	currentVersion := staker.GetImplementationPackagePath()
	ufmt.Printf("[INFO] Current version: %s\n", currentVersion)
	if currentVersion != stakerTestPath {
		panic(ufmt.Sprintf("Expected test version, got %s", currentVersion))
	}

	// Test StakeToken - should panic with test implementation message
	ufmt.Println("[INFO] Testing StakeToken function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: StakeToken not supported", func() {
		staker.StakeToken(cross, 1, "")
	})
	ufmt.Println("[EXPECTED] StakeToken panics correctly")

	// Test SetPoolTier - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetPoolTier function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetPoolTier not supported", func() {
		staker.SetPoolTier(cross, "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", 1)
	})
	ufmt.Println("[EXPECTED] SetPoolTier panics correctly")

	// Test AddToken - should panic with test implementation message
	ufmt.Println("[INFO] Testing AddToken function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: AddToken not supported", func() {
		staker.AddToken(cross, "gno.land/r/onbloc/foo")
	})
	ufmt.Println("[EXPECTED] AddToken panics correctly")

	// Test UnStakeToken - should panic with test implementation message
	ufmt.Println("[INFO] Testing UnStakeToken function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: UnStakeToken not supported", func() {
		staker.UnStakeToken(cross, 1, false)
	})
	ufmt.Println("[EXPECTED] UnStakeToken panics correctly")

	// Test CollectReward - should panic with test implementation message
	ufmt.Println("[INFO] Testing CollectReward function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: CollectReward not supported", func() {
		staker.CollectReward(cross, 1, false)
	})
	ufmt.Println("[EXPECTED] CollectReward panics correctly")

	// Test ChangePoolTier - should panic with test implementation message
	ufmt.Println("[INFO] Testing ChangePoolTier function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: ChangePoolTier not supported", func() {
		staker.ChangePoolTier(cross, "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500", 2)
	})
	ufmt.Println("[EXPECTED] ChangePoolTier panics correctly")

	// Test RemovePoolTier - should panic with test implementation message
	ufmt.Println("[INFO] Testing RemovePoolTier function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: RemovePoolTier not supported", func() {
		staker.RemovePoolTier(cross, "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500")
	})
	ufmt.Println("[EXPECTED] RemovePoolTier panics correctly")

	// Test RemoveToken - should panic with test implementation message
	ufmt.Println("[INFO] Testing RemoveToken function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: RemoveToken not supported", func() {
		staker.RemoveToken(cross, "gno.land/r/onbloc/foo")
	})
	ufmt.Println("[EXPECTED] RemoveToken panics correctly")

	// Test SetUnStakingFee - should panic with test implementation message
	ufmt.Println("[INFO] Testing SetUnStakingFee function panics correctly")
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, "test implementation: SetUnStakingFee not supported", func() {
		staker.SetUnStakingFee(cross, 100)
	})
	ufmt.Println("[EXPECTED] SetUnStakingFee panics correctly")
}

// Output:
// [SCENARIO] 1. Initialize staker contract with v1
// [INFO] Current implementation: gno.land/r/gnoswap/staker/v1
// [EXPECTED] Staker initialized with v1: gno.land/r/gnoswap/staker/v1
//
// [SCENARIO] 2. Upgrade staker contract to test version
// [INFO] Current version: gno.land/r/gnoswap/staker/v1
// [INFO] Upgrading staker contract to test version
// [EXPECTED] Staker upgraded to: gno.land/r/gnoswap/staker/v2_invalid
//
// [SCENARIO] 3. Verify test implementation panics correctly
// [INFO] Current version: gno.land/r/gnoswap/staker/v2_invalid
// [INFO] Testing StakeToken function panics correctly
// [EXPECTED] StakeToken panics correctly
// [INFO] Testing SetPoolTier function panics correctly
// [EXPECTED] SetPoolTier panics correctly
// [INFO] Testing AddToken function panics correctly
// [EXPECTED] AddToken panics correctly
// [INFO] Testing UnStakeToken function panics correctly
// [EXPECTED] UnStakeToken panics correctly
// [INFO] Testing CollectReward function panics correctly
// [EXPECTED] CollectReward panics correctly
// [INFO] Testing ChangePoolTier function panics correctly
// [EXPECTED] ChangePoolTier panics correctly
// [INFO] Testing RemovePoolTier function panics correctly
// [EXPECTED] RemovePoolTier panics correctly
// [INFO] Testing RemoveToken function panics correctly
// [EXPECTED] RemoveToken panics correctly
// [INFO] Testing SetUnStakingFee function panics correctly
// [EXPECTED] SetUnStakingFee panics correctly
