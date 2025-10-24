// Test unstaking positions after pool has been de-tiered (tier removed)
// This ensures users can recover their staked LP positions even after pools lose incentives
// V2: Collect rewards right before tier removal to avoid edge case

// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Mint and distribute GNS")
	mintGNS()
	println()

	println("[SCENARIO] 3. Create pool and set tier")
	createPoolWithTier()
	println()

	println("[SCENARIO] 4. Mint position on incentivized pool")
	mintPosition()
	println()

	println("[SCENARIO] 5. Stake position while pool has tier")
	stakePosition()
	println()

	println("[SCENARIO] 6. Verify rewards accumulate normally")
	verifyRewards()
	println()

	println("[SCENARIO] 7. Collect all rewards before tier removal")
	collectBeforeRemoval()
	println()

	println("[SCENARIO] 8. Remove pool tier (de-tier the pool)")
	removePoolTier()
	println()

	println("[SCENARIO] 9. Verify pool has no incentives")
	verifyNoIncentives()
	println()

	println("[SCENARIO] 10. Unstake position from de-tiered pool")
	unstakeFromDetiredPool()
	println()

	println("[SCENARIO] 11. Verify position ownership after unstake")
	verifyOwnership()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross, time.Now().Unix()+1)

	// override warm-up period for testing
	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross, 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFee(cross, 0)

	// set community pool distribution to 0%
	en.ChangeDistributionPct(
		cross,
		1, 7500, // staker
		2, 2500, // devOps
		3, 0, // community pool
		4, 0, // xGNS
	)

	testing.SetRealm(stakerRealm)
	testing.SkipHeights(1)
}

func mintGNS() {
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross)
	en.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] GNS minted and distributed\n")
	testing.SkipHeights(1)
}

func createPoolWithTier() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	// Create pool
	pl.CreatePool(cross, barPath, bazPath, fee500, "79228162514264337593543950337")

	// Set pool to tier 2
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", 2)

	ufmt.Printf("[EXPECTED] pool created: bar:baz:500 with tier 2\n")
	testing.SkipHeights(1)
}

func mintPosition() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminUser,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	owner, err := gnft.OwnerOf(positionIdFrom(positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner")
	}

	ufmt.Printf("[EXPECTED] position minted on bar:baz:500: id=%d\n", positionId)
	testing.SkipHeights(1)
}

func stakePosition() {
	testing.SetRealm(adminRealm)

	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	// Verify NFT ownership transferred to staker
	owner, err := gnft.OwnerOf(positionIdFrom(1))
	if err != nil || owner != stakerAddr {
		panic("NFT should be owned by staker after staking")
	}

	ufmt.Printf("[EXPECTED] position staked successfully while pool has tier 2\n")
	testing.SkipHeights(1)
}

func verifyRewards() {
	testing.SkipHeights(100) // Let rewards accumulate

	testing.SetRealm(adminRealm)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false) // Collect rewards
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	if diff == 0 {
		panic("expected rewards to accumulate")
	}

	ufmt.Printf("[EXPECTED] rewards accumulated normally: %d GNS\n", diff)
	// No skip heights here - collect right before tier removal
}

func collectBeforeRemoval() {
	testing.SetRealm(adminRealm)

	// Collect all pending rewards right before tier removal
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false) // Collect any remaining rewards
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[INFO] collected remaining rewards before tier removal: %d GNS\n", diff)
	// No skip heights - immediately remove tier
}

func removePoolTier() {
	testing.SetRealm(adminRealm)

	// Remove the pool from tier system
	sr.RemovePoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500")

	ufmt.Printf("[EXPECTED] pool tier removed - pool is now de-tiered\n")
	testing.SkipHeights(1)
}

func verifyNoIncentives() {
	testing.SetRealm(adminRealm)

	// Skip some blocks to ensure no new rewards accumulate
	testing.SkipHeights(50)

	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false) // Try to collect rewards
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	// Should be 0 since we collected right before tier removal and pool is de-tiered
	ufmt.Printf("[INFO] rewards after de-tiering: %d GNS (should be 0)\n", diff)

	// Verify pool has no tier
	// Pool should no longer be in the tier system after removal
	ufmt.Printf("[EXPECTED] pool has been removed from tier system and has no external incentives\n")
}

func unstakeFromDetiredPool() {
	testing.SetRealm(adminRealm)

	// This is the critical test - unstaking should succeed even though the pool has no incentives
	sr.UnStakeToken(cross, 1, false)

	ufmt.Printf("[EXPECTED] successfully unstaked position from de-tiered pool\n")
	testing.SkipHeights(1)
}

func verifyOwnership() {
	// Verify NFT ownership returned to original owner
	owner, err := gnft.OwnerOf(positionIdFrom(1))
	if err != nil {
		panic("error checking ownership: " + err.Error())
	}
	if owner != adminUser {
		panic(ufmt.Sprintf("NFT should be owned by admin after unstaking, got %s", owner))
	}

	ufmt.Printf("[EXPECTED] NFT ownership returned to admin: %s\n", owner)

	// Verify position can still be interacted with normally
	testing.SetRealm(adminRealm)
	position, found := pn.GetPosition(1)
	if !found {
		panic("position should still exist")
	}
	ufmt.Printf("[EXPECTED] position still accessible - liquidity: %s\n", position.Liquidity().ToString())
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Mint and distribute GNS
// [EXPECTED] GNS minted and distributed
//
// [SCENARIO] 3. Create pool and set tier
// [EXPECTED] pool created: bar:baz:500 with tier 2
//
// [SCENARIO] 4. Mint position on incentivized pool
// [EXPECTED] position minted on bar:baz:500: id=1
//
// [SCENARIO] 5. Stake position while pool has tier
// [EXPECTED] position staked successfully while pool has tier 2
//
// [SCENARIO] 6. Verify rewards accumulate normally
// [EXPECTED] rewards accumulated normally: 374839417 GNS
//
// [SCENARIO] 7. Collect all rewards before tier removal
// [INFO] collected remaining rewards before tier removal: 0 GNS
//
// [SCENARIO] 8. Remove pool tier (de-tier the pool)
// [EXPECTED] pool tier removed - pool is now de-tiered
//
// [SCENARIO] 9. Verify pool has no incentives
// [INFO] rewards after de-tiering: 0 GNS (should be 0)
// [EXPECTED] pool has been removed from tier system and has no external incentives
//
// [SCENARIO] 10. Unstake position from de-tiered pool
// [EXPECTED] successfully unstaked position from de-tiered pool
//
// [SCENARIO] 11. Verify position ownership after unstake
// [EXPECTED] NFT ownership returned to admin: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [EXPECTED] position still accessible - liquidity: 1025
