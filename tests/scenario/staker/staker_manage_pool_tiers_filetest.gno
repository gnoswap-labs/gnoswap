// staker manage pool tiers scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee100 uint32 = 100
	fee500 uint32 = 500
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create pools")
	createPools()
	println()

	println("[SCENARIO] 3. Set pool tier by admin")
	setPoolTierByAdmin()
	println()

	println("[SCENARIO] 4. Change pool tier by admin")
	changePoolTierByAdmin()
	println()

	println("[SCENARIO] 5. Set another pool to tier 3")
	setAnotherPoolTier3()
	println()

	println("[SCENARIO] 6. Remove pool tier by admin")
	removePoolTierByAdmin()
}

func initAccountAndEmission() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPools() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*2)
	testing.SkipHeights(1)

	println("[INFO] create bar:foo:500 pool")
	pl.CreatePool(cross, barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(-10000).ToString())

	println("[INFO] create bar:foo:100 pool")
	pl.CreatePool(cross, barPath, fooPath, 100, common.TickMathGetSqrtRatioAtTick(-10000).ToString())

	testing.SkipHeights(1)
}

func setPoolTierByAdmin() {
	testing.SetRealm(adminRealm)

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	targetTier := uint64(2)

	println("[INFO] set pool tier to 2")
	sr.SetPoolTierByAdmin(cross, poolPath, targetTier)

	// Verify the tier was set correctly
	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier set to: %d\n", currentTier)

	if currentTier != targetTier {
		panic("pool tier not set correctly")
	}
}

func changePoolTierByAdmin() {
	testing.SetRealm(adminRealm)

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
	newTier := uint64(3)

	println("[INFO] change pool tier from 2 to 3")
	sr.SetPoolTierByAdmin(cross, poolPath, newTier)

	// Verify the tier was changed correctly
	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier changed to: %d\n", currentTier)

	if currentTier != newTier {
		panic("pool tier not changed correctly")
	}
}

func setAnotherPoolTier3() {
	testing.SetRealm(adminRealm)

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100"
	targetTier := uint64(3)

	println("[INFO] set another pool (bar:foo:100) to tier 3")
	sr.SetPoolTierByAdmin(cross, poolPath, targetTier)

	// Verify the tier was set correctly
	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] second pool tier set to: %d\n", currentTier)

	if currentTier != targetTier {
		panic("second pool tier not set correctly")
	}
}

func removePoolTierByAdmin() {
	testing.SetRealm(adminRealm)

	poolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	println("[INFO] remove pool tier (set to 0)")
	sr.RemovePoolTierByAdmin(cross, poolPath)

	// Verify the tier was removed (should be 0)
	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier removed (should be 0): %d\n", currentTier)

	if currentTier != 0 {
		panic("pool tier not removed correctly")
	}

	// Verify the other pool still has its tier
	otherPoolPath := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100"
	otherTier := sr.GetPoolTier(otherPoolPath)
	ufmt.Printf("[EXPECTED] other pool tier unchanged: %d\n", otherTier)

	if otherTier != 3 {
		panic("other pool tier was affected unexpectedly")
	}
}

// Output:
// [SCENARIO] 1. Initialize account and emission
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pools
// [INFO] approve gns for pool creation
// [INFO] create bar:foo:500 pool
// [INFO] create bar:foo:100 pool
//
// [SCENARIO] 3. Set pool tier by admin
// [INFO] set pool tier to 2
// [EXPECTED] pool tier set to: 2
//
// [SCENARIO] 4. Change pool tier by admin
// [INFO] change pool tier from 2 to 3
// [EXPECTED] pool tier changed to: 3
//
// [SCENARIO] 5. Set another pool to tier 3
// [INFO] set another pool (bar:foo:100) to tier 3
// [EXPECTED] second pool tier set to: 3
//
// [SCENARIO] 6. Remove pool tier by admin
// [INFO] remove pool tier (set to 0)
// [EXPECTED] pool tier removed (should be 0): 0
// [EXPECTED] other pool tier unchanged: 3 