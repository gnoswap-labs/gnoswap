// PKGPATH: gno.land/r/demo/main

package main

import (
	"fmt"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/pool"

	_ "gno.land/r/gnoswap/pool/v1"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	fooPath  = "gno.land/r/onbloc/foo"
	barPath  = "gno.land/r/onbloc/bar"
	poolPath = fmt.Sprintf("%s:%s:%d", barPath, fooPath, FeeTier500)
)

// Test variables
var (
	tickLower       = int32(-10000)
	tickUpper       = int32(10000)
	liquidityExpect = "100000000000"

	MIN_PRICE string = "4295128740"
)

// DrySwap Test - ZeroForOne True with Positive Amount Specified
// Testing DrySwap functionality with zeroForOne=true and amountSpecified=16000
// Expected behavior: Calculate swap amounts without executing the actual swap
func main() {
	println("[SCENARIO] 1. Create pool and mint position")
	createPoolAndMintPosition(t)
	println()

	println("[SCENARIO] 2. DrySwap Test - ZeroForOne True with Positive Amount Specified")
	printChanges(poolPath, func() {
		drySwap(t, true, "30000000000")
	})
	println()

	println("[SCENARIO] 3. DrySwap With Cross Test - ZeroForOne True with Positive Amount Specified")
	printChanges(poolPath, func() {
		drySwapWithCross(t, true, "30000000000")
	})
	println()

	println("[SCENARIO] 4. Swap Test - ZeroForOne True with Positive Amount Specified")
	printChanges(poolPath, func() {
		swap(t, true, "30000000000")
	})
}

func createPoolAndMintPosition(t *testing.T) {
	testing.SetRealm(adminRealm)

	println("[INFO] Creating pool")

	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		FeeTier500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	println("[EXPECTED] Token0:", barPath)
	println("[EXPECTED] Token1:", fooPath)
	println("[EXPECTED] Fee tier:", FeeTier500)
	println("[EXPECTED] Initial liquidity amount:", liquidityExpect)
	println("[EXPECTED] Tick range:", tickLower, "to", tickUpper)

	// Approve tokens for minting
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	println()
	println("[INFO] Minting position")

	// Mint position
	testing.SetRealm(posRealm)
	mintAmount0, mintAmount1 := pool.Mint(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		tickLower,
		tickUpper,
		liquidityExpect,
		adminAddr,
	)

	println("[EXPECTED] Minted amount0:", mintAmount0)
	println("[EXPECTED] Minted amount1:", mintAmount1)
	println("[EXPECTED] Position minted successfully")

	pool.Mint(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		-100,
		100,
		"1000",
		adminAddr,
	)
}

// drySwap tests DrySwap with zeroForOne=true and positive amountSpecified
func drySwap(t *testing.T, zeroForOne bool, amountSpecified string) {
	// When: Perform DrySwap with zeroForOne=true and positive amountSpecified
	println("[INFO] Performing DrySwap with zeroForOne=true")
	println("[INFO] Amount specified:", amountSpecified)

	poolIn, poolOut, _ := pool.DrySwap(
		barPath,
		fooPath,
		FeeTier500,
		true, // zeroForOne
		amountSpecified,
		MIN_PRICE,
	)

	println("[EXPECTED] Actual pool input amount:", poolIn)
	println("[EXPECTED] Actual pool output amount:", poolOut)
}

// drySwapWithCross tests DrySwap with zeroForOne=true and positive amountSpecified with cross
func drySwapWithCross(t *testing.T, zeroForOne bool, amountSpecified string) {
	// When: Perform DrySwap with zeroForOne=true and positive amountSpecified
	println("[INFO] Performing DrySwap with zeroForOne=true")
	println("[INFO] Amount specified:", amountSpecified)

	var poolIn, poolOut string

	func(cur realm) {
		poolIn, poolOut, _ = pool.DrySwap(
			barPath,
			fooPath,
			FeeTier500,
			true, // zeroForOne
			amountSpecified,
			MIN_PRICE,
		)
	}(cross)

	println("[EXPECTED] Actual pool input amount:", poolIn)
	println("[EXPECTED] Actual pool output amount:", poolOut)
}

