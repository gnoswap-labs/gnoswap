// Scenario: Swap Balance Validation - Multi-Hop Swaps
// Purpose: Validate balance changes across multiple pool hops

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
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
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
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	fee500 uint32 = 500

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806

	initialBalance int64 = 500_000_000_000
)

type BalanceSnapshot struct {
	userBar          int64
	userBaz          int64
	userFoo          int64
	userQux          int64
	poolBarFooBar    int64
	poolBarFooFoo    int64
	poolFooBazFoo    int64
	poolFooBazBaz    int64
	poolBazQuxBaz    int64
	poolBazQuxQux    int64
	routerBar        int64
	routerBaz        int64
	routerFoo        int64
	routerQux        int64
	protocolFeeBar   int64
	protocolFeeBaz   int64
	protocolFeeFoo   int64
	protocolFeeQux   int64
}

func main() {
	println("[SCENARIO] Swap Balance Validation - Multi-Hop Swaps")
	println("[INFO] Purpose: Validate balance changes across multiple pool hops")
	println()

	println("[SCENARIO] 1. Initial Setup")
	initial := setupEnvironment()
	printBalanceSnapshot("Initial State", initial)
	println()

	println("[SCENARIO] 2. Create Pools & Mint Positions")
	println("  Creating 3 pools: BAR-FOO, FOO-BAZ, BAZ-QUX")
	afterSetup := setupPoolsAndPositions()
	printBalanceSnapshot("After Setup", afterSetup)
	println()

	println("[SCENARIO] 3. Single Hop Swap (BAR -> FOO)")
	afterSingleHop := performSingleHopSwap()
	printBalanceSnapshot("After Single Hop", afterSingleHop)
	validateBalanceChange(afterSetup, afterSingleHop, "SingleHop")
	println()

	println("[SCENARIO] 4. Two Hop Swap (BAR -> FOO -> BAZ)")
	afterTwoHop := performTwoHopSwap()
	printBalanceSnapshot("After Two Hop", afterTwoHop)
	validateBalanceChange(afterSingleHop, afterTwoHop, "TwoHop")
	validateNoIntermediateBalance(afterTwoHop)
	println()

	println("[SCENARIO] 5. Three Hop Swap (BAR -> FOO -> BAZ -> QUX)")
	afterThreeHop := performThreeHopSwap()
	printBalanceSnapshot("After Three Hop", afterThreeHop)
	validateBalanceChange(afterTwoHop, afterThreeHop, "ThreeHop")
	validateNoIntermediateBalance(afterThreeHop)
	println()

	println("[SCENARIO] 6. Reverse Three Hop Swap (QUX -> BAZ -> FOO -> BAR)")
	afterReverse := performReverseThreeHopSwap()
	printBalanceSnapshot("After Reverse Three Hop", afterReverse)
	validateBalanceChange(afterThreeHop, afterReverse, "ReverseThreeHop")
	validateNoIntermediateBalance(afterReverse)
	println()

	println("[SCENARIO] 7. System Balance Conservation")
	validateSystemBalance(initial, afterReverse)
	println()

	println("[SCENARIO] Complete - All multi-hop validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	snapshot := BalanceSnapshot{
		userBar:        bar.BalanceOf(userAddr),
		userBaz:        baz.BalanceOf(userAddr),
		userFoo:        foo.BalanceOf(userAddr),
		userQux:        qux.BalanceOf(userAddr),
		poolBarFooBar:  bar.BalanceOf(poolAddr),
		poolBarFooFoo:  foo.BalanceOf(poolAddr),
		poolFooBazFoo:  foo.BalanceOf(poolAddr),
		poolFooBazBaz:  baz.BalanceOf(poolAddr),
		poolBazQuxBaz:  baz.BalanceOf(poolAddr),
		poolBazQuxQux:  qux.BalanceOf(poolAddr),
		routerBar:      bar.BalanceOf(routerAddr),
		routerBaz:      baz.BalanceOf(routerAddr),
		routerFoo:      foo.BalanceOf(routerAddr),
		routerQux:      qux.BalanceOf(routerAddr),
		protocolFeeBar: bar.BalanceOf(protocolFeeAddr),
		protocolFeeBaz: baz.BalanceOf(protocolFeeAddr),
		protocolFeeFoo: foo.BalanceOf(protocolFeeAddr),
		protocolFeeQux: qux.BalanceOf(protocolFeeAddr),
	}

	return snapshot
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[BALANCE]", step)
	println("  User - BAR:", snapshot.userBar, "FOO:", snapshot.userFoo, "BAZ:", snapshot.userBaz, "QUX:", snapshot.userQux)
	println("  Pools - BAR:", snapshot.poolBarFooBar, "FOO:", snapshot.poolFooBazFoo, "BAZ:", snapshot.poolBazQuxBaz, "QUX:", snapshot.poolBazQuxQux)
	println("  Router - BAR:", snapshot.routerBar, "FOO:", snapshot.routerFoo, "BAZ:", snapshot.routerBaz, "QUX:", snapshot.routerQux)
}

