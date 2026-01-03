// Verify GetUnclaimedFee calculation consistency
// This test validates that GetUnclaimedFee returns the same result as
// the internal calculateTokensOwed logic used in decreaseLiquidity

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"

	Q128 string = "340282366920938463463374607431768211456"
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main() {
	ufmt.Println("[SCENARIO] GetUnclaimedFee Calculation Consistency Test")
	ufmt.Println("Testing multiple position scenarios to ensure API consistency")
	println()

	ufmt.Println("[STEP 1] Initialize pool")
	initPool()
	println()

	ufmt.Println("=== SCENARIO 1: Full-range position ===")
	testFullRangePosition()
	println()

	ufmt.Println("=== SCENARIO 2: Out-of-range position (below current tick) ===")
	testOutOfRangeBelowPosition()
	println()

	ufmt.Println("=== SCENARIO 3: Out-of-range position (above current tick) ===")
	testOutOfRangeAbovePosition()
	println()

	ufmt.Println("=== SCENARIO 4: Narrow range position ===")
	testNarrowRangePosition()
	println()

	ufmt.Println("[SUMMARY] All scenarios passed ✓")
}

func testFullRangePosition() {
	ufmt.Println("[STEP 2.1] Mint full-range position")
	positionId := mintFullRangePosition()

	ufmt.Println("[STEP 2.2] Execute swaps to generate fees")
	executeSwaps()

	ufmt.Println("[STEP 2.3] Validate GetUnclaimedFee matches manual calculation")
	validateGetUnclaimedFee(positionId, "Full-range")
}

func testOutOfRangeBelowPosition() {
	ufmt.Println("[STEP 3.1] Mint out-of-range position (below current tick)")
	positionId := mintOutOfRangeBelowPosition()

	ufmt.Println("[STEP 3.2] Execute swaps (position is out-of-range)")
	executeSwaps()

	ufmt.Println("[STEP 3.3] Validate fees (should be zero or minimal)")
	validateGetUnclaimedFee(positionId, "Out-of-range below")
}

func testOutOfRangeAbovePosition() {
	ufmt.Println("[STEP 4.1] Mint out-of-range position (above current tick)")
	positionId := mintOutOfRangeAbovePosition()

	ufmt.Println("[STEP 4.2] Execute swaps (position is out-of-range)")
	executeSwaps()

	ufmt.Println("[STEP 4.3] Validate fees (should be zero or minimal)")
	validateGetUnclaimedFee(positionId, "Out-of-range above")
}

func testNarrowRangePosition() {
	ufmt.Println("[STEP 5.1] Mint narrow range position")
	positionId := mintNarrowRangePosition()

	ufmt.Println("[STEP 5.2] Execute swaps within range")
	executeSmallSwaps()

	ufmt.Println("[STEP 5.3] Validate GetUnclaimedFee consistency")
	validateGetUnclaimedFee(positionId, "Narrow range")
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	ufmt.Println("[INFO] Creating pool with initial price")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"79228162514264337593543950336", // sqrt(1) * 2^96
	)
}

func mintFullRangePosition() uint64 {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting full-range position (-887270 to 887270)")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-887270, // Full range
		887270,
		"100000000",
		"100000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[RESULT] Position ID: %d, Amount0: %s, Amount1: %s\n", positionId, amount0, amount1)
	return positionId
}

func mintOutOfRangeBelowPosition() uint64 {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting out-of-range position below current tick (-100000 to -50000)")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-100000, // Below current tick (0)
		-50000,
		"100000000",
		"100000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[RESULT] Position ID: %d, Amount0: %s, Amount1: %s\n", positionId, amount0, amount1)
	return positionId
}

func mintOutOfRangeAbovePosition() uint64 {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting out-of-range position above current tick (50000 to 100000)")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		50000, // Above current tick (0)
		100000,
		"100000000",
		"100000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[RESULT] Position ID: %d, Amount0: %s, Amount1: %s\n", positionId, amount0, amount1)
	return positionId
}

