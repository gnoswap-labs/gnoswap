// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	maxApprove int64 = 9223372036854775806
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())

	poolCreationFee int64 = 100_000_000
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

var (
	fee500 = uint32(500)
)

func main() {
	println("[SCENARIO] Tick Cross Oracle Field Update")
	println("[INFO] Testing oracle field updates during tick crosses")
	println()

	// Setup: Create pool
	println("[SCENARIO] 1. Pool Creation and Setup")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, poolCreationFee)

	println("[INFO] Creating bar-foo pool (fee: 500, initial tick: 0)")
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	println("[INFO] Increasing observation cardinality to 100")
	pool.IncreaseObservationCardinalityNext(cross, barPath, fooPath, fee500, 100)
	println()

	// Add liquidity - wide range to allow crossing multiple times
	println("[SCENARIO] 2. Add Liquidity")
	testing.SetRealm(posRealm)
	println("[INFO] Minting position: tick range [-1000, 1000] for wide liquidity coverage")
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		"10000000",
		adminAddr,
	)
	println("[EXPECTED] Position created with amounts:", amount0, amount1)

	// Check initial pool state
	thisPool, _ := pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Initial pool tick:", thisPool.Slot0Tick())
	println("[INFO] Pool liquidity:", thisPool.Liquidity().ToString())
	println()

	// Get initial tick state before swap
	// Note: With fee500, tick spacing is 10, so we test tick -1000 (lower bound of liquidity)
	println("[SCENARIO] 3. Check Initial Tick State")
	poolPath := barPath + ":" + fooPath + ":" + ufmt.Sprintf("%d", fee500)
	testTick := int32(-1000) // Lower bound of liquidity position
	tickInfo, _ := pool.GetTickInfo(poolPath, testTick)
	ufmt.Printf("[INFO] Tick %d initial state:\n", testTick)
	println("[INFO] Initialized:", tickInfo.Initialized())
	println("[INFO] TickCumulativeOutside:", tickInfo.TickCumulativeOutside())
	println("[INFO] SecondsOutside:", tickInfo.SecondsOutside())
	if tickInfo.SecondsPerLiquidityOutsideX128() != nil {
		println("[INFO] SecondsPerLiquidityOutsideX128:", tickInfo.SecondsPerLiquidityOutsideX128().ToString())
	} else {
		println("[INFO] SecondsPerLiquidityOutsideX128: nil")
	}
	println()

	// Wait some time for oracle values to accumulate
	println("[SCENARIO] 4. Wait for Time to Pass")
	println("[INFO] Skipping 100 blocks to accumulate oracle values")
	testing.SkipHeights(100)
	println()

	// Perform swap to cross testTick
	println("[SCENARIO] 5. Perform Swap to Cross Tick (Downward)")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Printf("[INFO] Swapping zeroForOne to cross tick %d\n", testTick)

	// Need to approve tokens for swap
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)

	// Perform swap - zeroForOne (true) to decrease tick past testTick
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	amount0Out, amount1Out := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true, // zeroForOne - tick decreases (0 -> past testTick)
		"10000000", // large amount to ensure we cross testTick
		common.TickMathGetSqrtRatioAtTick(testTick - 100).ToString(), // target past testTick
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)
	println("[EXPECTED] Swap completed with amounts:", amount0Out, amount1Out)

	// Check current pool tick to confirm we crossed testTick
	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool tick after swap:", thisPool.Slot0Tick())
	println()

	// Check tick state after swap (oracle fields should be updated)
	println("[SCENARIO] 6. Check Tick State After Cross")
	tickInfoAfter, _ := pool.GetTickInfo(poolPath, testTick)
	ufmt.Printf("[INFO] Tick %d after cross:\n", testTick)
	println("[INFO] Initialized:", tickInfoAfter.Initialized())
	println("[EXPECTED] TickCumulativeOutside updated:", tickInfoAfter.TickCumulativeOutside())
	println("[EXPECTED] SecondsOutside updated:", tickInfoAfter.SecondsOutside())

	// The key validation: oracle fields should now be set and non-zero
	if tickInfoAfter.SecondsPerLiquidityOutsideX128() != nil {
		println("[EXPECTED] SecondsPerLiquidityOutsideX128 is set:", tickInfoAfter.SecondsPerLiquidityOutsideX128().ToString())

		// Verify it's different from initial state
		if tickInfoAfter.SecondsPerLiquidityOutsideX128().Gt(u256.Zero()) {
			println("[EXPECTED] Oracle field successfully updated (non-zero)")
		}
	} else {
		println("[ERROR] SecondsPerLiquidityOutsideX128 still nil after tick cross")
	}
	println()

	// Wait more time before second cross
	println("[SCENARIO] 7. Wait for More Time")
	println("[INFO] Skipping another 100 blocks")
	testing.SkipHeights(100)
	println()

	// Add more liquidity to allow second cross
	println("[SCENARIO] 7.5. Add Liquidity Outside Current Range")
	testing.SetRealm(posRealm)
	println("[INFO] Adding position [-2000, 2000] to provide liquidity for reverse swap")
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-2000,
		2000,
		"10000000",
		adminAddr,
	)
	println()

	// Cross tick again to verify oracle fields flip
	println("[SCENARIO] 8. Cross Tick Again (Reverse Direction - Upward)")
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Printf("[INFO] Swapping oneForZero to cross back above tick %d\n", testTick)

	// Approve foo tokens for reverse swap
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	amount0Out2, amount1Out2 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false, // oneForZero - tick increases (back above testTick)
		"10000000", // large amount to ensure crossing back
		common.TickMathGetSqrtRatioAtTick(1000).ToString(), // back to upper bound
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)
	println("[EXPECTED] Reverse swap completed:", amount0Out2, amount1Out2)

	// Check current pool tick after reverse swap
	thisPool, _ = pool.GetPool(barPath, fooPath, fee500)
	println("[INFO] Pool tick after reverse swap:", thisPool.Slot0Tick())
	println()

	// Check tick state after second cross
	println("[SCENARIO] 9. Verify Oracle Fields After Second Cross")
	tickInfoFinal, _ := pool.GetTickInfo(poolPath, testTick)
	ufmt.Printf("[INFO] Tick %d after second cross:\n", testTick)
	println("[EXPECTED] TickCumulativeOutside changed:", tickInfoFinal.TickCumulativeOutside())
	println("[EXPECTED] SecondsOutside changed:", tickInfoFinal.SecondsOutside())

	if tickInfoFinal.SecondsPerLiquidityOutsideX128() != nil {
		println("[EXPECTED] SecondsPerLiquidityOutsideX128 updated again:", tickInfoFinal.SecondsPerLiquidityOutsideX128().ToString())

		// Values should be different from first cross
		if tickInfoFinal.SecondsPerLiquidityOutsideX128().Neq(tickInfoAfter.SecondsPerLiquidityOutsideX128()) {
			println("[EXPECTED] Oracle field values changed on second cross")
		}
	}
	println()

	println("[SCENARIO] Test Complete - Oracle Fields Update on Tick Cross")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Tick Cross Oracle Field Update