func setupEnvironment() BalanceSnapshot {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	bar.Transfer(cross, userAddr, initialBalance)
	baz.Transfer(cross, userAddr, initialBalance)
	foo.Transfer(cross, userAddr, initialBalance)
	qux.Transfer(cross, userAddr, initialBalance)

	testing.SetRealm(userRealm)
	return getBalanceSnapshot()
}

func setupPoolsAndPositions() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)
	qux.Approve(cross, poolAddr, max_approve)

	// Create Pool 1: BAR-FOO
	println("[INFO] Creating BAR-FOO pool")
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pn.Mint(cross, barPath, fooPath, fee500, int32(-10000), int32(10000), "100000000000", "100000000000", "0", "0", max_timeout, userAddr, userAddr, "")

	// Create Pool 2: FOO-BAZ
	println("[INFO] Creating FOO-BAZ pool")
	pl.CreatePool(cross, bazPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pn.Mint(cross, bazPath, fooPath, fee500, int32(-10000), int32(10000), "100000000000", "100000000000", "0", "0", max_timeout, userAddr, userAddr, "")

	// Create Pool 3: BAZ-QUX
	println("[INFO] Creating BAZ-QUX pool")
	pl.CreatePool(cross, bazPath, quxPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pn.Mint(cross, bazPath, quxPath, fee500, int32(-10000), int32(10000), "100000000000", "100000000000", "0", "0", max_timeout, userAddr, userAddr, "")

	println("[INFO] All pools and positions created")

	return getBalanceSnapshot()
}

func performSingleHopSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	swapAmount := int64(10_000_000_000)
	println("[INFO] Single Hop: Swapping", swapAmount, "BAR -> FOO")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		fooPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Single Hop - In:", amountIn, "Out:", amountOut)

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performTwoHopSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)

	swapAmount := int64(5_000_000_000)
	println("[INFO] Two Hop: Swapping", swapAmount, "BAR -> FOO -> BAZ")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		bazPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/baz:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Two Hop - In:", amountIn, "Out:", amountOut)
	println("[INFO] Route: BAR -> FOO (pool 1) -> BAZ (pool 2)")

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performThreeHopSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	bar.Approve(cross, routerAddr, max_approve)
	qux.Approve(cross, routerAddr, max_approve)

	swapAmount := int64(3_000_000_000)
	println("[INFO] Three Hop: Swapping", swapAmount, "BAR -> FOO -> BAZ -> QUX")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		quxPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Three Hop - In:", amountIn, "Out:", amountOut)
	println("[INFO] Route: BAR -> FOO (pool 1) -> BAZ (pool 2) -> QUX (pool 3)")

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performReverseThreeHopSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	qux.Approve(cross, routerAddr, max_approve)
	bar.Approve(cross, routerAddr, max_approve)

	swapAmount := int64(2_000_000_000)
	println("[INFO] Reverse Three Hop: Swapping", swapAmount, "QUX -> BAZ -> FOO -> BAR")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		quxPath,
		barPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/onbloc/qux:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:500*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Reverse Three Hop - In:", amountIn, "Out:", amountOut)
	println("[INFO] Route: QUX -> BAZ (pool 3) -> FOO (pool 2) -> BAR (pool 1)")

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[VALIDATION] Balance Change Check for", swapType)

	userBarDiff := after.userBar - before.userBar
	userBazDiff := after.userBaz - before.userBaz
	userFooDiff := after.userFoo - before.userFoo
	userQuxDiff := after.userQux - before.userQux

	protocolFeeBarDiff := after.protocolFeeBar - before.protocolFeeBar
	protocolFeeBazDiff := after.protocolFeeBaz - before.protocolFeeBaz
	protocolFeeFooDiff := after.protocolFeeFoo - before.protocolFeeFoo
	protocolFeeQuxDiff := after.protocolFeeQux - before.protocolFeeQux

	println("  User BAR change:", userBarDiff)
	println("  User FOO change:", userFooDiff)
	println("  User BAZ change:", userBazDiff)
	println("  User QUX change:", userQuxDiff)

	// Router must be empty
	assertRouterIsEmpty(after)

	// At least one token must decrease (input) and one must increase (output)
	changedTokens := 0
	if userBarDiff != 0 {
		changedTokens++
	}
	if userFooDiff != 0 {
		changedTokens++
	}
	if userBazDiff != 0 {
		changedTokens++
	}
	if userQuxDiff != 0 {
		changedTokens++
	}

	if changedTokens < 2 {
		panic("[ERROR] Multi-hop swap should change at least 2 token balances")
	}

	// Exact conservation for each token: user + pools + protocol fee + router changes must sum to 0
	// Note: pools share same address so we can't separate them, but the total should still be conserved
	totalBarChange := userBarDiff + (after.poolBarFooBar - before.poolBarFooBar) + protocolFeeBarDiff + (after.routerBar - before.routerBar)
	totalFooChange := userFooDiff + (after.poolFooBazFoo - before.poolFooBazFoo) + protocolFeeFooDiff + (after.routerFoo - before.routerFoo)
	totalBazChange := userBazDiff + (after.poolBazQuxBaz - before.poolBazQuxBaz) + protocolFeeBazDiff + (after.routerBaz - before.routerBaz)
	totalQuxChange := userQuxDiff + (after.poolBazQuxQux - before.poolBazQuxQux) + protocolFeeQuxDiff + (after.routerQux - before.routerQux)

	if totalBarChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BAR not conserved! Total change: %d", totalBarChange))
	}
	if totalFooChange != 0 {
		panic(ufmt.Sprintf("[ERROR] FOO not conserved! Total change: %d", totalFooChange))
	}
	if totalBazChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BAZ not conserved! Total change: %d", totalBazChange))
	}
	if totalQuxChange != 0 {
		panic(ufmt.Sprintf("[ERROR] QUX not conserved! Total change: %d", totalQuxChange))
	}

	println("[VALIDATION] Exact balance conservation verified for multi-hop swap")
}

