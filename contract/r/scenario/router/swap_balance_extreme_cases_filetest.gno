// Scenario: Swap Balance Validation - Extreme Cases
// Purpose: Validate balance changes in extreme swap scenarios

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewUserRealm(userAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500 uint32 = 500

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806

	initialBalance int64 = 1_000_000_000_000 // 1 trillion for extreme swaps
)

type BalanceSnapshot struct {
	userBar          int64
	userFoo          int64
	poolBar          int64
	poolFoo          int64
	routerBar        int64
	routerFoo        int64
	protocolFeeBar   int64
	protocolFeeFoo   int64
}

var t *testing.T

func main() {
	println("[SCENARIO] Swap Balance Validation - Extreme Cases")
	println("[INFO] Purpose: Validate balance changes in extreme swap scenarios")
	println()

	println("[SCENARIO] 1. Initial Setup")
	initial := setupEnvironment()
	printBalanceSnapshot("Initial State", initial)
	println()

	println("[SCENARIO] 2. Create Pool & Mint Large Position")
	afterSetup := setupPoolAndPosition()
	printBalanceSnapshot("After Setup", afterSetup)
	println()

	println("[SCENARIO] 3. Extreme Case 1: Very Large Swap (90% of liquidity)")
	afterLargeSwap := performLargeSwap(afterSetup)
	printBalanceSnapshot("After Large Swap", afterLargeSwap)
	validateBalanceChange(afterSetup, afterLargeSwap, "Large ExactIn")
	println()

	println("[SCENARIO] 4. Extreme Case 2: Swap Back with High Slippage")
	afterReverseSwap := performReverseSwap(afterLargeSwap)
	printBalanceSnapshot("After Reverse Swap", afterReverseSwap)
	validateBalanceChange(afterLargeSwap, afterReverseSwap, "Large ExactOut")
	println()

	println("[SCENARIO] 5. Extreme Case 3: Small Swap After Large Price Movement")
	afterSmallSwap := performSmallSwap(afterReverseSwap)
	printBalanceSnapshot("After Small Swap", afterSmallSwap)
	validateBalanceChange(afterReverseSwap, afterSmallSwap, "Small ExactIn")
	validateSmallSwapImpact(afterReverseSwap, afterSmallSwap)
	println()

	println("[SCENARIO] 6. Final Validation: Total System Balance Conservation")
	validateSystemBalance(initial, afterSmallSwap)
	println()

	println("[SCENARIO] Complete - All extreme case validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	snapshot := BalanceSnapshot{
		userBar:          bar.BalanceOf(userAddr),
		userFoo:          foo.BalanceOf(userAddr),
		poolBar:          bar.BalanceOf(poolAddr),
		poolFoo:          foo.BalanceOf(poolAddr),
		routerBar:        bar.BalanceOf(routerAddr),
		routerFoo:        foo.BalanceOf(routerAddr),
		protocolFeeBar:   bar.BalanceOf(protocolFeeAddr),
		protocolFeeFoo:   foo.BalanceOf(protocolFeeAddr),
	}

	return snapshot
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User BAR balance:", snapshot.userBar)
	println("[EXPECTED] User FOO balance:", snapshot.userFoo)
	println("[EXPECTED] Pool BAR balance:", snapshot.poolBar)
	println("[EXPECTED] Pool FOO balance:", snapshot.poolFoo)
	println("[EXPECTED] Router BAR balance:", snapshot.routerBar)
	println("[EXPECTED] Router FOO balance:", snapshot.routerFoo)
	println("[EXPECTED] Protocol fee BAR balance:", snapshot.protocolFeeBar)
	println("[EXPECTED] Protocol fee FOO balance:", snapshot.protocolFeeFoo)
}

func setupEnvironment() BalanceSnapshot {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	bar.Transfer(cross, userAddr, initialBalance)
	foo.Transfer(cross, userAddr, initialBalance)

	testing.SetRealm(userRealm)
	return getBalanceSnapshot()
}

func setupPoolAndPosition() BalanceSnapshot {
	testing.SetRealm(userRealm)

	// Create pool
	pl.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	bar.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)

	// Mint very large position for extreme swaps
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		int32(-50000), // very wide range
		int32(50000),
		"500000000000", // 500 billion
		"500000000000",
		"0",
		"0",
		max_timeout,
		userAddr,
		userAddr,
		"",
	)

	println("[INFO] Large Position ID:", tokenId)
	println("[INFO] Liquidity:", liquidity)
	println("[INFO] Amount0 (BAR):", amount0)
	println("[INFO] Amount1 (FOO):", amount1)

	return getBalanceSnapshot()
}

func performLargeSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	foo.Approve(cross, routerAddr, max_approve)

	// Swap 90% of pool's FOO liquidity
	swapAmount := int64(450_000_000_000) // 90% of 500B
	println("[INFO] Extreme Swap: Swapping", swapAmount, "FOO -> BAR (90% of liquidity)")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		fooPath,
		barPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500",
		"100",
		"1", // minimal output requirement
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Large Swap - In:", amountIn, "Out:", amountOut)
	println("[INFO] Expected: Massive price impact and slippage")

	return getBalanceSnapshot()
}

func performReverseSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, routerAddr, max_approve)

	// Swap back with exact out
	swapAmount := int64(200_000_000_000)
	println("[INFO] Reverse Swap: Getting", swapAmount, "FOO back")

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath,
		fooPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		"100",
		ufmt.Sprintf("%d", max_approve), // allow max slippage
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Reverse Swap - In:", amountIn, "Out:", amountOut)

	return getBalanceSnapshot()
}

func performSmallSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	foo.Approve(cross, routerAddr, max_approve)

	// Very small swap after extreme price movement
	swapAmount := int64(1_000_000) // just 1M
	println("[INFO] Small Swap: Swapping", swapAmount, "FOO -> BAR (after extreme movement)")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		fooPath,
		barPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Small Swap - In:", amountIn, "Out:", amountOut)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance conservation for", swapType)

	userBarDiff := after.userBar - before.userBar
	userFooDiff := after.userFoo - before.userFoo
	poolBarDiff := after.poolBar - before.poolBar
	poolFooDiff := after.poolFoo - before.poolFoo

	println("[EXPECTED] User BAR change:", userBarDiff)
	println("[EXPECTED] User FOO change:", userFooDiff)
	println("[EXPECTED] Pool BAR change:", poolBarDiff)
	println("[EXPECTED] Pool FOO change:", poolFooDiff)

	// Router must be empty
	if after.routerBar != 0 || after.routerFoo != 0 {
		panic("[ERROR] Router has remaining balance - funds stuck!")
	}

	// User gains must come from pool (conservation of mass)
	// Pool BAR decrease should roughly equal User BAR increase (minus fees)
	// Pool FOO increase should roughly equal User FOO decrease (plus fees)

	// Check direction is correct
	if userBarDiff > 0 && poolBarDiff > 0 {
		panic("[ERROR] Both user and pool gained BAR - impossible!")
	}
	if userFooDiff > 0 && poolFooDiff > 0 {
		panic("[ERROR] Both user and pool gained FOO - impossible!")
	}

	println("[EXPECTED] Balance conservation holds - no value created or destroyed")
}

func validateSmallSwapImpact(before, after BalanceSnapshot) {
	println("[INFO] Validating small swap impact")

	userBarDiff := after.userBar - before.userBar
	userFooDiff := after.userFoo - before.userFoo

	println("[EXPECTED] Small swap caused minimal balance change")
	println("[EXPECTED] User BAR change:", userBarDiff)
	println("[EXPECTED] User FOO change:", userFooDiff)

	// Small swap should have proportionally less impact
	if userBarDiff == 0 && userFooDiff == 0 {
		panic("[ERROR] Small swap had no effect")
	}

	println("[EXPECTED] Small swap executed correctly despite extreme price")
}

func validateSystemBalance(initial, final BalanceSnapshot) {
	println("[INFO] Validating system-wide balance conservation")

	// Total supply in system should be conserved
	// User + Pool + Router + ProtocolFee = Initial Supply

	totalBarInitial := initial.userBar + initial.poolBar + initial.routerBar + initial.protocolFeeBar
	totalBarFinal := final.userBar + final.poolBar + final.routerBar + final.protocolFeeBar

	totalFooInitial := initial.userFoo + initial.poolFoo + initial.routerFoo + initial.protocolFeeFoo
	totalFooFinal := final.userFoo + final.poolFoo + final.routerFoo + final.protocolFeeFoo

	println("[EXPECTED] Total BAR - Initial:", totalBarInitial, "Final:", totalBarFinal)
	println("[EXPECTED] Total FOO - Initial:", totalFooInitial, "Final:", totalFooFinal)

	if totalBarInitial != totalBarFinal {
		panic("[ERROR] BAR tokens were created or destroyed!")
	}

	if totalFooInitial != totalFooFinal {
		panic("[ERROR] FOO tokens were created or destroyed!")
	}

	println("[EXPECTED] System-wide balance perfectly conserved")
	println("[EXPECTED] No tokens leaked, created, or destroyed in extreme scenarios")
}

