// Scenario: Safe Mode blocks withdraw operations
//
// This test verifies that when Safe Mode is activated, withdraw operations
// are blocked while other operations continue to work normally.
//
// Safe Mode configuration (from config.gno):
//   - OpTypeWithdraw: true (BLOCKED)
//   - All other operations: false (ALLOWED)
//
// Test cases:
//   1. Position Mint works in Safe Mode (position not blocked)
//   2. DecreaseLiquidity is blocked in Safe Mode (withdraw blocked)
//   3. CollectFee is blocked in Safe Mode (withdraw blocked)
//   4. Router swap works in Safe Mode (router not blocked)
//   5. After disabling Safe Mode, withdraw operations work again

package main

import (
	"chain"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	_ "gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

const INT64_MAX int64 = 9223372036854775807

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)
	poolAddr   = access.MustGetAddress(prbac.ROLE_POOL.String())
	routerAddr = access.MustGetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	fee     = uint32(3000)

	positionId uint64
)

func main() {
	ufmt.Println("[SCENARIO] Safe Mode blocks withdraw operations")
	println()

	ufmt.Println("[STEP 1] Initialize pool and tokens")
	initPoolAndTokens()
	println()

	ufmt.Println("[STEP 2] Mint position (before Safe Mode)")
	mintPosition()
	println()

	ufmt.Println("[STEP 3] Set halt level to Safe Mode")
	setSafeMode()
	println()

	ufmt.Println("[STEP 4] Test: Position Mint works in Safe Mode")
	testMintInSafeMode()
	println()

	ufmt.Println("[STEP 5] Test: DecreaseLiquidity is BLOCKED in Safe Mode")
	testDecreaseLiquidityBlocked()
	println()

	ufmt.Println("[STEP 6] Test: CollectFee is BLOCKED in Safe Mode")
	testCollectFeeBlocked()
	println()

	ufmt.Println("[STEP 7] Test: Router swap works in Safe Mode")
	testRouterSwapInSafeMode()
	println()

	ufmt.Println("[STEP 8] Disable Safe Mode and verify withdraw works")
	disableSafeModeAndVerify()
	println()
}

func initPoolAndTokens() {
	testing.SetRealm(adminRealm)

	// Initialize emission
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	testing.SkipHeights(1)

	// Distribute tokens to alice
	defaultTokenAmount := int64(100000000)
	atom.Transfer(cross, aliceAddr, defaultTokenAmount)
	btc.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Printf("[INFO] Alice ATOM balance: %d\n", atom.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Alice BTC balance: %d\n", btc.BalanceOf(aliceAddr))

	// Create pool
	pool.SetPoolCreationFee(cross, 0)
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
	ufmt.Println("[INFO] Pool created: gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:3000")
}

func mintPosition() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, INT64_MAX)
	btc.Approve(cross, poolAddr, INT64_MAX)

	testing.SetOriginSend(chain.Coins{})
	id, liquidity, amount0, amount1 := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-960,
		960,
		"10000000",
		"10000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)

	positionId = id
	ufmt.Printf("[INFO] Position minted with ID: %d\n", positionId)
	ufmt.Printf("[INFO] Liquidity: %s, Amount0: %s, Amount1: %s\n", liquidity, amount0, amount1)
}

func setSafeMode() {
	testing.SetRealm(adminRealm)

	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)

	isWithdrawHalted := halt.IsHaltedWithdraw()
	isPositionHalted := halt.IsHaltedPosition()
	isPoolHalted := halt.IsHaltedPool()
	isRouterHalted := halt.IsHaltedRouter()

	ufmt.Println("[INFO] Safe Mode activated")
	ufmt.Printf("[EXPECTED] Withdraw halted: %t (should be true)\n", isWithdrawHalted)
	ufmt.Printf("[EXPECTED] Position halted: %t (should be false)\n", isPositionHalted)
	ufmt.Printf("[EXPECTED] Pool halted: %t (should be false)\n", isPoolHalted)
	ufmt.Printf("[EXPECTED] Router halted: %t (should be false)\n", isRouterHalted)
}

func testMintInSafeMode() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Attempting to mint position in Safe Mode...")

	testing.SetOriginSend(chain.Coins{})
	id, liquidity, _, _ := position.Mint(
		cross,
		atomPath,
		btcPath,
		fee,
		-1920,
		1920,
		"5000000",
		"5000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		"",
	)

	ufmt.Printf("[SUCCESS] Position minted in Safe Mode! ID: %d, Liquidity: %s\n", id, liquidity)
}

