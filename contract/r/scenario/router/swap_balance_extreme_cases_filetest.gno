// Scenario: Swap Balance Validation - Extreme Cases
// Purpose: Validate balance changes in extreme swap scenarios

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewUserRealm(userAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

	fee500 uint32 = 500

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806

	initialBalance int64 = 1_000_000_000_000 // 1 trillion for extreme swaps
)

type BalanceSnapshot struct {
	userAtom          int64
	userBtc          int64
	poolAtom          int64
	poolBtc          int64
	routerAtom        int64
	routerBtc        int64
	protocolFeeAtom   int64
	protocolFeeBtc   int64
}

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
		userAtom:          atom.BalanceOf(userAddr),
		userBtc:          btc.BalanceOf(userAddr),
		poolAtom:          atom.BalanceOf(poolAddr),
		poolBtc:          btc.BalanceOf(poolAddr),
		routerAtom:        atom.BalanceOf(routerAddr),
		routerBtc:        btc.BalanceOf(routerAddr),
		protocolFeeAtom:   atom.BalanceOf(protocolFeeAddr),
		protocolFeeBtc:   btc.BalanceOf(protocolFeeAddr),
	}

	return snapshot
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User ATOM balance:", snapshot.userAtom)
	println("[EXPECTED] User BTC balance:", snapshot.userBtc)
	println("[EXPECTED] Pool ATOM balance:", snapshot.poolAtom)
	println("[EXPECTED] Pool BTC balance:", snapshot.poolBtc)
	println("[EXPECTED] Router ATOM balance:", snapshot.routerAtom)
	println("[EXPECTED] Router BTC balance:", snapshot.routerBtc)
	println("[EXPECTED] Protocol fee ATOM balance:", snapshot.protocolFeeAtom)
	println("[EXPECTED] Protocol fee BTC balance:", snapshot.protocolFeeBtc)
}

func setupEnvironment() BalanceSnapshot {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	atom.Transfer(cross, userAddr, initialBalance)
	btc.Transfer(cross, userAddr, initialBalance)

	testing.SetRealm(userRealm)
	return getBalanceSnapshot()
}

func setupPoolAndPosition() BalanceSnapshot {
	testing.SetRealm(userRealm)

	// Create pool
	pl.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	atom.Approve(cross, poolAddr, max_approve)
	btc.Approve(cross, poolAddr, max_approve)

	// Mint very large position for extreme swaps
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		int32(-50000), // very wide range
		int32(50000),
		"500000000000", // 500 billion
		"500000000000",
		"0",
		"0",
		max_timeout,
		userAddr,
		"",
	)

	println("[INFO] Large Position ID:", tokenId)
	println("[INFO] Liquidity:", liquidity)
	println("[INFO] Amount0 (ATOM):", amount0)
	println("[INFO] Amount1 (BTC):", amount1)

	return getBalanceSnapshot()
}

func performLargeSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	btc.Approve(cross, routerAddr, max_approve)

	// Swap 90% of pool's BTC liquidity
	swapAmount := int64(450_000_000_000) // 90% of 500B
	println("[INFO] Extreme Swap: Swapping", swapAmount, "BTC -> ATOM (90% of liquidity)")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		btcPath,
		atomPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:500",
		"100",
		"1", // minimal output requirement
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Large Swap - In:", amountIn, "Out:", amountOut)
	println("[INFO] Expected: Massive price impact and slippage")

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performReverseSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	atom.Approve(cross, routerAddr, max_approve)

	// Swap back with exact out
	swapAmount := int64(200_000_000_000)
	println("[INFO] Reverse Swap: Getting", swapAmount, "BTC back")

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath,
		btcPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:500",
		"100",
		ufmt.Sprintf("%d", max_approve), // allow max slippage
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Reverse Swap - In:", amountIn, "Out:", amountOut)

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performSmallSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(userRealm)

	btc.Approve(cross, routerAddr, max_approve)

	// Very small swap after extreme price movement
	swapAmount := int64(1_000_000) // just 1M
	println("[INFO] Small Swap: Swapping", swapAmount, "BTC -> ATOM (after extreme movement)")

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		btcPath,
		atomPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/gnoswap/test_token/btc:gno.land/r/gnoswap/test_token/atom:500",
		"100",
		"1",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Small Swap - In:", amountIn, "Out:", amountOut)

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance conservation for", swapType)

	userAtomDiff := after.userAtom - before.userAtom
	userBtcDiff := after.userBtc - before.userBtc
	poolAtomDiff := after.poolAtom - before.poolAtom
	poolBtcDiff := after.poolBtc - before.poolBtc
	protocolFeeAtomDiff := after.protocolFeeAtom - before.protocolFeeAtom
	protocolFeeBtcDiff := after.protocolFeeBtc - before.protocolFeeBtc

	println("[EXPECTED] User ATOM change:", userAtomDiff)
	println("[EXPECTED] User BTC change:", userBtcDiff)
	println("[EXPECTED] Pool ATOM change:", poolAtomDiff)
	println("[EXPECTED] Pool BTC change:", poolBtcDiff)
	println("[EXPECTED] Protocol Fee ATOM change:", protocolFeeAtomDiff)
	println("[EXPECTED] Protocol Fee BTC change:", protocolFeeBtcDiff)

	// Router must be empty
	assertRouterIsEmpty(after)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalAtomChange := userAtomDiff + poolAtomDiff + protocolFeeAtomDiff
	totalBtcChange := userBtcDiff + poolBtcDiff + protocolFeeBtcDiff

	if totalAtomChange != 0 {
		panic(ufmt.Sprintf("[ERROR] ATOM not conserved in swap! Total change: %d", totalAtomChange))
	}
	if totalBtcChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BTC not conserved in swap! Total change: %d", totalBtcChange))
	}

	println("[EXPECTED] Exact balance conservation verified - all tokens accounted for")
}