func assertRouterIsEmpty(snapshot BalanceSnapshot) {
	if snapshot.routerBar != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has BAR balance: %d - funds stuck!", snapshot.routerBar))
	}
	if snapshot.routerFoo != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has FOO balance: %d - funds stuck!", snapshot.routerFoo))
	}
	if snapshot.routerBaz != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has BAZ balance: %d - funds stuck!", snapshot.routerBaz))
	}
	if snapshot.routerQux != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has QUX balance: %d - funds stuck!", snapshot.routerQux))
	}
}

func validateNoIntermediateBalance(snapshot BalanceSnapshot) {
	println("[VALIDATION] Checking for stuck intermediate tokens")

	// Router should never hold any tokens after swap completes
	if snapshot.routerBar != 0 {
		panic("[ERROR] Router has BAR balance - tokens stuck in intermediate hop!")
	}
	if snapshot.routerFoo != 0 {
		panic("[ERROR] Router has FOO balance - tokens stuck in intermediate hop!")
	}
	if snapshot.routerBaz != 0 {
		panic("[ERROR] Router has BAZ balance - tokens stuck in intermediate hop!")
	}
	if snapshot.routerQux != 0 {
		panic("[ERROR] Router has QUX balance - tokens stuck in intermediate hop!")
	}

	println("[VALIDATION] No intermediate tokens stuck - clean multi-hop execution")
}