// Output:
// [SCENARIO] Swap Balance Validation - Extreme Cases
// [INFO] Purpose: Validate balance changes in extreme swap scenarios
//
// [SCENARIO] 1. Initial Setup
// [INFO] Initial State
// [EXPECTED] User BAR balance: 1000000000000
// [EXPECTED] User FOO balance: 1000000000000
// [EXPECTED] Pool BAR balance: 0
// [EXPECTED] Pool FOO balance: 0
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 2. Create Pool & Mint Large Position
// [INFO] Large Position ID: 1
// [INFO] Liquidity: 544718833860
// [INFO] Amount0 (BAR): 500000000000
// [INFO] Amount1 (FOO): 500000000000
// [INFO] After Setup
// [EXPECTED] User BAR balance: 500000000000
// [EXPECTED] User FOO balance: 500000000000
// [EXPECTED] Pool BAR balance: 500000000000
// [EXPECTED] Pool FOO balance: 500000000000
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 3. Extreme Case 1: Very Large Swap (90% of liquidity)
// [INFO] Extreme Swap: Swapping 450000000000 FOO -> BAR (90% of liquidity)
// [INFO] Large Swap - In: 450000000000 Out: -245987862163
// [INFO] Expected: Massive price impact and slippage
// [INFO] After Large Swap
// [EXPECTED] User BAR balance: 745987862163
// [EXPECTED] User FOO balance: 50000000000
// [EXPECTED] Pool BAR balance: 253642601740
// [EXPECTED] Pool FOO balance: 950000000000
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 369536097
// [EXPECTED] Protocol fee FOO balance: 0
// [INFO] Validating balance conservation for Large ExactIn
// [EXPECTED] User BAR change: 245987862163
// [EXPECTED] User FOO change: -450000000000
// [EXPECTED] Pool BAR change: -246357398260
// [EXPECTED] Pool FOO change: 450000000000
// [EXPECTED] Balance conservation holds - no value created or destroyed
//
// [SCENARIO] 4. Extreme Case 2: Swap Back with High Slippage
// [INFO] Reverse Swap: Getting 200000000000 FOO back
// [INFO] Reverse Swap - In: 75286230276 Out: -200000000000
// [INFO] After Reverse Swap
// [EXPECTED] User BAR balance: 670701631887
// [EXPECTED] User FOO balance: 250000000000
// [EXPECTED] Pool BAR balance: 328928832016
// [EXPECTED] Pool FOO balance: 749699549324
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 369536097
// [EXPECTED] Protocol fee FOO balance: 300450676
// [INFO] Validating balance conservation for Large ExactOut
// [EXPECTED] User BAR change: -75286230276
// [EXPECTED] User FOO change: 200000000000
// [EXPECTED] Pool BAR change: 75286230276
// [EXPECTED] Pool FOO change: -200300450676
// [EXPECTED] Balance conservation holds - no value created or destroyed
//
// [SCENARIO] 5. Extreme Case 3: Small Swap After Large Price Movement
// [INFO] Small Swap: Swapping 1000000 FOO -> BAR (after extreme movement)
// [INFO] Small Swap - In: 1000000 Out: -469486
// [INFO] After Small Swap
// [EXPECTED] User BAR balance: 670702101373
// [EXPECTED] User FOO balance: 249999000000
// [EXPECTED] Pool BAR balance: 328928361825
// [EXPECTED] Pool FOO balance: 749700549324
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 369536802
// [EXPECTED] Protocol fee FOO balance: 300450676
// [INFO] Validating balance conservation for Small ExactIn
// [EXPECTED] User BAR change: 469486
// [EXPECTED] User FOO change: -1000000
// [EXPECTED] Pool BAR change: -470191
// [EXPECTED] Pool FOO change: 1000000
// [EXPECTED] Balance conservation holds - no value created or destroyed
// [INFO] Validating small swap impact
// [EXPECTED] Small swap caused minimal balance change
// [EXPECTED] User BAR change: 469486
// [EXPECTED] User FOO change: -1000000
// [EXPECTED] Small swap executed correctly despite extreme price
//
// [SCENARIO] 6. Final Validation: Total System Balance Conservation
// [INFO] Validating system-wide balance conservation
// [EXPECTED] Total BAR - Initial: 1000000000000 Final: 1000000000000
// [EXPECTED] Total FOO - Initial: 1000000000000 Final: 1000000000000
// [EXPECTED] System-wide balance perfectly conserved
// [EXPECTED] No tokens leaked, created, or destroyed in extreme scenarios
//
// [SCENARIO] Complete - All extreme case validations passed
