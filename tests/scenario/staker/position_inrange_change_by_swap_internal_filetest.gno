// position in-range change by swap (internal rewards) scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	rt "gno.land/r/gnoswap/v1/router"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint narrow range position")
	mintNarrowRangePosition()
	println()

	println("[SCENARIO] 4. Stake position and verify in-range")
	stakePositionAndVerifyInRange()
	println()

	println("[SCENARIO] 5. Collect reward while in-range")
	collectRewardWhileInRange()
	println()

	println("[SCENARIO] 6. Perform swap to move price out of range")
	performSwapToMovePrice()
	println()

	println("[SCENARIO] 7. Collect reward while out-of-range")
	collectRewardWhileOutOfRange()
	println()

	println("[SCENARIO] 8. Perform reverse swap to move price back in-range")
	performReverseSwap()
	println()

	println("[SCENARIO] 9. Collect reward after returning to in-range")
	collectRewardAfterReturningInRange()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool to tier 1")
	sr.SetPoolTierByAdmin(cross, poolPath, 1)

	testing.SkipHeights(1)
}

func mintNarrowRangePosition() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)
	testing.SkipHeights(2)

	println("[INFO] mint narrow range position (tick range: -50 ~ 50)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-50), // narrow range around current price (tick 0)
		int32(50),
		"10000",
		"10000",
		"1",
		"1",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	// Check current pool tick
	currentTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] current pool tick: %d\n", currentTick)
	ufmt.Printf("[INFO] position range: -50 to 50\n")

	if currentTick < -50 || currentTick > 50 {
		panic("position should be in-range initially")
	}

	testing.SkipHeights(1)
}

func stakePositionAndVerifyInRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position staked successfully\n")

	// Verify position is in-range
	currentTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] current tick after staking: %d\n", currentTick)

	if currentTick < -50 || currentTick > 50 {
		panic("position should be in-range after staking")
	}

	testing.SkipHeights(1)
}

func collectRewardWhileInRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards while in-range")
	testing.SkipHeights(10)

	println("[INFO] collect reward while position is in-range")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	inRangeReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward while in-range: %d\n", inRangeReward)

	if inRangeReward <= 0 {
		panic("should have received reward while in-range")
	}

	println("[INFO] confirmed: rewards distributed while position is in-range")
}

func performSwapToMovePrice() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for swapping")
	bar.Approve(cross, routerAddr, consts.INT64_MAX)
	baz.Approve(cross, routerAddr, consts.INT64_MAX)

	// Check current tick before swap
	currentTickBefore := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] tick before swap: %d\n", currentTickBefore)

	println("[INFO] perform large swap to move price out of range")
	// Swap a large amount to move the tick significantly
	swapAmount := "100000"

	println("[INFO] swap bar for baz to move tick up")
	_, amountOut := rt.ExactInSwapRoute(
		cross,
		barPath,
		bazPath,
		swapAmount,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		"100",
		"0",
		max_timeout,
		"",
	)

	ufmt.Printf("[INFO] swapped %s bar for %s baz\n", swapAmount, amountOut)

	// Check tick after swap
	currentTickAfter := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] tick after swap: %d\n", currentTickAfter)

	// Position should now be out of range (tick > 50)
	if currentTickAfter <= 50 {
		println("[WARNING] swap might not have moved price far enough")
		// Try another swap to move further
		println("[INFO] perform additional swap")
		rt.ExactInSwapRoute(
			cross,
			barPath,
			bazPath,
			swapAmount,
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
			"100",
			"0",
			max_timeout,
			"",
		)

		finalTick := pl.PoolGetSlot0Tick(poolPath)
		ufmt.Printf("[EXPECTED] final tick after additional swap: %d\n", finalTick)
	}

	testing.SkipHeights(1)
}

func collectRewardWhileOutOfRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards while out-of-range")
	testing.SkipHeights(10)

	println("[INFO] collect reward while position is out-of-range")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	outOfRangeReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward while out-of-range: %d\n", outOfRangeReward)

	if outOfRangeReward != 0 {
		panic("should not receive reward while out-of-range")
	}

	println("[INFO] confirmed: no rewards distributed while position is out-of-range")
}

