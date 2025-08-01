// position reposition with low liquidity scenario
package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/pool"
	"gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = std.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = std.NewUserRealm(routerAddr)

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main() {
	ufmt.Println("[SCENARIO] Testing Reposition with Low Liquidity")
	ufmt.Println("This test demonstrates that reposition works even when liquidity is very low")
	println()

	ufmt.Println("[STEP 1] Initialize pool with tick 10000")
	initPool()
	println()

	ufmt.Println("[STEP 2] Mint minimal initial position (8000~12000)")
	mintMinimalPosition()
	println()

	ufmt.Println("[STEP 3] Execute large swap to move price significantly")
	executeLargeSwap()
	println()

	ufmt.Println("[STEP 4] Check pool state - very low liquidity")
	checkLowLiquidityState()
	println()

	ufmt.Println("[STEP 5] Decrease position liquidity to prepare for reposition")
	decreasePositionLiquidity()
	println()

	ufmt.Println("[STEP 6] Reposition to new range with low liquidity environment")
	repositionInLowLiquidity()
	println()

	ufmt.Println("[STEP 7] Verify reposition succeeded despite low liquidity")
	verifyRepositionSuccess()
	println()

	ufmt.Println("[STEP 8] Test swap in new range to confirm functionality")
	testSwapInNewRange()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	ufmt.Println("[INFO] Creating pool at tick 10000")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006", // sqrt price for tick 10000
	)
}

func mintMinimalPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting minimal position to create low liquidity scenario")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"10000000", // Much smaller than normal test
		"10000000", // Much smaller than normal test
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[RESULT] Position ID: %d\n", positionId)
	ufmt.Printf("[RESULT] Liquidity: %s (very low)\n", liquidity)
	ufmt.Printf("[RESULT] Amount0: %s\n", amount0)
	ufmt.Printf("[RESULT] Amount1: %s\n", amount1)
}

func executeLargeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)

	p := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[DEBUG] Tick before swap: %d\n", p.Slot0Tick())
	ufmt.Printf("[DEBUG] Pool liquidity: %s\n", p.Liquidity().ToString())

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Executing large swap relative to liquidity")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"2000000", // Moderate swap to avoid extreme price movement
		MIN_PRICE,
		adminAddr,
	)

	ufmt.Printf("[DEBUG] Tick after swap: %d\n", p.Slot0Tick())
	ufmt.Printf("[RESULT] Swap amount0: %s\n", amount0)
	ufmt.Printf("[RESULT] Swap amount1: %s\n", amount1)
}

func checkLowLiquidityState() {
	p := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[STATE] Current tick: %d\n", p.Slot0Tick())
	ufmt.Printf("[STATE] Pool liquidity: %s (very low)\n", p.Liquidity().ToString())
	ufmt.Printf("[STATE] Current sqrt price: %s\n", p.Slot0SqrtPriceX96())
}

func decreasePositionLiquidity() {
	testing.SetRealm(adminRealm)

	pos, _ := position.GetPosition(1)
	currentLiquidity := pos.Liquidity().ToString()

	ufmt.Printf("[INFO] Decreasing position liquidity: %s\n", currentLiquidity)

	// Collect any fees first
	position.CollectFee(cross, 1, false)

	// Decrease all liquidity
	position.DecreaseLiquidity(
		cross,
		1,
		currentLiquidity,
		"0",
		"0",
		9999999999,
		false,
	)

	ufmt.Println("[RESULT] Position liquidity decreased to 0")
}

func repositionInLowLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	p := pool.GetPool(barPath, fooPath, fee500)
	currentTick := p.Slot0Tick()

	// Calculate new range around current price
	// Ensure we don't exceed the valid tick range (-887272 to 887272)
	newTickLower := (currentTick/1000)*1000 - 2000
	newTickUpper := (currentTick/1000)*1000 + 2000

	// Clamp to valid range
	if newTickLower < -887272 {
		newTickLower = -887272
	}
	if newTickUpper > 887272 {
		newTickUpper = 887272
	}

	ufmt.Printf("[INFO] Current tick: %d\n", currentTick)
	ufmt.Printf("[INFO] Repositioning to new range: %d ~ %d\n", newTickLower, newTickUpper)
	ufmt.Println("[INFO] Current pool has very low liquidity")

	_, liquidity, tickLower, tickUpper, amount0, amount1 := position.Reposition(
		cross,
		1,
		newTickLower,
		newTickUpper,
		"20000000", // New liquidity amount
		"20000000",
		"0",
		"0",
	)

	ufmt.Printf("[RESULT] Reposition successful!\n")
	ufmt.Printf("[RESULT] New liquidity: %s\n", liquidity)
	ufmt.Printf("[RESULT] New range: %d ~ %d\n", tickLower, tickUpper)
	ufmt.Printf("[RESULT] Amount0 used: %s\n", amount0)
	ufmt.Printf("[RESULT] Amount1 used: %s\n", amount1)
}

