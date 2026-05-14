// Scenario: Swap Balance Validation - Mixed Position Ranges
// Purpose: Validate that out-of-range positions don't affect swap balance calculations

// PKGPATH: gno.land/r/gnoswap/pool/swap_balance_mixed

package swap_balance_mixed

import (
	"testing"

	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/sol"
)

const (
	maxApprove      int64  = 9223372036854775806
	poolCreationFee int64  = 100_000_000
	fee500          uint32 = 500
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	positionAddr, _    = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm           = testing.NewUserRealm(positionAddr)
	routerRealm        = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
)

var (
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"
)

const (
	MIN_PRICE = "4295128740"
	MAX_PRICE = "1461446703485210103287273052203988822378723970341"
)

// turn protocol fee on
func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 6, 6)
}

type BalanceSnapshot struct {
	userAtone         int64
	userSol         int64
	poolAtone         int64
	poolSol         int64
	protocolFeeAtone  int64
	protocolFeeSol  int64
}

func main() {
	println("[SCENARIO] Swap Balance Validation - Mixed Position Ranges")
	println("[INFO] Purpose: Validate out-of-range positions don't affect swaps")
	println()

	println("[SCENARIO] 1. Setup Pool with Mixed Positions")
	initial := setupPoolWithMixedPositions()
	printBalanceSnapshot("After Pool Setup", initial)
	println()

	println("[SCENARIO] 2. ExactInput Swap with Mixed Positions")
	afterExactIn := testExactInputWithMixedPositions(initial)
	printBalanceSnapshot("After ExactInput Swap", afterExactIn)
	validateBalanceChange(initial, afterExactIn, "ExactInput")
	println()

	println("[SCENARIO] 3. ExactOutput Swap with Mixed Positions")
	afterExactOut := testExactOutputWithMixedPositions(afterExactIn)
	printBalanceSnapshot("After ExactOutput Swap", afterExactOut)
	validateBalanceChange(afterExactIn, afterExactOut, "ExactOutput")
	println()

	println("[SCENARIO] Complete - All mixed position validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	return BalanceSnapshot{
		userAtone:        atone.BalanceOf(adminAddr),
		userSol:        sol.BalanceOf(adminAddr),
		poolAtone:        atone.BalanceOf(poolAddr),
		poolSol:        sol.BalanceOf(poolAddr),
		protocolFeeAtone: atone.BalanceOf(protocolFeeAddr),
		protocolFeeSol: sol.BalanceOf(protocolFeeAddr),
	}
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User ATONE balance:", snapshot.userAtone)
	println("[EXPECTED] User SOL balance:", snapshot.userSol)
	println("[EXPECTED] Pool ATONE balance:", snapshot.poolAtone)
	println("[EXPECTED] Pool SOL balance:", snapshot.poolSol)
	println("[EXPECTED] Protocol fee ATONE balance:", snapshot.protocolFeeAtone)
	println("[EXPECTED] Protocol fee SOL balance:", snapshot.protocolFeeSol)
}

func setupPoolWithMixedPositions() BalanceSnapshot {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atonePath, solPath, fee500, "79228162514264337593543950336")

	sol.Approve(cross, poolAddr, maxApprove)
	atone.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	inRangeAmount0, inRangeAmount1 := pool.Mint(
		cross,
		atonePath,
		solPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	outOfRangeAmount0, outOfRangeAmount1 := pool.Mint(
		cross,
		atonePath,
		solPath,
		fee500,
		2000,
		4000,
		"500000000",
		adminAddr,
	)

	pools, _ := pool.GetPool(atonePath, solPath, fee500)
	currentLiquidity := pools.Liquidity().ToString()

	println("[INFO] In-range position (-1000 to 1000):", inRangeAmount0, inRangeAmount1)
	println("[INFO] Out-of-range position (2000 to 4000):", outOfRangeAmount0, outOfRangeAmount1)
	println("[INFO] Active liquidity:", currentLiquidity)

	return getBalanceSnapshot()
}