func testDecreaseLiquidityBlocked() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Attempting DecreaseLiquidity in Safe Mode (should abort)...")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		position.DecreaseLiquidity(
			cross,
			positionId,
			"1000000",
			"0",
			"0",
			time.Now().Unix()+3600,
		)
	})

	ufmt.Println("[SUCCESS] DecreaseLiquidity correctly blocked with 'halted: withdraw'")
}

func testCollectFeeBlocked() {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Attempting CollectFee in Safe Mode (should abort)...")

	uassert.AbortsContains(t, "halted: withdraw", func() {
		position.CollectFee(cross, positionId)
	})

	ufmt.Println("[SUCCESS] CollectFee correctly blocked with 'halted: withdraw'")
}

func testRouterSwapInSafeMode() {
	testing.SetRealm(aliceRealm)
	atom.Approve(cross, routerAddr, INT64_MAX)
	btc.Approve(cross, routerAddr, INT64_MAX)

	ufmt.Println("[INFO] Attempting router swap in Safe Mode...")

	testing.SetOriginSend(chain.Coins{})
	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		atomPath,
		btcPath,
		"100000",
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:3000",
		"100",
		"0",
		time.Now().Unix()+3600,
		"",
	)

	ufmt.Printf("[SUCCESS] Router swap works in Safe Mode! AmountIn: %s, AmountOut: %s\n", amountIn, amountOut)
}

func disableSafeModeAndVerify() {
	testing.SetRealm(adminRealm)

	halt.SetHaltLevel(cross, halt.HaltLevelNone)

	isWithdrawHalted := halt.IsHaltedWithdraw()
	ufmt.Printf("[INFO] Safe Mode disabled. Withdraw halted: %t (should be false)\n", isWithdrawHalted)

	// Now try DecreaseLiquidity again - should work
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Attempting DecreaseLiquidity after Safe Mode disabled...")

	_, liquidity, _, _, _, _, _ := position.DecreaseLiquidity(
		cross,
		positionId,
		"1000000",
		"0",
		"0",
		time.Now().Unix()+3600,
	)

	ufmt.Printf("[SUCCESS] DecreaseLiquidity works after Safe Mode disabled! Liquidity removed: %s\n", liquidity)
}

// Output:
// [SCENARIO] Safe Mode blocks withdraw operations
//
// [STEP 1] Initialize pool and tokens
// [INFO] Alice ATOM balance: 100000000
// [INFO] Alice BTC balance: 100000000
// [INFO] Pool created: gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:3000
//
// [STEP 2] Mint position (before Safe Mode)
// [INFO] Position minted with ID: 1
// [INFO] Liquidity: 213383746, Amount0: 10000000, Amount1: 10000000
//
// [STEP 3] Set halt level to Safe Mode
// [INFO] Safe Mode activated
// [EXPECTED] Withdraw halted: true (should be true)
// [EXPECTED] Position halted: false (should be false)
// [EXPECTED] Pool halted: false (should be false)
// [EXPECTED] Router halted: false (should be false)
//
// [STEP 4] Test: Position Mint works in Safe Mode
// [INFO] Attempting to mint position in Safe Mode...
// [SUCCESS] Position minted in Safe Mode! ID: 2, Liquidity: 54625929
//
// [STEP 5] Test: DecreaseLiquidity is BLOCKED in Safe Mode
// [INFO] Attempting DecreaseLiquidity in Safe Mode (should abort)...
// [SUCCESS] DecreaseLiquidity correctly blocked with 'halted: withdraw'
//
// [STEP 6] Test: CollectFee is BLOCKED in Safe Mode
// [INFO] Attempting CollectFee in Safe Mode (should abort)...
// [SUCCESS] CollectFee correctly blocked with 'halted: withdraw'
//
// [STEP 7] Test: Router swap works in Safe Mode
// [INFO] Attempting router swap in Safe Mode...
// [SUCCESS] Router swap works in Safe Mode! AmountIn: 100000, AmountOut: -99513
//
// [STEP 8] Disable Safe Mode and verify withdraw works
// [INFO] Safe Mode disabled. Withdraw halted: false (should be false)
// [INFO] Attempting DecreaseLiquidity after Safe Mode disabled...
// [SUCCESS] DecreaseLiquidity works after Safe Mode disabled! Liquidity removed: 1000000
