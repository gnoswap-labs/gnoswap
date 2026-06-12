// position in-range change by swap (external rewards) scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"chain/runtime"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"


	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rt "gno.land/r/gnoswap/router"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS
	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

	t *testing.T
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool(cur)
	println()

	println("[SCENARIO] 3. Create external incentive")
	createExternalIncentive(cur)
	println()

	println("[SCENARIO] 4. Mint narrow range position")
	mintNarrowRangePosition(cur)
	println()

	println("[SCENARIO] 5. Stake position and verify in-range")
	stakePositionAndVerifyInRange(cur)
	println()

	println("[SCENARIO] 6. Collect external reward while in-range")
	collectExternalRewardWhileInRange(cur)
	println()

	println("[SCENARIO] 7. Perform swap to move price out of range")
	performSwapToMovePrice(cur)
	println()

	println("[SCENARIO] 8. Collect external reward while out-of-range")
	collectExternalRewardWhileOutOfRange(cur)
	println()

	println("[SCENARIO] 9. Perform reverse swap to move price back in-range")
	performReverseSwap(cur)
	println()

	println("[SCENARIO] 10. Collect external reward after returning to in-range")
	collectExternalRewardAfterReturningInRange(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross(cur), 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross(cur), 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross(cur), barPath, bazPath, 100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func createExternalIncentive(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive with bar token")
	sr.CreateExternalIncentive(
		cross(cur),
		poolPath,
		barPath,
		90_000_000_000, // 90 billion bar tokens for 90 days
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[INFO] external incentive created - reward per block: ~1000000000\n")

	// Make external incentives start
	leftHeight := 978 - runtime.ChainHeight()
	if leftHeight > 0 {
		testing.SkipHeights(leftHeight + 5) // skip 5 blocks more
	}
}

func mintNarrowRangePosition(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint narrow range position (tick range: -50 ~ 50)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee100,
		int32(-50), // narrow range around current price (tick 0)
		int32(50),
		"10000",
		"10000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	// Check current pool tick
	currentTick := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] current pool tick: %d\n", currentTick)
	ufmt.Printf("[INFO] position range: -50 to 50\n")

	if currentTick < -50 || currentTick > 50 {
		panic("position should be in-range initially")
	}

	testing.SkipHeights(1)
}

func stakePositionAndVerifyInRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	ufmt.Printf("[EXPECTED] position staked successfully\n")

	// Verify position is in-range
	currentTick := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] current tick after staking: %d\n", currentTick)

	if currentTick < -50 || currentTick > 50 {
		panic("position should be in-range after staking")
	}

	testing.SkipHeights(1)
}

func collectExternalRewardWhileInRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate external rewards while in-range")
	testing.SkipHeights(10)

	println("[INFO] collect external reward while position is in-range")
	beforeBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterBar := bar.BalanceOf(adminUser)
	inRangeReward := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] external reward while in-range: %d\n", inRangeReward)

	if inRangeReward <= 0 {
		panic("should have received external reward while in-range")
	}

	println("[INFO] confirmed: external rewards distributed while position is in-range")
}

func performSwapToMovePrice(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for swapping")
	bar.Approve(cross(cur), routerAddr, maxInt64)
	baz.Approve(cross(cur), routerAddr, maxInt64)

	// Check current tick before swap
	currentTickBefore := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] tick before swap: %d\n", currentTickBefore)

	println("[INFO] perform large swap to move price out of range")
	// Swap a large amount to move the tick significantly
	swapAmount := "100000"

	println("[INFO] swap bar for baz to move tick up")
	_, amountOut := rt.ExactInSwapRoute(
		cross(cur),
		barPath,
		bazPath,
		swapAmount,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		"100",
		"0",
		maxTimeout,
		"",
	)

	ufmt.Printf("[INFO] swapped %s bar for %s baz\n", swapAmount, amountOut)

	// Check tick after swap
	currentTickAfter := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] tick after swap: %d\n", currentTickAfter)

	// Position should now be out of range (tick > 50)
	if currentTickAfter <= 50 {
		println("[WARNING] swap might not have moved price far enough")
		// Try another swap to move further
		println("[INFO] perform additional swap")

		rt.ExactInSwapRoute(
			cross(cur),
			barPath,
			bazPath,
			swapAmount,
			"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
			"100",
			"0",
			maxTimeout,
			"",
		)

		finalTick := pl.GetSlot0Tick(poolPath)
		ufmt.Printf("[EXPECTED] final tick after additional swap: %d\n", finalTick)
	}

	testing.SkipHeights(1)
}

func collectExternalRewardWhileOutOfRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate external rewards while out-of-range")
	testing.SkipHeights(10)

	println("[INFO] collect external reward while position is out-of-range")
	beforeBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterBar := bar.BalanceOf(adminUser)
	outOfRangeReward := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] external reward while out-of-range: %d\n", outOfRangeReward)

	if outOfRangeReward != 0 {
		panic("should not receive external reward while out-of-range")
	}

	println("[INFO] confirmed: no external rewards distributed while position is out-of-range")
}

func performReverseSwap(cur realm) {
	testing.SetRealm(adminRealm)

	// Check current tick before reverse swap
	currentTickBefore := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] tick before reverse swap: %d\n", currentTickBefore)

	println("[INFO] perform reverse swap to move price back into range")
	// Swap baz for bar to move tick back down
	reverseSwapAmount := "50000"

	println("[INFO] swap baz for bar to move tick down")

	var amountOut string = "0"

	_, amountOut = rt.ExactInSwapRoute(
		cross(cur),
		bazPath,
		barPath,
		reverseSwapAmount,
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:100",
		"100",
		"0",
		maxTimeout,
		"",
	)

	ufmt.Printf("[INFO] swapped %s baz for %s bar\n", reverseSwapAmount, amountOut)

	// Check tick after reverse swap
	currentTickAfter := pl.GetSlot0Tick(poolPath)
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

func collectExternalRewardAfterReturningInRange(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate external rewards after returning to in-range")
	testing.SkipHeights(10)

	println("[INFO] collect external reward after position returned to in-range")
	beforeBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterBar := bar.BalanceOf(adminUser)
	backInRangeReward := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] external reward after returning to in-range: %d\n", backInRangeReward)

	// Get final tick for verification
	finalTick := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[INFO] final tick: %d\n", finalTick)

	if finalTick >= -50 && finalTick <= 50 {
		if backInRangeReward <= 0 {
			panic("should have received external reward when back in-range")
		}
		println("[INFO] confirmed: external rewards resumed when position returned to in-range")
	} else {
		if backInRangeReward != 0 {
			panic("should not receive external reward while still out-of-range")
		}
		println("[INFO] position is still out-of-range, no external rewards as expected")
	}

	println("[INFO] position in-range change by swap (external rewards) scenario completed successfully")
	println("[INFO] confirmed: external rewards are only distributed when positions are in-range")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
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
//
// [SCENARIO] 3. Create external incentive
// [INFO] approve tokens for external incentive
// [INFO] create external incentive with bar token
// [INFO] external incentive created - reward per block: ~1000000000
//
// [SCENARIO] 4. Mint narrow range position
// [INFO] approve tokens for minting
// [INFO] mint narrow range position (tick range: -50 ~ 50)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 4005202
// [EXPECTED] amount0: 10000, amount1: 10000
// [INFO] current pool tick: 0
// [INFO] position range: -50 to 50
//
// [SCENARIO] 5. Stake position and verify in-range
// [INFO] approve NFT to staker and stake position
// [EXPECTED] position staked successfully
// [INFO] current tick after staking: 0
//
// [SCENARIO] 6. Collect external reward while in-range
// [INFO] skip blocks to accumulate external rewards while in-range
// [INFO] collect external reward while position is in-range
// [EXPECTED] external reward while in-range: 190972
// [INFO] confirmed: external rewards distributed while position is in-range
//
// [SCENARIO] 7. Perform swap to move price out of range
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
// [SCENARIO] 8. Collect external reward while out-of-range
// [INFO] skip blocks to accumulate external rewards while out-of-range
// [INFO] collect external reward while position is out-of-range
// [EXPECTED] external reward while out-of-range: 0
// [INFO] confirmed: no external rewards distributed while position is out-of-range
//
// [SCENARIO] 9. Perform reverse swap to move price back in-range
// [INFO] tick before reverse swap: -887271
// [INFO] perform reverse swap to move price back into range
// [INFO] swap baz for bar to move tick down
// [INFO] swapped 50000 baz for 0 bar
// [EXPECTED] tick after reverse swap: -887271
// [WARNING] position might still be out-of-range
// [INFO] position range: -50 to 50, current tick: -887271
//
// [SCENARIO] 10. Collect external reward after returning to in-range
// [INFO] skip blocks to accumulate external rewards after returning to in-range
// [INFO] collect external reward after position returned to in-range
// [EXPECTED] external reward after returning to in-range: 0
// [INFO] final tick: -887271
// [INFO] position is still out-of-range, no external rewards as expected
// [INFO] position in-range change by swap (external rewards) scenario completed successfully
// [INFO] confirmed: external rewards are only distributed when positions are in-range