func verifyRepositionSuccess() {
	testing.SetRealm(adminRealm)
	pos, _ := position.GetPosition(1)

	ufmt.Println("[VERIFY] Position after reposition:")
	ufmt.Printf("  - Liquidity: %s\n", pos.Liquidity().ToString())
	ufmt.Printf("  - TickLower: %d\n", pos.TickLower())
	ufmt.Printf("  - TickUpper: %d\n", pos.TickUpper())

	p := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[VERIFY] Pool liquidity after reposition: %s\n", p.Liquidity().ToString())
}

func testSwapInNewRange() {
	testing.SetRealm(adminRealm)
	foo.Approve(cross, poolAddr, INT64_MAX)

	p := pool.GetPool(barPath, fooPath, fee500)
	ufmt.Printf("[DEBUG] Tick before test swap: %d\n", p.Slot0Tick())

	testing.SetRealm(routerRealm)
	ufmt.Println("[INFO] Testing swap in new range")
	amount0, amount1 := pool.Swap(
		cross,
		fooPath,
		barPath,
		fee500,
		adminAddr,
		false,
		"1000000", // Small swap to test
		MAX_PRICE,
		adminAddr,
	)

	ufmt.Printf("[RESULT] Test swap successful!\n")
	ufmt.Printf("[RESULT] Swap amount0: %s\n", amount0)
	ufmt.Printf("[RESULT] Swap amount1: %s\n", amount1)
	ufmt.Printf("[DEBUG] Tick after test swap: %d\n", p.Slot0Tick())
}

// Output:
// [SCENARIO] Testing Reposition with Low Liquidity
// This test demonstrates that reposition works even when liquidity is very low
//
// [STEP 1] Initialize pool with tick 10000
// [INFO] Creating pool at tick 10000
//
// [STEP 2] Mint minimal initial position (8000~12000)
// [INFO] Minting minimal position to create low liquidity scenario
// [RESULT] Position ID: 1
// [RESULT] Liquidity: 63740878 (very low)
// [RESULT] Amount0: 3678979
// [RESULT] Amount1: 10000000
//
// [STEP 3] Execute large swap to move price significantly
// [DEBUG] Tick before swap: 10000
// [DEBUG] Pool liquidity: 63740878
// [INFO] Executing large swap relative to liquidity
// [DEBUG] Tick after swap: 8991
// [RESULT] Swap amount0: 2000000
// [RESULT] Swap amount1: -5166443
//
// [STEP 4] Check pool state - very low liquidity
// [STATE] Current tick: 8991
// [STATE] Pool liquidity: 63740878 (very low)
// [STATE] Current sqrt price: %!s((unhandled))
//
// [STEP 5] Decrease position liquidity to prepare for reposition
// [INFO] Decreasing position liquidity: 63740878
// [RESULT] Position liquidity decreased to 0
//
// [STEP 6] Reposition to new range with low liquidity environment
// [INFO] Current tick: 8991
// [INFO] Repositioning to new range: 6000 ~ 10000
// [INFO] Current pool has very low liquidity
// [RESULT] Reposition successful!
// [RESULT] New liquidity: 91832574
// [RESULT] New range: 6000 ~ 10000
// [RESULT] Amount0 used: 2879994
// [RESULT] Amount1 used: 20000000
//
// [STEP 7] Verify reposition succeeded despite low liquidity
// [VERIFY] Position after reposition:
//   - Liquidity: 91832574
//   - TickLower: 6000
//   - TickUpper: 10000
// [VERIFY] Pool liquidity after reposition: 91832574
//
// [STEP 8] Test swap in new range to confirm functionality
// [DEBUG] Tick before test swap: 8991
// [INFO] Testing swap in new range
// [RESULT] Test swap successful!
// [RESULT] Swap amount0: -403917
// [RESULT] Swap amount1: 1000000
// [DEBUG] Tick after test swap: 9130