func validateSystemBalance(initial, final BalanceSnapshot) {
	println("[VALIDATION] System-Wide Balance Conservation Across All Hops")

	// Calculate total for each token (including protocol fees)
	totalBarInitial := initial.userBar + initial.poolBarFooBar + initial.routerBar + initial.protocolFeeBar
	totalBarFinal := final.userBar + final.poolBarFooBar + final.routerBar + final.protocolFeeBar

	totalFooInitial := initial.userFoo + initial.poolFooBazFoo + initial.routerFoo + initial.protocolFeeFoo
	totalFooFinal := final.userFoo + final.poolFooBazFoo + final.routerFoo + final.protocolFeeFoo

	totalBazInitial := initial.userBaz + initial.poolBazQuxBaz + initial.routerBaz + initial.protocolFeeBaz
	totalBazFinal := final.userBaz + final.poolBazQuxBaz + final.routerBaz + final.protocolFeeBaz

	totalQuxInitial := initial.userQux + initial.poolBazQuxQux + initial.routerQux + initial.protocolFeeQux
	totalQuxFinal := final.userQux + final.poolBazQuxQux + final.routerQux + final.protocolFeeQux

	println("  Total BAR - Initial:", totalBarInitial, "Final:", totalBarFinal)
	println("  Total FOO - Initial:", totalFooInitial, "Final:", totalFooFinal)
	println("  Total BAZ - Initial:", totalBazInitial, "Final:", totalBazFinal)
	println("  Total QUX - Initial:", totalQuxInitial, "Final:", totalQuxFinal)

	if totalBarInitial != totalBarFinal {
		panic("[ERROR] BAR tokens not conserved across multi-hop swaps!")
	}
	if totalFooInitial != totalFooFinal {
		panic("[ERROR] FOO tokens not conserved across multi-hop swaps!")
	}
	if totalBazInitial != totalBazFinal {
		panic("[ERROR] BAZ tokens not conserved across multi-hop swaps!")
	}
	if totalQuxInitial != totalQuxFinal {
		panic("[ERROR] QUX tokens not conserved across multi-hop swaps!")
	}

	println("[VALIDATION] All tokens perfectly conserved across multi-hop swaps")
	println("[SUCCESS] No leakage in any intermediate pool or router")
}

