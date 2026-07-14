// PKGPATH: gno.land/r/gnoswap/v1/main

// Test file to verify unstaking works after tier removal
// This test demonstrates the bug where positions CANNOT be unstaked from pools that have been de-tiered

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	_ "gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main(cur realm) {
	println("=== TEST: Unstaking After Tier Removal ===")
	println()
	println("This test demonstrates a critical bug where users cannot unstake")
	println("positions from pools that have been removed from the tier system.")
	println()

	println("[STEP 1] Initialize and setup")
	initAndSetup(cur)

	println("[STEP 2] Create pool and set to tier 2")
	createPoolAndSetTier(cur)

	println("[STEP 3] Mint and stake position")
	positionId := mintAndStakePosition(cur)

	println("[STEP 4] Verify position is staked")
	verifyStaked(cur, positionId)

	println("[STEP 5] Remove pool from tier system")
	removePoolTier(cur)

	println("[STEP 6] Attempt to unstake position after tier removal")
	attemptUnstake(cur, positionId)

	println("[STEP 7] Verify unstaking was successful")
	verifyUnstaked(cur, positionId)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	// Set unstaking fee to 0
	sr.SetUnStakingFee(cross(cur), 0)

	// Set pool creation fee to 0
	pl.SetPoolCreationFee(cross(cur), 0)

	testing.SkipHeights(1)
	println("[INFO] Initialized")
}

func createPoolAndSetTier(cur realm) {
	testing.SetRealm(adminRealm)

	// Create pool
	pl.CreatePool(cross(cur), barPath, bazPath, fee3000, "79228162514264337593543950337")

	// Set pool to tier 2
	sr.SetPoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)

	tier := sr.GetPoolTier("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000")
	ufmt.Printf("[INFO] Pool created and set to tier %d\n", tier)

	testing.SkipHeights(1)
}

func mintAndStakePosition(cur realm) uint64 {
	testing.SetRealm(adminRealm)

	// Approve tokens
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	// Mint position
	// fee3000 has tick spacing of 60, so ticks must be multiples of 60
	positionId, liquidity, _, _ := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee3000,
		int32(-1020), // -1020 is divisible by 60
		int32(1020),  // 1020 is divisible by 60
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	ufmt.Printf("[INFO] Minted position %d with liquidity %s\n", positionId, liquidity)

	// Approve and stake
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId))
	sr.StakeToken(cross(cur), positionId, "")

	println("[INFO] Position staked")
	testing.SkipHeights(1)

	return positionId
}

func verifyStaked(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	isStaked := sr.IsStaked(positionId)
	ufmt.Printf("[INFO] Position %d staked status: %v\n", positionId, isStaked)

	if !isStaked {
		panic("Position should be staked")
	}
}

func removePoolTier(cur realm) {
	testing.SetRealm(adminRealm)

	println("Removing pool from tier system...")
	sr.RemovePoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000")

	tier := sr.GetPoolTier("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000")
	ufmt.Printf("[INFO] Pool tier after removal: %d (0 means no tier)\n", tier)

	if tier != 0 {
		panic("Pool should have no tier after removal")
	}

	testing.SkipHeights(1)
}

// This should now work after the fix
func attemptUnstake(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	println("Attempting to unstake position from de-tiered pool...")

	// This should now succeed after the fix
	poolPath := sr.UnStakeToken(cross(cur), positionId)

	println("[INFO] poolPath: ", poolPath)

	println()
	println("=== BUG FIXED ===")
	println("Users CAN NOW unstake positions from pools that have been removed from the tier system.")
}

func verifyUnstaked(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)
	isStaked := sr.IsStaked(positionId)
	ufmt.Printf("[INFO] Position %d staked status after unstaking: %v\n", positionId, isStaked)

	if isStaked {
		panic("Position should not be staked after unstaking")
	}

	// Verify NFT ownership returned to user
	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil {
		panic(err)
	}

	if owner != adminUser {
		panic(ufmt.Sprintf("NFT should be owned by admin after unstaking, but owned by %s", owner))
	}

	println("[INFO] NFT ownership successfully returned to user")
	println()
	println("=== TEST PASSED ===")
	println("The bug has been fixed! Users can unstake from de-tiered pools.")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
	switch positionId := positionId.(type) {
	case string:
		return grc721.TokenID(positionId)
	case int:
		return grc721.TokenID(strconv.Itoa(positionId))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId)))
	case grc721.TokenID:
		return positionId
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// === TEST: Unstaking After Tier Removal ===
//
// This test demonstrates a critical bug where users cannot unstake
// positions from pools that have been removed from the tier system.
//
// [STEP 1] Initialize and setup
// [INFO] Initialized
// [STEP 2] Create pool and set to tier 2
// [INFO] Pool created and set to tier 2
// [STEP 3] Mint and stake position
// [INFO] Minted position 1 with liquidity 20113
// [INFO] Position staked
// [STEP 4] Verify position is staked
// [INFO] Position 1 staked status: true
// [STEP 5] Remove pool from tier system
// Removing pool from tier system...
// [INFO] Pool tier after removal: 0 (0 means no tier)
// [STEP 6] Attempt to unstake position after tier removal
// Attempting to unstake position from de-tiered pool...
// [INFO] poolPath:  gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000
//
// === BUG FIXED ===
// Users CAN NOW unstake positions from pools that have been removed from the tier system.
// [STEP 7] Verify unstaking was successful
// [INFO] Position 1 staked status after unstaking: false
// [INFO] NFT ownership successfully returned to user
//
// === TEST PASSED ===
// The bug has been fixed! Users can unstake from de-tiered pools.