func testExactInputWithMixedPositions(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(atonePath, solPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping 200000 ATONE -> SOL (exact input)")

	atone.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		atonePath,
		solPath,
		fee500,
		adminAddr,
		true,
		"200000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atonePath, solPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(atonePath, solPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func testExactOutputWithMixedPositions(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(atonePath, solPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping SOL -> 80000 ATONE (exact output)")

	sol.Approve(cross, poolAddr, 300000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		atonePath,
		solPath,
		fee500,
		adminAddr,
		false,
		"-80000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atonePath, solPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(atonePath, solPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	userAtoneDiff := after.userAtone - before.userAtone
	userSolDiff := after.userSol - before.userSol
	poolAtoneDiff := after.poolAtone - before.poolAtone
	poolSolDiff := after.poolSol - before.poolSol
	protocolFeeAtoneDiff := after.protocolFeeAtone - before.protocolFeeAtone
	protocolFeeSolDiff := after.protocolFeeSol - before.protocolFeeSol

	println("[EXPECTED] User ATONE change:", userAtoneDiff)
	println("[EXPECTED] User SOL change:", userSolDiff)
	println("[EXPECTED] Pool ATONE change:", poolAtoneDiff)
	println("[EXPECTED] Pool SOL change:", poolSolDiff)
	println("[EXPECTED] Protocol Fee ATONE change:", protocolFeeAtoneDiff)
	println("[EXPECTED] Protocol Fee SOL change:", protocolFeeSolDiff)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalAtoneChange := userAtoneDiff + poolAtoneDiff + protocolFeeAtoneDiff
	totalSolChange := userSolDiff + poolSolDiff + protocolFeeSolDiff

	if totalAtoneChange != 0 {
		panic(ufmt.Sprintf("[ERROR] ATONE not conserved! Total change: %d", totalAtoneChange))
	}
	if totalSolChange != 0 {
		panic(ufmt.Sprintf("[ERROR] SOL not conserved! Total change: %d", totalSolChange))
	}

	println("[EXPECTED] Exact balance conservation verified for", swapType)
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

// Output:
// [SCENARIO] Swap Balance Validation - Mixed Position Ranges
// [INFO] Purpose: Validate out-of-range positions don't affect swaps
//
// [SCENARIO] 1. Setup Pool with Mixed Positions
// [INFO] In-range position (-1000 to 1000): 48768198 48768198
// [INFO] Out-of-range position (2000 to 4000): 43051502 0
// [INFO] Active liquidity: 1000000000
// [INFO] After Pool Setup
// [EXPECTED] User ATONE balance: 139999908180300
// [EXPECTED] User SOL balance: 599999999951231802
// [EXPECTED] Pool ATONE balance: 91819700
// [EXPECTED] Pool SOL balance: 48768198
// [EXPECTED] Protocol fee ATONE balance: 0
// [EXPECTED] Protocol fee SOL balance: 0
//
// [SCENARIO] 2. ExactInput Swap with Mixed Positions
// [INFO] Swapping 200000 ATONE -> SOL (exact input)
// [INFO] Swap - In: 200000 Out: -199860
// [INFO] Tick: 0 -> -4
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactInput Swap
// [EXPECTED] User ATONE balance: 139999907980300
// [EXPECTED] User SOL balance: 599999999951431662
// [EXPECTED] Pool ATONE balance: 92019700
// [EXPECTED] Pool SOL balance: 48568338
// [EXPECTED] Protocol fee ATONE balance: 0
// [EXPECTED] Protocol fee SOL balance: 0
// [INFO] Validating balance changes for ExactInput
// [EXPECTED] User ATONE change: -200000
// [EXPECTED] User SOL change: 199860
// [EXPECTED] Pool ATONE change: 200000
// [EXPECTED] Pool SOL change: -199860
// [EXPECTED] Protocol Fee ATONE change: 0
// [EXPECTED] Protocol Fee SOL change: 0
// [EXPECTED] Exact balance conservation verified for ExactInput
//
// [SCENARIO] 3. ExactOutput Swap with Mixed Positions
// [INFO] Swapping SOL -> 80000 ATONE (exact output)
// [INFO] Swap - In: -80000 Out: 80016
// [INFO] Tick: -4 -> -3
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactOutput Swap
// [EXPECTED] User ATONE balance: 139999908060300
// [EXPECTED] User SOL balance: 599999999951351646
// [EXPECTED] Pool ATONE balance: 91939700
// [EXPECTED] Pool SOL balance: 48648354
// [EXPECTED] Protocol fee ATONE balance: 0
// [EXPECTED] Protocol fee SOL balance: 0
// [INFO] Validating balance changes for ExactOutput
// [EXPECTED] User ATONE change: 80000
// [EXPECTED] User SOL change: -80016
// [EXPECTED] Pool ATONE change: -80000
// [EXPECTED] Pool SOL change: 80016
// [EXPECTED] Protocol Fee ATONE change: 0
// [EXPECTED] Protocol Fee SOL change: 0
// [EXPECTED] Exact balance conservation verified for ExactOutput
//
// [SCENARIO] Complete - All mixed position validations passed
