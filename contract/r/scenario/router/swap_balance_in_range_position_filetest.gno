// Scenario: Swap Balance Validation - In Range Position
// Purpose: Validate balance changes with in-range position swaps that cause price movement

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

	initialBalance int64 = 100_000_000_000
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
	println("[SCENARIO] Swap Balance Validation - In Range Position")
	println("[INFO] Purpose: Validate balance changes with in-range position swaps")
	println()

	println("[SCENARIO] 1. Initial Setup")
	initial := setupEnvironment()
	printBalanceSnapshot("Initial State", initial)
	println()

	println("[SCENARIO] 2. Create Pool")
	afterPool := createPool()
	printBalanceSnapshot("After Pool Creation", afterPool)
	println()

	println("[SCENARIO] 3. Mint In-Range Position")
	afterMint := mintInRangePosition()
	printBalanceSnapshot("After Position Mint", afterMint)
	println()

	println("[SCENARIO] 4. Exact In Swap (FOO -> BAR)")
	afterExactIn := performExactInSwap()
	printBalanceSnapshot("After Exact In Swap", afterExactIn)
	validateBalanceChange(afterMint, afterExactIn, "ExactIn")
	println()

	println("[SCENARIO] 5. Exact Out Swap (BAR -> FOO)")
	afterExactOut := performExactOutSwap()
	printBalanceSnapshot("After Exact Out Swap", afterExactOut)
	validateBalanceChange(afterExactIn, afterExactOut, "ExactOut")
	println()

	println("[SCENARIO] Complete - All balance validations passed")
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

func createPool() BalanceSnapshot {
	testing.SetRealm(userRealm)

	pl.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	return getBalanceSnapshot()
}

func mintInRangePosition() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)

	// Mint position covering wide range around current price (tick 0)
	// This ensures the position stays in range during swaps
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		int32(-10000), // tickLower
		int32(10000),  // tickUpper
		"50000000000", // amount0Desired (BAR)
		"50000000000", // amount1Desired (FOO)
		"0",           // amount0Min
		"0",           // amount1Min
		max_timeout,
		userAddr,
		userAddr,
		"",
	)

	println("[INFO] Minted position ID:", tokenId)
	println("[INFO] Liquidity:", liquidity)
	println("[INFO] Amount0 (BAR):", amount0)
	println("[INFO] Amount1 (FOO):", amount1)

	return getBalanceSnapshot()
}

func performExactInSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	foo.Approve(cross, routerAddr, max_approve)
	bar.Approve(cross, routerAddr, max_approve)

	// Swap FOO -> BAR (exact in)
	// This should increase the price (more FOO in pool, less BAR)
	swapAmount := int64(10_000_000_000)
	println("[INFO] Swapping", swapAmount, "FOO -> BAR")

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

	println("[INFO] Exact In - In:", amountIn, "Out:", amountOut)

	return getBalanceSnapshot()
}

func performExactOutSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	// Swap BAR -> FOO (exact out)
	// This should decrease the price (more BAR in pool, less FOO)
	swapAmount := int64(5_000_000_000)
	println("[INFO] Swapping BAR ->", swapAmount, "FOO")

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath,
		fooPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		"100",
		ufmt.Sprintf("%d", max_approve),
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Exact Out - In:", amountIn, "Out:", amountOut)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	// User balance should change (tokens swapped)
	userBarDiff := after.userBar - before.userBar
	userFooDiff := after.userFoo - before.userFoo

	// Pool balance should change (opposite of user)
	poolBarDiff := after.poolBar - before.poolBar
	poolFooDiff := after.poolFoo - before.poolFoo

	println("[EXPECTED] User BAR change:", userBarDiff)
	println("[EXPECTED] User FOO change:", userFooDiff)
	println("[EXPECTED] Pool BAR change:", poolBarDiff)
	println("[EXPECTED] Pool FOO change:", poolFooDiff)

	// Router should have zero balance after swap (no stuck funds)
	if after.routerBar != 0 || after.routerFoo != 0 {
		panic("[ERROR] Router has remaining balance after swap")
	}

	// Conservation check: user's loss should roughly equal pool's gain (minus fees)
	// For ExactIn: user loses input token, pool gains it
	// For ExactOut: user gains output token, pool loses it
	if swapType == "ExactIn" {
		if userFooDiff >= 0 {
			panic("[ERROR] User FOO should decrease in ExactIn swap")
		}
		if poolFooDiff <= 0 {
			panic("[ERROR] Pool FOO should increase in ExactIn swap")
		}
	} else if swapType == "ExactOut" {
		if userFooDiff <= 0 {
			panic("[ERROR] User FOO should increase in ExactOut swap")
		}
		if poolFooDiff >= 0 {
			panic("[ERROR] Pool FOO should decrease in ExactOut swap")
		}
	}

	println("[EXPECTED] Balance changes are valid for", swapType)
}

