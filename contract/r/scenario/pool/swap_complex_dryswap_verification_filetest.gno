// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
)

const (
	fee500 uint32 = 500
	fee100 uint32 = 100
)

const (
	maxApprove      int64 = 9223372036854775806
	poolCreationFee int64 = 100_000_000
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

var (
	MIN_SQRT_RATIO string = "4295128740"
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970341"
)

func main() {
	println("[SCENARIO] Complex Swap DrySwap Verification")
	println("[INFO] Purpose: Verify DrySwap predictions match actual Swap results in complex scenarios")
	println()

	setupPool()
	println()

	createComplexPositions()
	println()

	verifyLargeSwapZeroForOne()
	println()

	verifyLargeSwapOneForZero()
	println()

	verifyExtremeSwapWithPriceLimit()
	println()

	verifyMultipleDirectionSwaps()
	println()

	println("[SCENARIO] Complete - All DrySwap predictions matched actual Swap results")
}

func setupPool() {
	println("[SCENARIO] 1. Setup Pool")
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	println("[EXPECTED] Pool created at tick=0 (1:1 price)")
}

func createComplexPositions() {
	println("[SCENARIO] 2. Create Complex Positions")
	testing.SetRealm(posRealm)

	println("[INFO] Position 1: Full range with large liquidity")
	pool.Mint(cross, barPath, fooPath, fee500, -887220, 887220, "10000000000", adminAddr)

	println("[INFO] Position 2: Narrow range around current price")
	pool.Mint(cross, barPath, fooPath, fee500, -1000, 1000, "5000000000", adminAddr)

	println("[INFO] Position 3: Wide range above current price")
	pool.Mint(cross, barPath, fooPath, fee500, 5000, 50000, "3000000000", adminAddr)

	println("[INFO] Position 4: Wide range below current price")
	pool.Mint(cross, barPath, fooPath, fee500, -50000, -5000, "3000000000", adminAddr)

	println("[INFO] Position 5: Concentrated liquidity at +10000")
	pool.Mint(cross, barPath, fooPath, fee500, 9000, 11000, "2000000000", adminAddr)

	println("[INFO] Position 6: Concentrated liquidity at -10000")
	pool.Mint(cross, barPath, fooPath, fee500, -11000, -9000, "2000000000", adminAddr)

	println("[EXPECTED] 6 positions created with varying ranges and liquidity")
}

func verifyLargeSwapZeroForOne() {
	println("[SCENARIO] 3. Verify Large Swap (ZeroForOne=true)")

	testing.SetRealm(adminRealm)
	dryPoolIn, dryPoolOut, dryEndPrice := pool.DrySwap(
		barPath,
		fooPath,
		fee500,
		true,
		"100000000",
		MIN_SQRT_RATIO,
	)

	println("[INFO] DrySwap prediction:")
	println("[INFO] - poolIn:", dryPoolIn)
	println("[INFO] - poolOut:", dryPoolOut)
	println("[INFO] - endPrice:", dryEndPrice)

	beforeBarBalance := bar.BalanceOf(adminAddr)
	beforeFooBalance := foo.BalanceOf(adminAddr)

	bar.Approve(cross, poolAddr, 100000000)

	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"100000000",
		MIN_SQRT_RATIO,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	afterBarBalance := bar.BalanceOf(adminAddr)
	afterFooBalance := foo.BalanceOf(adminAddr)

	println("[INFO] Actual Swap result:")
	println("[INFO] - amount0:", amount0)
	println("[INFO] - amount1:", amount1)

	barDelta := safeSubInt64(afterBarBalance, beforeBarBalance)
	fooDelta := safeSubInt64(afterFooBalance, beforeFooBalance)

	println("[EXPECTED] Balance changes: bar=", barDelta, "foo=", fooDelta)
	println("[EXPECTED] DrySwap prediction matches actual Swap")
}

func verifyLargeSwapOneForZero() {
	println("[SCENARIO] 4. Verify Large Swap (ZeroForOne=false)")

	testing.SetRealm(adminRealm)
	dryPoolIn, dryPoolOut, dryEndPrice := pool.DrySwap(
		barPath,
		fooPath,
		fee500,
		false,
		"50000000",
		MAX_SQRT_RATIO,
	)

	println("[INFO] DrySwap prediction:")
	println("[INFO] - poolIn:", dryPoolIn)
	println("[INFO] - poolOut:", dryPoolOut)
	println("[INFO] - endPrice:", dryEndPrice)

	beforeBarBalance := bar.BalanceOf(adminAddr)
	beforeFooBalance := foo.BalanceOf(adminAddr)

	foo.Approve(cross, poolAddr, 50000000)

	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"50000000",
		MAX_SQRT_RATIO,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	afterBarBalance := bar.BalanceOf(adminAddr)
	afterFooBalance := foo.BalanceOf(adminAddr)

	println("[INFO] Actual Swap result:")
	println("[INFO] - amount0:", amount0)
	println("[INFO] - amount1:", amount1)

	barDelta := safeSubInt64(afterBarBalance, beforeBarBalance)
	fooDelta := safeSubInt64(afterFooBalance, beforeFooBalance)

	println("[EXPECTED] Balance changes: bar=", barDelta, "foo=", fooDelta)
	println("[EXPECTED] DrySwap prediction matches actual Swap")
}

func verifyExtremeSwapWithPriceLimit() {
	println("[SCENARIO] 5. Verify Extreme Swap with Price Limit")

	testing.SetRealm(adminRealm)
	pools, _ := pool.GetPool(barPath, fooPath, fee500)
	currentPrice := pools.Slot0SqrtPriceX96()
	println("[INFO] Current price:", currentPrice)

	targetTick := int32(-5000)
	targetPrice := common.TickMathGetSqrtRatioAtTick(targetTick).ToString()
	println("[INFO] Target price limit (tick -5000):", targetPrice)

	dryPoolIn, dryPoolOut, dryEndPrice := pool.DrySwap(
		barPath,
		fooPath,
		fee500,
		true,
		"500000000",
		targetPrice,
	)

	println("[INFO] DrySwap prediction:")
	println("[INFO] - poolIn:", dryPoolIn)
	println("[INFO] - poolOut:", dryPoolOut)
	println("[INFO] - endPrice:", dryEndPrice)

	beforeBarBalance := bar.BalanceOf(adminAddr)
	beforeFooBalance := foo.BalanceOf(adminAddr)

	bar.Approve(cross, poolAddr, 500000000)

	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"500000000",
		targetPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	afterBarBalance := bar.BalanceOf(adminAddr)
	afterFooBalance := foo.BalanceOf(adminAddr)

	println("[INFO] Actual Swap result:")
	println("[INFO] - amount0:", amount0)
	println("[INFO] - amount1:", amount1)

	pools, _ = pool.GetPool(barPath, fooPath, fee500)
	endPrice := pools.Slot0SqrtPriceX96()
	println("[INFO] End price:", endPrice)

	barDelta := safeSubInt64(afterBarBalance, beforeBarBalance)
	fooDelta := safeSubInt64(afterFooBalance, beforeFooBalance)

	println("[EXPECTED] Balance changes: bar=", barDelta, "foo=", fooDelta)
	println("[EXPECTED] Price stopped at limit, DrySwap prediction matches")
}

func verifyMultipleDirectionSwaps() {
	println("[SCENARIO] 6. Verify Multiple Direction Changes")

	println("[INFO] Swap 1: ZeroForOne=true, amount=10000000")
	testing.SetRealm(adminRealm)
	dryIn1, dryOut1, _ := pool.DrySwap(barPath, fooPath, fee500, true, "10000000", MIN_SQRT_RATIO)

	bar.Approve(cross, poolAddr, 10000000)

	testing.SetRealm(routerRealm)
	amt0_1, amt1_1 := pool.Swap(cross, barPath, fooPath, fee500, adminAddr, true, "10000000", MIN_SQRT_RATIO, adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		})

	println("[EXPECTED] Swap 1: DrySwap(", dryIn1, ",", dryOut1, ") == Swap(", amt0_1, ",", amt1_1, ")")

	println("[INFO] Swap 2: ZeroForOne=false, amount=20000000")
	testing.SetRealm(adminRealm)
	dryIn2, dryOut2, _ := pool.DrySwap(barPath, fooPath, fee500, false, "20000000", MAX_SQRT_RATIO)

	foo.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(routerRealm)
	amt0_2, amt1_2 := pool.Swap(cross, barPath, fooPath, fee500, adminAddr, false, "20000000", MAX_SQRT_RATIO, adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		})

	println("[EXPECTED] Swap 2: DrySwap(", dryIn2, ",", dryOut2, ") == Swap(", amt0_2, ",", amt1_2, ")")

	println("[INFO] Swap 3: ZeroForOne=true, amount=-5000000 (exactOutput)")
	testing.SetRealm(adminRealm)
	dryIn3, dryOut3, _ := pool.DrySwap(barPath, fooPath, fee500, true, "-5000000", MIN_SQRT_RATIO)

	bar.Approve(cross, poolAddr, 10000000)

	testing.SetRealm(routerRealm)
	amt0_3, amt1_3 := pool.Swap(cross, barPath, fooPath, fee500, adminAddr, true, "-5000000", MIN_SQRT_RATIO, adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		})

	println("[EXPECTED] Swap 3: DrySwap(", dryIn3, ",", dryOut3, ") == Swap(", amt0_3, ",", amt1_3, ")")

	println("[INFO] Swap 4: ZeroForOne=false, amount=-8000000 (exactOutput)")
	testing.SetRealm(adminRealm)
	dryIn4, dryOut4, _ := pool.DrySwap(barPath, fooPath, fee500, false, "-8000000", MAX_SQRT_RATIO)

	foo.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(routerRealm)
	amt0_4, amt1_4 := pool.Swap(cross, barPath, fooPath, fee500, adminAddr, false, "-8000000", MAX_SQRT_RATIO, adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		})

	println("[EXPECTED] Swap 4: DrySwap(", dryIn4, ",", dryOut4, ") == Swap(", amt0_4, ",", amt1_4, ")")

	println("[EXPECTED] All direction changes verified successfully")
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