// swap tests Swap with zeroForOne=true and positive amountSpecified
func swap(t *testing.T, zeroForOne bool, amountSpecified string) {
	println("[INFO] Performing Swap with zeroForOne=true")
	println("[INFO] Amount specified:", amountSpecified)

	var poolIn, poolOut string

	testing.SetRealm(adminRealm)

	swapCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(adminAddr))

			// Transfer token0 if needed
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(cross, barPath, poolAddr, amount0Delta)
			}

			// Transfer token1 if needed
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(cross, fooPath, poolAddr, amount1Delta)
			}
		}(cross)

		return nil
	}

	func(cur realm) {
		const mockSwapperPath = "gno.land/r/gnoswap/test/mock_swapper"

		testing.SetRealm(testing.NewCodeRealm(mockSwapperPath))
		poolIn, poolOut = pool.Swap(
			cross,
			barPath,
			fooPath,
			FeeTier500,
			adminAddr,
			zeroForOne,
			amountSpecified,
			MIN_PRICE,
			adminAddr,
			swapCallback,
		)
	}(cross)

	println("[EXPECTED] Actual pool input amount:", poolIn)
	println("[EXPECTED] Actual pool output amount:", poolOut)
}

func printChanges(poolPath string, fn func()) {
	previousTick := pool.GetSlot0Tick(poolPath)
	previousBalance0, previousBalance1 := pool.GetBalances(poolPath)
	previousFeeGrowthGlobal0X128, previousFeeGrowthGlobal1X128 := pool.GetFeeGrowthGlobalX128(poolPath)
	positionKey := pool.EncodePositionKey(tickLower, tickUpper)
	previousPositionFeeGrowthInside0LastX128, previousPositionFeeGrowthInside1LastX128 := pool.GetPositionFeeGrowthInsideLastX128(poolPath, positionKey)
	previousPositionLiquidity := pool.GetPositionLiquidity(poolPath, positionKey)

	expectedTick := int32(-100)
	previousTickInfo, _ := pool.GetTickInfo(poolPath, previousTick)
	previousResultTickCumulativeOutside := previousTickInfo.TickCumulativeOutside()
	previousResultTickFeeGrowthOutside0X128 := previousTickInfo.FeeGrowthOutside0X128()
	previousResultTickFeeGrowthOutside1X128 := previousTickInfo.FeeGrowthOutside1X128()

	fn()

	currentTick := pool.GetSlot0Tick(poolPath)
	currentBalance0, currentBalance1 := pool.GetBalances(poolPath)
	currentFeeGrowthGlobal0X128, currentFeeGrowthGlobal1X128 := pool.GetFeeGrowthGlobalX128(poolPath)
	currentPositionFeeGrowthInside0LastX128, currentPositionFeeGrowthInside1LastX128 := pool.GetPositionFeeGrowthInsideLastX128(poolPath, positionKey)
	currentPositionLiquidity := pool.GetPositionLiquidity(poolPath, positionKey)
	expectedTickInfo, _ := pool.GetTickInfo(poolPath, expectedTick)
	expectedResultTickCumulativeOutside := expectedTickInfo.TickCumulativeOutside()
	expectedResultTickFeeGrowthOutside0X128 := expectedTickInfo.FeeGrowthOutside0X128()
	expectedResultTickFeeGrowthOutside1X128 := expectedTickInfo.FeeGrowthOutside1X128()

	println("[EXPECTED] Tick changed from:", previousTick, "to:", currentTick)
	println("[EXPECTED] Balance0 changed from:", previousBalance0, "to:", currentBalance0)
	println("[EXPECTED] Balance1 changed from:", previousBalance1, "to:", currentBalance1)
	println("[EXPECTED] Fee growth global0X128 changed from:", previousFeeGrowthGlobal0X128, "to:", currentFeeGrowthGlobal0X128)
	println("[EXPECTED] Fee growth global1X128 changed from:", previousFeeGrowthGlobal1X128, "to:", currentFeeGrowthGlobal1X128)
	println("[EXPECTED] Position fee growth inside0LastX128 changed from:", previousPositionFeeGrowthInside0LastX128, "to:", currentPositionFeeGrowthInside0LastX128)
	println("[EXPECTED] Position fee growth inside1LastX128 changed from:", previousPositionFeeGrowthInside1LastX128, "to:", currentPositionFeeGrowthInside1LastX128)
	println("[EXPECTED] Position liquidity changed from:", previousPositionLiquidity, "to:", currentPositionLiquidity)
	println("[EXPECTED] Result tick cumulative outside changed from:", previousResultTickCumulativeOutside, "to:", expectedResultTickCumulativeOutside)
	println("[EXPECTED] Result tick fee growth outside0X128 changed from:", previousResultTickFeeGrowthOutside0X128, "to:", expectedResultTickFeeGrowthOutside0X128)
	println("[EXPECTED] Result tick fee growth outside1X128 changed from:", previousResultTickFeeGrowthOutside1X128, "to:", expectedResultTickFeeGrowthOutside1X128)
}