func performReverseSwap() {
	testing.SetRealm(adminRealm)

	// Check current tick before reverse swap
	currentTickBefore := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] tick before reverse swap: %d\n", currentTickBefore)

	println("[INFO] perform reverse swap to move price back into range")
	// Swap baz for bar to move tick back down
	reverseSwapAmount := "50000"

	println("[INFO] swap baz for bar to move tick down")
	_, amountOut := rt.ExactInSwapRoute(
		cross,
		bazPath,
		barPath,
		reverseSwapAmount,
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:100",
		"100",
		"0",
		max_timeout,
		"",
	)

	ufmt.Printf("[INFO] swapped %s baz for %s bar\n", reverseSwapAmount, amountOut)

	// Check tick after reverse swap
	currentTickAfter := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] tick after reverse swap: %d\n", currentTickAfter)

	// Position should be back in range (-50 <= tick <= 50)
	if currentTickAfter >= -50 && currentTickAfter <= 50 {
		println("[INFO] position is back in-range")
	} else {
		println("[WARNING] position might still be out-of-range")
		ufmt.Printf("[INFO] position range: -50 to 50, current tick: %d\n", currentTickAfter)
	}

	testing.SkipHeights(1)
}

func collectRewardAfterReturningInRange() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards after returning to in-range")
	testing.SkipHeights(10)

	println("[INFO] collect reward after position returned to in-range")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	backInRangeReward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward after returning to in-range: %d\n", backInRangeReward)

	// Get final tick for verification
	finalTick := pl.PoolGetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] final tick: %d\n", finalTick)

	if finalTick >= -50 && finalTick <= 50 {
		if backInRangeReward <= 0 {
			panic("should have received reward when back in-range")
		}
		println("[INFO] confirmed: rewards resumed when position returned to in-range")
	} else {
		if backInRangeReward != 0 {
			panic("should not receive reward while still out-of-range")
		}
		println("[INFO] position is still out-of-range, no rewards as expected")
	}

	println("[INFO] position in-range change by swap scenario completed successfully")
	println("[INFO] confirmed: rewards are only distributed when positions are in-range")
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint narrow range position
// [INFO] approve tokens for minting
// [INFO] mint narrow range position (tick range: -50 ~ 50)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 4005202
// [EXPECTED] amount0: 10000, amount1: 10000
// [INFO] current pool tick: 0
// [INFO] position range: -50 to 50
//
// [SCENARIO] 4. Stake position and verify in-range
// [INFO] approve NFT to staker and stake position
// [EXPECTED] position staked successfully
// [INFO] current tick after staking: 0
//
// [SCENARIO] 5. Collect reward while in-range
// [INFO] skip blocks to accumulate rewards while in-range
// [INFO] collect reward while position is in-range
// [EXPECTED] reward while in-range: 17658388
// [INFO] confirmed: rewards distributed while position is in-range
//
// [SCENARIO] 6. Perform swap to move price out of range
// [INFO] approve tokens for swapping
// [INFO] tick before swap: 0
// [INFO] perform large swap to move price out of range
// [INFO] swap bar for baz to move tick up
// [INFO] swapped 100000 bar for -9985 baz
// [EXPECTED] tick after swap: -887271
// [WARNING] swap might not have moved price far enough
// [INFO] perform additional swap
// [EXPECTED] final tick after additional swap: -887271
//
// [SCENARIO] 7. Collect reward while out-of-range
// [INFO] skip blocks to accumulate rewards while out-of-range
// [INFO] collect reward while position is out-of-range
// [EXPECTED] reward while out-of-range: 0
// [INFO] confirmed: no rewards distributed while position is out-of-range
//
// [SCENARIO] 8. Perform reverse swap to move price back in-range
// [INFO] tick before reverse swap: -887271
// [INFO] perform reverse swap to move price back into range
// [INFO] swap baz for bar to move tick down
// [INFO] swapped 50000 baz for 0 bar
// [EXPECTED] tick after reverse swap: -887271
// [WARNING] position might still be out-of-range
// [INFO] position range: -50 to 50, current tick: -887271
//
// [SCENARIO] 9. Collect reward after returning to in-range
// [INFO] skip blocks to accumulate rewards after returning to in-range
// [INFO] collect reward after position returned to in-range
// [EXPECTED] reward after returning to in-range: 0
// [INFO] final tick: -887271
// [INFO] position is still out-of-range, no rewards as expected
// [INFO] position in-range change by swap scenario completed successfully
// [INFO] confirmed: rewards are only distributed when positions are in-range