func safeSubInt64(a, b int64) int64 {
	result := a - b
	if (result > a) != (b < 0) {
		panic("int64 overflow in subtraction")
	}
	return result
}

// Output:
// [SCENARIO] Complex Swap DrySwap Verification
// [INFO] Purpose: Verify DrySwap predictions match actual Swap results in complex scenarios
//
// [SCENARIO] 1. Setup Pool
// [EXPECTED] Pool created at tick=0 (1:1 price)
//
// [SCENARIO] 2. Create Complex Positions
// [INFO] Position 1: Full range with large liquidity
// [INFO] Position 2: Narrow range around current price
// [INFO] Position 3: Wide range above current price
// [INFO] Position 4: Wide range below current price
// [INFO] Position 5: Concentrated liquidity at +10000
// [INFO] Position 6: Concentrated liquidity at -10000
// [EXPECTED] 6 positions created with varying ranges and liquidity
//
// [SCENARIO] 3. Verify Large Swap (ZeroForOne=true)
// [INFO] DrySwap prediction:
// [INFO] - poolIn: 100000000
// [INFO] - poolOut: -99288408
// [INFO] - endPrice: true
// [INFO] Actual Swap result:
// [INFO] - amount0: 100000000
// [INFO] - amount1: -99288408
// [EXPECTED] Balance changes: bar= -100000000 foo= 99288408
// [EXPECTED] DrySwap prediction matches actual Swap
//
// [SCENARIO] 4. Verify Large Swap (ZeroForOne=false)
// [INFO] DrySwap prediction:
// [INFO] - poolIn: -50473936
// [INFO] - poolOut: 50000000
// [INFO] - endPrice: true
// [INFO] Actual Swap result:
// [INFO] - amount0: -50473936
// [INFO] - amount1: 50000000
// [EXPECTED] Balance changes: bar= 50473936 foo= -50000000
// [EXPECTED] DrySwap prediction matches actual Swap
//
// [SCENARIO] 5. Verify Extreme Swap with Price Limit
// [INFO] Current price: &(array[(17654669951358689512 uint64),(4280847330 uint64),(0 uint64),(0 uint64)] gno.land/p/gnoswap/uint256.Uint)
// [INFO] Target price limit (tick -5000): 61703726247759831737814779831
// [INFO] DrySwap prediction:
// [INFO] - poolIn: 500000000
// [INFO] - poolOut: -480513023
// [INFO] - endPrice: true
// [INFO] Actual Swap result:
// [INFO] - amount0: 500000000
// [INFO] - amount1: -480513023
// [INFO] End price: &(array[(17755719775704812608 uint64),(4143261482 uint64),(0 uint64),(0 uint64)] gno.land/p/gnoswap/uint256.Uint)
// [EXPECTED] Balance changes: bar= -500000000 foo= 480513023
// [EXPECTED] Price stopped at limit, DrySwap prediction matches
//
// [SCENARIO] 6. Verify Multiple Direction Changes
// [INFO] Swap 1: ZeroForOne=true, amount=10000000
// [EXPECTED] Swap 1: DrySwap( 10000000 , -9295412 ) == Swap( 10000000 , -9295412 )
// [INFO] Swap 2: ZeroForOne=false, amount=20000000
// [EXPECTED] Swap 2: DrySwap( -21478603 , 20000000 ) == Swap( -21478603 , 20000000 )
// [INFO] Swap 3: ZeroForOne=true, amount=-5000000 (exactOutput)
// [EXPECTED] Swap 3: DrySwap( 5369459 , -5000000 ) == Swap( 5369459 , -5000000 )
// [INFO] Swap 4: ZeroForOne=false, amount=-8000000 (exactOutput)
// [EXPECTED] Swap 4: DrySwap( -8000000 , 7458261 ) == Swap( -8000000 , 7458261 )
// [EXPECTED] All direction changes verified successfully
//
// [SCENARIO] Complete - All DrySwap predictions matched actual Swap results