// [INFO] Testing oracle field updates during tick crosses
//
// [SCENARIO] 1. Pool Creation and Setup
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 500, initial tick: 0)
// [INFO] Approving tokens for pool operations
// [INFO] Increasing observation cardinality to 100
//
// [SCENARIO] 2. Add Liquidity
// [INFO] Minting position: tick range [-1000, 1000] for wide liquidity coverage
// [EXPECTED] Position created with amounts: 487682 487682
// [INFO] Initial pool tick: 0
// [INFO] Pool liquidity: 10000000
//
// [SCENARIO] 3. Check Initial Tick State
// [INFO] Tick -1000 initial state:
// [INFO] Initialized: true
// [INFO] TickCumulativeOutside: 0
// [INFO] SecondsOutside: 0
// [INFO] SecondsPerLiquidityOutsideX128: 0
//
// [SCENARIO] 4. Wait for Time to Pass
// [INFO] Skipping 100 blocks to accumulate oracle values
//
// [SCENARIO] 5. Perform Swap to Cross Tick (Downward)
// [INFO] Swapping zeroForOne to cross tick -1000
// [EXPECTED] Swap completed with amounts: 512942 -487681
// [INFO] Pool tick after swap: -1100
//
// [SCENARIO] 6. Check Tick State After Cross
// [INFO] Tick -1000 after cross:
// [INFO] Initialized: true
// [EXPECTED] TickCumulativeOutside updated: -500
// [EXPECTED] SecondsOutside updated: 1234568390
// [EXPECTED] SecondsPerLiquidityOutsideX128 is set: 17014118346046923173168730371588410
// [EXPECTED] Oracle field successfully updated (non-zero)
//
// [SCENARIO] 7. Wait for More Time
// [INFO] Skipping another 100 blocks
//
// [SCENARIO] 7.5. Add Liquidity Outside Current Range
// [INFO] Adding position [-2000, 2000] to provide liquidity for reverse swap
//
// [SCENARIO] 8. Cross Tick Again (Reverse Direction - Upward)
// [INFO] Swapping oneForZero to cross back above tick -1000
// [EXPECTED] Reverse swap completed: -2053424 2049200
// [INFO] Pool tick after reverse swap: 1000
//
// [SCENARIO] 9. Verify Oracle Fields After Second Cross
// [INFO] Tick -1000 after second cross:
// [EXPECTED] TickCumulativeOutside changed: -549500
// [EXPECTED] SecondsOutside changed: 500
// [EXPECTED] SecondsPerLiquidityOutsideX128 updated again: 170141183460469231731687303715884105728000
// [EXPECTED] Oracle field values changed on second cross
//
// [SCENARIO] Test Complete - Oracle Fields Update on Tick Cross