func validateSmallSwapImpact(before, after BalanceSnapshot) {
	println("[INFO] Validating small swap impact")

	userAtomDiff := after.userAtom - before.userAtom
	userBtcDiff := after.userBtc - before.userBtc

	println("[EXPECTED] Small swap caused minimal balance change")
	println("[EXPECTED] User ATOM change:", userAtomDiff)
	println("[EXPECTED] User BTC change:", userBtcDiff)

	// Small swap should have actual token movements
	if userAtomDiff == 0 && userBtcDiff == 0 {
		panic("[ERROR] Small swap had no effect")
	}

	// Verify swap direction is correct (BTC in, ATOM out)
	if userBtcDiff >= 0 {
		panic("[ERROR] User BTC should decrease in small swap")
	}
	if userAtomDiff <= 0 {
		panic("[ERROR] User ATOM should increase in small swap")
	}

	println("[EXPECTED] Small swap executed correctly despite extreme price")
}

func assertRouterIsEmpty(snapshot BalanceSnapshot) {
	if snapshot.routerAtom != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has ATOM balance: %d - funds stuck!", snapshot.routerAtom))
	}
	if snapshot.routerBtc != 0 {
		panic(ufmt.Sprintf("[ERROR] Router has BTC balance: %d - funds stuck!", snapshot.routerBtc))
	}
}