func mintNarrowRangePosition() uint64 {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting narrow range position (-10000 to 10000)")
	positionId, _, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-10000, // Narrow range around current tick
		10000,
		"100000000",
		"100000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[RESULT] Position ID: %d, Amount0: %s, Amount1: %s\n", positionId, amount0, amount1)
	return positionId
}

func executeSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)

	// First swap: ZeroForOne
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing swap ZeroForOne")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"10000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[RESULT] Swap ZeroForOne: amount0=%s, amount1=%s\n", amount0, amount1)

	// Second swap: OneForZero
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, INT64_MAX)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	amount0, amount1 = pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"10000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[RESULT] Swap OneForZero: amount0=%s, amount1=%s\n", amount0, amount1)
}

func executeSmallSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	// Smaller swaps to stay within narrow range
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing small swap ZeroForOne")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[RESULT] Small swap ZeroForOne: amount0=%s, amount1=%s\n", amount0, amount1)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	amount0, amount1 = pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"1000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[RESULT] Small swap OneForZero: amount0=%s, amount1=%s\n", amount0, amount1)
}

func validateGetUnclaimedFee(positionId uint64, scenarioName string) {
	testing.SetRealm(adminRealm)

	ufmt.Printf("[%s] Validating position %d\n", scenarioName, positionId)

	// Method 1: GetUnclaimedFee (api.gno approach)
	fee0FromApi, fee1FromApi := position.GetUnclaimedFee(positionId)
	ufmt.Printf("[METHOD 1] GetUnclaimedFee: Fee0=%s, Fee1=%s\n", fee0FromApi.ToString(), fee1FromApi.ToString())

	// Method 2: Manual calculation using same logic as decreaseLiquidity/calculateTokensOwed
	posData, exists := position.GetPosition(positionId)
	if !exists {
		ufmt.Println("[ERROR] Position not found")
		return
	}
	poolKey := posData.PoolKey()
	tickLower := posData.TickLower()
	tickUpper := posData.TickUpper()
	liquidity := posData.Liquidity()
	feeGrowthInside0LastX128 := posData.FeeGrowthInside0LastX128()
	feeGrowthInside1LastX128 := posData.FeeGrowthInside1LastX128()

	// Get current feeGrowthInside from pool (same as decreaseLiquidity does)
	positionKey := computePositionKey(tickLower, tickUpper)
	currentFeeGrowthInside0X128, currentFeeGrowthInside1X128 := pool.GetPositionFeeGrowthInsideLastX128(poolKey, positionKey)

	// Calculate fees manually using the same formula as calculateTokensOwed
	diff0 := subUint256(currentFeeGrowthInside0X128, feeGrowthInside0LastX128)
	expectedFee0 := u256.MulDiv(diff0, liquidity, u256.MustFromDecimal(Q128))

	diff1 := subUint256(currentFeeGrowthInside1X128, feeGrowthInside1LastX128)
	expectedFee1 := u256.MulDiv(diff1, liquidity, u256.MustFromDecimal(Q128))

	ufmt.Printf("[METHOD 2] Manual Calc: Fee0=%s, Fee1=%s\n", expectedFee0.ToString(), expectedFee1.ToString())

	// Validate both methods match
	if fee0FromApi.ToString() == expectedFee0.ToString() && fee1FromApi.ToString() == expectedFee1.ToString() {
		ufmt.Printf("[%s] ✓ Both methods match\n", scenarioName)
	} else {
		ufmt.Printf("[%s] ✗ MISMATCH DETECTED!\n", scenarioName)
		ufmt.Printf("[ERROR] Fee0: API=%s vs Manual=%s\n", fee0FromApi.ToString(), expectedFee0.ToString())
		ufmt.Printf("[ERROR] Fee1: API=%s vs Manual=%s\n", fee1FromApi.ToString(), expectedFee1.ToString())
	}
}

func computePositionKey(tickLower int32, tickUpper int32) string {
	return ufmt.Sprintf("%d:%d", tickLower, tickUpper)
}