// Output:
// [SCENARIO] 1. Create pool and mint position
// [INFO] Creating pool
// [EXPECTED] Token0: gno.land/r/onbloc/bar
// [EXPECTED] Token1: gno.land/r/onbloc/foo
// [EXPECTED] Fee tier: 500
// [EXPECTED] Initial liquidity amount: 100000000000
// [EXPECTED] Tick range: -10000 to 10000
//
// [INFO] Minting position
// [EXPECTED] Minted amount0: 39345417785
// [EXPECTED] Minted amount1: 39345417785
// [EXPECTED] Position minted successfully
//
// [SCENARIO] 2. DrySwap Test - ZeroForOne True with Positive Amount Specified
// [INFO] Performing DrySwap with zeroForOne=true
// [INFO] Amount specified: 30000000000
// [EXPECTED] Actual pool input amount: 30000000000
// [EXPECTED] Actual pool output amount: -23068046312
// [EXPECTED] Tick changed from: 0 to: 0
// [EXPECTED] Balance0 changed from: 39345417790 to: 39345417790
// [EXPECTED] Balance1 changed from: 39345417790 to: 39345417790
// [EXPECTED] Fee growth global0X128 changed from: 0 to: 0
// [EXPECTED] Fee growth global1X128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside0LastX128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside1LastX128 changed from: 0 to: 0
// [EXPECTED] Position liquidity changed from: 100000000000 to: 100000000000
// [EXPECTED] Result tick cumulative outside changed from: 0 to: 0
// [EXPECTED] Result tick fee growth outside0X128 changed from:  to: 0
// [EXPECTED] Result tick fee growth outside1X128 changed from:  to: 0
//
// [SCENARIO] 3. DrySwap With Cross Test - ZeroForOne True with Positive Amount Specified
// [INFO] Performing DrySwap with zeroForOne=true
// [INFO] Amount specified: 30000000000
// [EXPECTED] Actual pool input amount: 30000000000
// [EXPECTED] Actual pool output amount: -23068046312
// [EXPECTED] Tick changed from: 0 to: 0
// [EXPECTED] Balance0 changed from: 39345417790 to: 39345417790
// [EXPECTED] Balance1 changed from: 39345417790 to: 39345417790
// [EXPECTED] Fee growth global0X128 changed from: 0 to: 0
// [EXPECTED] Fee growth global1X128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside0LastX128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside1LastX128 changed from: 0 to: 0
// [EXPECTED] Position liquidity changed from: 100000000000 to: 100000000000
// [EXPECTED] Result tick cumulative outside changed from: 0 to: 0
// [EXPECTED] Result tick fee growth outside0X128 changed from:  to: 0
// [EXPECTED] Result tick fee growth outside1X128 changed from:  to: 0
//
// [SCENARIO] 4. Swap Test - ZeroForOne True with Positive Amount Specified
// [INFO] Performing Swap with zeroForOne=true
// [INFO] Amount specified: 30000000000
// [EXPECTED] Actual pool input amount: 30000000000
// [EXPECTED] Actual pool output amount: -23068046312
// [EXPECTED] Tick changed from: 0 to: -5246
// [EXPECTED] Balance0 changed from: 39345417790 to: 69345417790
// [EXPECTED] Balance1 changed from: 39345417790 to: 16277371478
// [EXPECTED] Fee growth global0X128 changed from: 0 to: 51042358432432232774273966355645589
// [EXPECTED] Fee growth global1X128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside0LastX128 changed from: 0 to: 0
// [EXPECTED] Position fee growth inside1LastX128 changed from: 0 to: 0
// [EXPECTED] Position liquidity changed from: 100000000000 to: 100000000000
// [EXPECTED] Result tick cumulative outside changed from: 0 to: 0
// [EXPECTED] Result tick fee growth outside0X128 changed from:  to: 853220595461685939286571464062626
// [EXPECTED] Result tick fee growth outside1X128 changed from:  to: 0