// Output:
// [SCENARIO] Swap Balance Validation - In Range Position
// [INFO] Purpose: Validate balance changes with in-range position swaps
//
// [SCENARIO] 1. Initial Setup
// [INFO] Initial State
// [EXPECTED] User BAR balance: 100000000000
// [EXPECTED] User FOO balance: 100000000000
// [EXPECTED] Pool BAR balance: 0
// [EXPECTED] Pool FOO balance: 0
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 2. Create Pool
// [INFO] After Pool Creation
// [EXPECTED] User BAR balance: 100000000000
// [EXPECTED] User FOO balance: 100000000000
// [EXPECTED] Pool BAR balance: 0
// [EXPECTED] Pool FOO balance: 0
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 3. Mint In-Range Position
// [INFO] Minted position ID: 1
// [INFO] Liquidity: 127079601172
// [INFO] Amount0 (BAR): 50000000000
// [INFO] Amount1 (FOO): 50000000000
// [INFO] After Position Mint
// [EXPECTED] User BAR balance: 50000000000
// [EXPECTED] User FOO balance: 50000000000
// [EXPECTED] Pool BAR balance: 50000000000
// [EXPECTED] Pool FOO balance: 50000000000
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 4. Exact In Swap (FOO -> BAR)
// [INFO] Swapping 10000000000 FOO -> BAR
// [INFO] Exact In - In: 10000000000 Out: -9252300294
// [INFO] After Exact In Swap
// [EXPECTED] User BAR balance: 59252300294
// [EXPECTED] User FOO balance: 40000000000
// [EXPECTED] Pool BAR balance: 40733800407
// [EXPECTED] Pool FOO balance: 60000000000
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 13899299
// [EXPECTED] Protocol fee FOO balance: 0
// [INFO] Validating balance changes for ExactIn
// [EXPECTED] User BAR change: 9252300294
// [EXPECTED] User FOO change: -10000000000
// [EXPECTED] Pool BAR change: -9266199593
// [EXPECTED] Pool FOO change: 10000000000
// [EXPECTED] Balance changes are valid for ExactIn
//
// [SCENARIO] 5. Exact Out Swap (BAR -> FOO)
// [INFO] Swapping BAR -> 5000000000 FOO
// [INFO] Exact Out - In: 4469297080 Out: -5000000000
// [INFO] After Exact Out Swap
// [EXPECTED] User BAR balance: 54783003214
// [EXPECTED] User FOO balance: 45000000000
// [EXPECTED] Pool BAR balance: 45203097487
// [EXPECTED] Pool FOO balance: 54992488734
// [EXPECTED] Router BAR balance: 0
// [EXPECTED] Router FOO balance: 0
// [EXPECTED] Protocol fee BAR balance: 13899299
// [EXPECTED] Protocol fee FOO balance: 7511266
// [INFO] Validating balance changes for ExactOut
// [EXPECTED] User BAR change: -4469297080
// [EXPECTED] User FOO change: 5000000000
// [EXPECTED] Pool BAR change: 4469297080
// [EXPECTED] Pool FOO change: -5007511266
// [EXPECTED] Balance changes are valid for ExactOut
//
// [SCENARIO] Complete - All balance validations passed