func subUint256(x, y *u256.Uint) *u256.Uint {
	if x.Cmp(y) < 0 {
		maxUint256 := u256.MustFromDecimal("115792089237316195423570985008687907853269984665640564039457584007913129639935")
		diff := u256.Zero().Sub(maxUint256, y)
		result := u256.Zero().Add(diff, x)
		return result.Add(result, u256.One())
	}

	return u256.Zero().Sub(x, y)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] GetUnclaimedFee Calculation Consistency Test
// Testing multiple position scenarios to ensure API consistency
//
// [STEP 1] Initialize pool
// [INFO] Creating pool with initial price
//
// === SCENARIO 1: Full-range position ===
// [STEP 2.1] Mint full-range position
// [INFO] Minting full-range position (-887270 to 887270)
// [RESULT] Position ID: 1, Amount0: 100000000, Amount1: 100000000
// [STEP 2.2] Execute swaps to generate fees
// [INFO] Executing swap ZeroForOne
// [RESULT] Swap ZeroForOne: amount0=10000, amount1=-9950
// [INFO] Executing swap OneForZero
// [RESULT] Swap OneForZero: amount0=-9950, amount1=10000
// [STEP 2.3] Validate GetUnclaimedFee matches manual calculation
// [Full-range] Validating position 1
// [METHOD 1] GetUnclaimedFee: Fee0=5, Fee1=5
// [METHOD 2] Manual Calc: Fee0=5, Fee1=5
// [Full-range] ✓ Both methods match
//
// === SCENARIO 2: Out-of-range position (below current tick) ===
// [STEP 3.1] Mint out-of-range position (below current tick)
// [INFO] Minting out-of-range position below current tick (-100000 to -50000)
// [RESULT] Position ID: 2, Amount0: 0, Amount1: 100000000
// [STEP 3.2] Execute swaps (position is out-of-range)
// [INFO] Executing swap ZeroForOne
// [RESULT] Swap ZeroForOne: amount0=10000, amount1=-9901
// [INFO] Executing swap OneForZero
// [RESULT] Swap OneForZero: amount0=-9901, amount1=10000
// [STEP 3.3] Validate fees (should be zero or minimal)
// [Out-of-range below] Validating position 2
// [METHOD 1] GetUnclaimedFee: Fee0=0, Fee1=0
// [METHOD 2] Manual Calc: Fee0=0, Fee1=0
// [Out-of-range below] ✓ Both methods match
//
// === SCENARIO 3: Out-of-range position (above current tick) ===
// [STEP 4.1] Mint out-of-range position (above current tick)
// [INFO] Minting out-of-range position above current tick (50000 to 100000)
// [RESULT] Position ID: 3, Amount0: 100000000, Amount1: 0
// [STEP 4.2] Execute swaps (position is out-of-range)
// [INFO] Executing swap ZeroForOne
// [RESULT] Swap ZeroForOne: amount0=10000, amount1=-9851
// [INFO] Executing swap OneForZero
// [RESULT] Swap OneForZero: amount0=-9851, amount1=10000
// [STEP 4.3] Validate fees (should be zero or minimal)
// [Out-of-range above] Validating position 3
// [METHOD 1] GetUnclaimedFee: Fee0=0, Fee1=0
// [METHOD 2] Manual Calc: Fee0=0, Fee1=0
// [Out-of-range above] ✓ Both methods match
//
// === SCENARIO 4: Narrow range position ===
// [STEP 5.1] Mint narrow range position
// [INFO] Minting narrow range position (-10000 to 10000)
// [RESULT] Position ID: 4, Amount0: 100000000, Amount1: 100000000
// [STEP 5.2] Execute swaps within range
// [INFO] Executing small swap ZeroForOne
// [RESULT] Small swap ZeroForOne: amount0=1000, amount1=-995
// [INFO] Executing small swap OneForZero
// [RESULT] Small swap OneForZero: amount0=-995, amount1=1000
// [STEP 5.3] Validate GetUnclaimedFee consistency
// [Narrow range] Validating position 4
// [METHOD 1] GetUnclaimedFee: Fee0=0, Fee1=0
// [METHOD 2] Manual Calc: Fee0=0, Fee1=0
// [Narrow range] ✓ Both methods match
//
// [SUMMARY] All scenarios passed ✓
