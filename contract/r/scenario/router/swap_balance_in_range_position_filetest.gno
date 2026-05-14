// Scenario: Swap Balance Validation - In Range Position
// Purpose: Validate balance changes with in-range position swaps that cause price movement

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

	initialBalance int64 = 100_000_000_000
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

	println("[SCENARIO] 4. Exact In Swap (BTC -> ATOM)")
	afterExactIn := performExactInSwap()
	printBalanceSnapshot("After Exact In Swap", afterExactIn)
	validateBalanceChange(afterMint, afterExactIn, "ExactIn")
	println()

	println("[SCENARIO] 5. Exact Out Swap (ATOM -> BTC)")
	afterExactOut := performExactOutSwap()
	printBalanceSnapshot("After Exact Out Swap", afterExactOut)
	validateBalanceChange(afterExactIn, afterExactOut, "ExactOut")
	println()

	println("[SCENARIO] 6. System Balance Conservation Check")
	validateSystemBalance(initial, afterExactOut)
	println()

	println("[SCENARIO] Complete - All balance validations passed")
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

func createPool() BalanceSnapshot {
	testing.SetRealm(userRealm)

	pl.CreatePool(
		cross,
		atomPath,
		btcPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	return getBalanceSnapshot()
}

func mintInRangePosition() BalanceSnapshot {
	testing.SetRealm(userRealm)

	atom.Approve(cross, poolAddr, max_approve)
	btc.Approve(cross, poolAddr, max_approve)

	// Mint position covering wide range around current price (tick 0)
	// This ensures the position stays in range during swaps
	tokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		int32(-10000), // tickLower
		int32(10000),  // tickUpper
		"50000000000", // amount0Desired (ATOM)
		"50000000000", // amount1Desired (BTC)
		"0",           // amount0Min
		"0",           // amount1Min
		max_timeout,
		userAddr,
		"",
	)

	println("[INFO] Minted position ID:", tokenId)
	println("[INFO] Liquidity:", liquidity)
	println("[INFO] Amount0 (ATOM):", amount0)
	println("[INFO] Amount1 (BTC):", amount1)

	return getBalanceSnapshot()
}

func performExactInSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	btc.Approve(cross, routerAddr, max_approve)
	atom.Approve(cross, routerAddr, max_approve)

	// Swap BTC -> ATOM (exact in)
	// This should increase the price (more BTC in pool, less ATOM)
	swapAmount := int64(10_000_000_000)
	println("[INFO] Swapping", swapAmount, "BTC -> ATOM")

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

	println("[INFO] Exact In - In:", amountIn, "Out:", amountOut)

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func performExactOutSwap() BalanceSnapshot {
	testing.SetRealm(userRealm)

	atom.Approve(cross, routerAddr, max_approve)
	btc.Approve(cross, routerAddr, max_approve)

	// Swap ATOM -> BTC (exact out)
	// This should decrease the price (more ATOM in pool, less BTC)
	swapAmount := int64(5_000_000_000)
	println("[INFO] Swapping ATOM ->", swapAmount, "BTC")

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath,
		btcPath,
		ufmt.Sprintf("%d", swapAmount),
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:500",
		"100",
		ufmt.Sprintf("%d", max_approve),
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[INFO] Exact Out - In:", amountIn, "Out:", amountOut)

	snapshot := getBalanceSnapshot()
	assertRouterIsEmpty(snapshot)
	return snapshot
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	// User balance should change (tokens swapped)
	userAtomDiff := after.userAtom - before.userAtom
	userBtcDiff := after.userBtc - before.userBtc

	// Pool balance should change (opposite of user)
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

	// Router should have zero balance after swap (no stuck funds)
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

	println("[EXPECTED] Exact balance conservation verified for", swapType)
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
}

// Output:
// [SCENARIO] Swap Balance Validation - In Range Position
// [INFO] Purpose: Validate balance changes with in-range position swaps
//
// [SCENARIO] 1. Initial Setup
// [INFO] Initial State
// [EXPECTED] User ATOM balance: 100000000000
// [EXPECTED] User BTC balance: 100000000000
// [EXPECTED] Pool ATOM balance: 0
// [EXPECTED] Pool BTC balance: 0
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 2. Create Pool
// [INFO] After Pool Creation
// [EXPECTED] User ATOM balance: 100000000000
// [EXPECTED] User BTC balance: 100000000000
// [EXPECTED] Pool ATOM balance: 0
// [EXPECTED] Pool BTC balance: 0
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 3. Mint In-Range Position
// [INFO] Minted position ID: 1
// [INFO] Liquidity: 127079601172
// [INFO] Amount0 (ATOM): 50000000000
// [INFO] Amount1 (BTC): 50000000000
// [INFO] After Position Mint
// [EXPECTED] User ATOM balance: 50000000000
// [EXPECTED] User BTC balance: 50000000000
// [EXPECTED] Pool ATOM balance: 50000000000
// [EXPECTED] Pool BTC balance: 50000000000
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 0
// [EXPECTED] Protocol fee BTC balance: 0
//
// [SCENARIO] 4. Exact In Swap (BTC -> ATOM)
// [INFO] Swapping 10000000000 BTC -> ATOM
// [INFO] Exact In - In: 10000000000 Out: -9252300294
// [INFO] After Exact In Swap
// [EXPECTED] User ATOM balance: 59252300294
// [EXPECTED] User BTC balance: 40000000000
// [EXPECTED] Pool ATOM balance: 40733800407
// [EXPECTED] Pool BTC balance: 60000000000
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 13899299
// [EXPECTED] Protocol fee BTC balance: 0
// [INFO] Validating balance changes for ExactIn
// [EXPECTED] User ATOM change: 9252300294
// [EXPECTED] User BTC change: -10000000000
// [EXPECTED] Pool ATOM change: -9266199593
// [EXPECTED] Pool BTC change: 10000000000
// [EXPECTED] Protocol Fee ATOM change: 13899299
// [EXPECTED] Protocol Fee BTC change: 0
// [EXPECTED] Exact balance conservation verified for ExactIn
//
// [SCENARIO] 5. Exact Out Swap (ATOM -> BTC)
// [INFO] Swapping ATOM -> 5000000000 BTC
// [INFO] Exact Out - In: 4469297080 Out: -5000000000
// [INFO] After Exact Out Swap
// [EXPECTED] User ATOM balance: 54783003214
// [EXPECTED] User BTC balance: 45000000000
// [EXPECTED] Pool ATOM balance: 45203097487
// [EXPECTED] Pool BTC balance: 54992488734
// [EXPECTED] Router ATOM balance: 0
// [EXPECTED] Router BTC balance: 0
// [EXPECTED] Protocol fee ATOM balance: 13899299
// [EXPECTED] Protocol fee BTC balance: 7511266
// [INFO] Validating balance changes for ExactOut
// [EXPECTED] User ATOM change: -4469297080
// [EXPECTED] User BTC change: 5000000000
// [EXPECTED] Pool ATOM change: 4469297080
// [EXPECTED] Pool BTC change: -5007511266
// [EXPECTED] Protocol Fee ATOM change: 0
// [EXPECTED] Protocol Fee BTC change: 7511266
// [EXPECTED] Exact balance conservation verified for ExactOut
//
// [SCENARIO] 6. System Balance Conservation Check
// [INFO] Validating system-wide balance conservation
// [EXPECTED] Total ATOM - Initial: 100000000000 Final: 100000000000
// [EXPECTED] Total BTC - Initial: 100000000000 Final: 100000000000
// [EXPECTED] System-wide balance perfectly conserved
//
// [SCENARIO] Complete - All balance validations passed