// Output:
// [SCENARIO] Swap Balance Validation - Multi-Hop Swaps
// [INFO] Purpose: Validate balance changes across multiple pool hops
//
// [SCENARIO] 1. Initial Setup
// [BALANCE] Initial State
//   User - BAR: 500000000000 FOO: 500000000000 BAZ: 500000000000 QUX: 500000000000
//   Pools - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
//
// [SCENARIO] 2. Create Pools & Mint Positions
//   Creating 3 pools: BAR-FOO, FOO-BAZ, BAZ-QUX
// [INFO] Creating BAR-FOO pool
// [INFO] Creating FOO-BAZ pool
// [INFO] Creating BAZ-QUX pool
// [INFO] All pools and positions created
// [BALANCE] After Setup
//   User - BAR: 400000000000 FOO: 300000000000 BAZ: 300000000000 QUX: 400000000000
//   Pools - BAR: 100000000000 FOO: 200000000000 BAZ: 200000000000 QUX: 100000000000
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
//
// [SCENARIO] 3. Single Hop Swap (BAR -> FOO)
// [INFO] Single Hop: Swapping 10000000000 BAR -> FOO
// [INFO] Single Hop - In: 10000000000 Out: -9602386497
// [BALANCE] After Single Hop
//   User - BAR: 390000000000 FOO: 309602386497 BAZ: 300000000000 QUX: 400000000000
//   Pools - BAR: 110000000000 FOO: 190383188286 BAZ: 200000000000 QUX: 100000000000
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
// [VALIDATION] Balance Change Check for SingleHop
//   User BAR change: -10000000000
//   User FOO change: 9602386497
//   User BAZ change: 0
//   User QUX change: 0
// [VALIDATION] Balance changes are valid for multi-hop swap
//
// [SCENARIO] 4. Two Hop Swap (BAR -> FOO -> BAZ)
// [INFO] Two Hop: Swapping 5000000000 BAR -> FOO -> BAZ
// [INFO] Two Hop - In: 5000000000 Out: -4451991291
// [INFO] Route: BAR -> FOO (pool 1) -> BAZ (pool 2)
// [BALANCE] After Two Hop
//   User - BAR: 385000000000 FOO: 309602386497 BAZ: 304451991291 QUX: 400000000000
//   Pools - BAR: 115000000000 FOO: 190383188286 BAZ: 195541320691 QUX: 100000000000
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
// [VALIDATION] Balance Change Check for TwoHop
//   User BAR change: -5000000000
//   User FOO change: 0
//   User BAZ change: 4451991291
//   User QUX change: 0
// [VALIDATION] Balance changes are valid for multi-hop swap
// [VALIDATION] Checking for stuck intermediate tokens
// [VALIDATION] No intermediate tokens stuck - clean multi-hop execution
//
// [SCENARIO] 5. Three Hop Swap (BAR -> FOO -> BAZ -> QUX)
// [INFO] Three Hop: Swapping 3000000000 BAR -> FOO -> BAZ -> QUX
// [INFO] Three Hop - In: 3000000000 Out: -2495426539
// [INFO] Route: BAR -> FOO (pool 1) -> BAZ (pool 2) -> QUX (pool 3)
// [BALANCE] After Three Hop
//   User - BAR: 382000000000 FOO: 309602386497 BAZ: 304451991291 QUX: 402495426539
//   Pools - BAR: 118000000000 FOO: 190383188286 BAZ: 195541320691 QUX: 97500824699
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
// [VALIDATION] Balance Change Check for ThreeHop
//   User BAR change: -3000000000
//   User FOO change: 0
//   User BAZ change: 0
//   User QUX change: 2495426539
// [VALIDATION] Balance changes are valid for multi-hop swap
// [VALIDATION] Checking for stuck intermediate tokens
// [VALIDATION] No intermediate tokens stuck - clean multi-hop execution
//
// [SCENARIO] 6. Reverse Three Hop Swap (QUX -> BAZ -> FOO -> BAR)
// [INFO] Reverse Three Hop: Swapping 2000000000 QUX -> BAZ -> FOO -> BAR
// [INFO] Reverse Three Hop - In: 2000000000 Out: -2404819407
// [INFO] Route: QUX -> BAZ (pool 3) -> FOO (pool 2) -> BAR (pool 1)
// [BALANCE] After Reverse Three Hop
//   User - BAR: 384404819407 FOO: 309602386497 BAZ: 304451991291 QUX: 400495426539
//   Pools - BAR: 115591567945 FOO: 190383188286 BAZ: 195541320691 QUX: 99500824699
//   Router - BAR: 0 FOO: 0 BAZ: 0 QUX: 0
// [VALIDATION] Balance Change Check for ReverseThreeHop
//   User BAR change: 2404819407
//   User FOO change: 0
//   User BAZ change: 0
//   User QUX change: -2000000000
// [VALIDATION] Balance changes are valid for multi-hop swap
// [VALIDATION] Checking for stuck intermediate tokens
// [VALIDATION] No intermediate tokens stuck - clean multi-hop execution
//
// [SCENARIO] 7. System Balance Conservation
// [VALIDATION] System-Wide Balance Conservation Across All Hops
//   Total BAR - Initial: 500000000000 Final: 500000000000
//   Total FOO - Initial: 500000000000 Final: 500000000000
//   Total BAZ - Initial: 500000000000 Final: 500000000000
//   Total QUX - Initial: 500000000000 Final: 500000000000
// [VALIDATION] All tokens perfectly conserved across multi-hop swaps
// [SUCCESS] No leakage in any intermediate pool or router
//
// [SCENARIO] Complete - All multi-hop validations passed