func validateSystemBalance(initial, final BalanceSnapshot) {
	println("[INFO] Validating system-wide balance conservation")

	// Total supply in system should be conserved
	// User + Pool + Router + ProtocolFee = Initial Supply

	totalAtomInitial := initial.userAtom + initial.poolAtom + initial.routerAtom + initial.protocolFeeAtom
	totalAtomFinal := final.userAtom + final.poolAtom + final.routerAtom + final.protocolFeeAtom

	totalBtcInitial := initial.userBtc + initial.poolBtc + initial.routerBtc + initial.protocolFeeBtc
	totalBtcFinal := final.userBtc + final.poolBtc + final.routerBtc + final.protocolFeeBtc

	println("[EXPECTED] Total ATOM - Initial:", totalAtomInitial, "Final:", totalAtomFinal)
	println("[EXPECTED] Total BTC - Initial:", totalBtcInitial, "Final:", totalBtcFinal)

	if totalAtomInitial != totalAtomFinal {
		panic("[ERROR] ATOM tokens were created or destroyed!")
	}

	if totalBtcInitial != totalBtcFinal {
		panic("[ERROR] BTC tokens were created or destroyed!")
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
// [EXPECTED] User ATOM balance: 1000000000000
// [EXPECTED] User BTC balance: 1000000000000
// [EXPECTED] Pool ATOM balance: 0
// [EXPECTED] Pool BTC balance: 0
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 2. Create Pool & Mint Large Position
// [INFO] Large Position ID: 1
// [INFO] Liquidity: 544718833860
// [INFO] Amount0 (ATOM): 500000000000
// [INFO] Amount1 (BTC): 500000000000
// [INFO] After Setup
// [EXPECTED] User ATOM balance: 500000000000
// [EXPECTED] User BTC balance: 500000000000
// [EXPECTED] Pool ATOM balance: 500000000000
// [EXPECTED] Pool BTC balance: 500000000000
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 3. Extreme Case 1: Very Large Swap (90% of liquidity)
// [INFO] Extreme Swap: Swapping 450000000000 BTC -> ATOM (90% of liquidity)
// [INFO] Large Swap - In: 450000000000 Out: -245987862163
// [INFO] Expected: Massive price impact and slippage
// [INFO] After Large Swap
// [EXPECTED] User ATOM balance: 745987862163
// [EXPECTED] User BTC balance: 50000000000
// [EXPECTED] Pool ATOM balance: 253642601740
// [EXPECTED] Pool BTC balance: 950000000000
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 369536097
// [EXPECTED] Protocol fee BTC balance: 0
// [INFO] Validating balance conservation for Large ExactIn
// [EXPECTED] User ATOM change: 245987862163
// [EXPECTED] User BTC change: -450000000000
// [EXPECTED] Pool ATOM change: -246357398260
// [EXPECTED] Pool BTC change: 450000000000
// [EXPECTED] Protocol Fee ATOM change: 369536097
// [EXPECTED] Protocol Fee BTC change: 0
// [EXPECTED] Exact balance conservation verified - all tokens accounted for
//
// [SCENARIO] 4. Extreme Case 2: Swap Back with High Slippage
// [INFO] Reverse Swap: Getting 200000000000 BTC back
// [INFO] Reverse Swap - In: 75286230276 Out: -200000000000
// [INFO] After Reverse Swap
// [EXPECTED] User ATOM balance: 670701631887
// [EXPECTED] User BTC balance: 250000000000
// [EXPECTED] Pool ATOM balance: 328928832016
// [EXPECTED] Pool BTC balance: 749699549324
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 369536097
// [EXPECTED] Protocol fee BTC balance: 300450676
// [INFO] Validating balance conservation for Large ExactOut
// [EXPECTED] User ATOM change: -75286230276
// [EXPECTED] User BTC change: 200000000000
// [EXPECTED] Pool ATOM change: 75286230276
// [EXPECTED] Pool BTC change: -200300450676
// [EXPECTED] Protocol Fee ATOM change: 0
// [EXPECTED] Protocol Fee BTC change: 300450676
// [EXPECTED] Exact balance conservation verified - all tokens accounted for
//
// [SCENARIO] 5. Extreme Case 3: Small Swap After Large Price Movement
// [INFO] Small Swap: Swapping 1000000 BTC -> ATOM (after extreme movement)
// [INFO] Small Swap - In: 1000000 Out: -469486
// [INFO] After Small Swap
// [EXPECTED] User ATOM balance: 670702101373
// [EXPECTED] User BTC balance: 249999000000
// [EXPECTED] Pool ATOM balance: 328928361825
// [EXPECTED] Pool BTC balance: 749700549324
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 369536802
// [EXPECTED] Protocol fee BTC balance: 300450676
// [INFO] Validating balance conservation for Small ExactIn
// [EXPECTED] User ATOM change: 469486
// [EXPECTED] User BTC change: -1000000
// [EXPECTED] Pool ATOM change: -470191
// [EXPECTED] Pool BTC change: 1000000
// [EXPECTED] Protocol Fee ATOM change: 705
// [EXPECTED] Protocol Fee BTC change: 0
// [EXPECTED] Exact balance conservation verified - all tokens accounted for
// [INFO] Validating small swap impact
// [EXPECTED] Small swap caused minimal balance change
// [EXPECTED] User ATOM change: 469486
// [EXPECTED] User BTC change: -1000000
// [EXPECTED] Small swap executed correctly despite extreme price
//
// [SCENARIO] 6. Final Validation: Total System Balance Conservation
// [INFO] Validating system-wide balance conservation
// [EXPECTED] Total ATOM - Initial: 1000000000000 Final: 1000000000000
// [EXPECTED] Total BTC - Initial: 1000000000000 Final: 1000000000000
// [EXPECTED] System-wide balance perfectly conserved
// [EXPECTED] No tokens leaked, created, or destroyed in extreme scenarios
//
// [SCENARIO] Complete - All extreme case validations passed
