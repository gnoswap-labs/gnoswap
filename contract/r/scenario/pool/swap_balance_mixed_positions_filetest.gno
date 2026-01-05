// Scenario: Swap Balance Validation - Mixed Position Ranges
// Purpose: Validate that out-of-range positions don't affect swap balance calculations

// PKGPATH: gno.land/r/gnoswap/pool/swap_balance_mixed

package swap_balance_mixed

import (
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
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
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"
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
	userBaz         int64
	userQux         int64
	poolBaz         int64
	poolQux         int64
	protocolFeeBaz  int64
	protocolFeeQux  int64
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
		userBaz:        baz.BalanceOf(adminAddr),
		userQux:        qux.BalanceOf(adminAddr),
		poolBaz:        baz.BalanceOf(poolAddr),
		poolQux:        qux.BalanceOf(poolAddr),
		protocolFeeBaz: baz.BalanceOf(protocolFeeAddr),
		protocolFeeQux: qux.BalanceOf(protocolFeeAddr),
	}
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User BAZ balance:", snapshot.userBaz)
	println("[EXPECTED] User QUX balance:", snapshot.userQux)
	println("[EXPECTED] Pool BAZ balance:", snapshot.poolBaz)
	println("[EXPECTED] Pool QUX balance:", snapshot.poolQux)
	println("[EXPECTED] Protocol fee BAZ balance:", snapshot.protocolFeeBaz)
	println("[EXPECTED] Protocol fee QUX balance:", snapshot.protocolFeeQux)
}

func setupPoolWithMixedPositions() BalanceSnapshot {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, bazPath, quxPath, fee500, "79228162514264337593543950336")

	qux.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	inRangeAmount0, inRangeAmount1 := pool.Mint(
		cross,
		bazPath,
		quxPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	outOfRangeAmount0, outOfRangeAmount1 := pool.Mint(
		cross,
		bazPath,
		quxPath,
		fee500,
		2000,
		4000,
		"500000000",
		adminAddr,
	)

	pools := pool.GetPool(bazPath, quxPath, fee500)
	currentLiquidity := pools.Liquidity().ToString()

	println("[INFO] In-range position (-1000 to 1000):", inRangeAmount0, inRangeAmount1)
	println("[INFO] Out-of-range position (2000 to 4000):", outOfRangeAmount0, outOfRangeAmount1)
	println("[INFO] Active liquidity:", currentLiquidity)

	return getBalanceSnapshot()
}

func testExactInputWithMixedPositions(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools := pool.GetPool(bazPath, quxPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping 200000 BAZ -> QUX (exact input)")

	baz.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		bazPath,
		quxPath,
		fee500,
		adminAddr,
		true,
		"200000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(bazPath, quxPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(bazPath, quxPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func testExactOutputWithMixedPositions(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools := pool.GetPool(bazPath, quxPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping QUX -> 80000 BAZ (exact output)")

	qux.Approve(cross, poolAddr, 300000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		bazPath,
		quxPath,
		fee500,
		adminAddr,
		false,
		"-80000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(bazPath, quxPath, amount0Delta, amount1Delta)
		},
	)

	pools = pool.GetPool(bazPath, quxPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	userBazDiff := after.userBaz - before.userBaz
	userQuxDiff := after.userQux - before.userQux
	poolBazDiff := after.poolBaz - before.poolBaz
	poolQuxDiff := after.poolQux - before.poolQux
	protocolFeeBazDiff := after.protocolFeeBaz - before.protocolFeeBaz
	protocolFeeQuxDiff := after.protocolFeeQux - before.protocolFeeQux

	println("[EXPECTED] User BAZ change:", userBazDiff)
	println("[EXPECTED] User QUX change:", userQuxDiff)
	println("[EXPECTED] Pool BAZ change:", poolBazDiff)
	println("[EXPECTED] Pool QUX change:", poolQuxDiff)
	println("[EXPECTED] Protocol Fee BAZ change:", protocolFeeBazDiff)
	println("[EXPECTED] Protocol Fee QUX change:", protocolFeeQuxDiff)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalBazChange := userBazDiff + poolBazDiff + protocolFeeBazDiff
	totalQuxChange := userQuxDiff + poolQuxDiff + protocolFeeQuxDiff

	if totalBazChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BAZ not conserved! Total change: %d", totalBazChange))
	}
	if totalQuxChange != 0 {
		panic(ufmt.Sprintf("[ERROR] QUX not conserved! Total change: %d", totalQuxChange))
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
// [EXPECTED] User BAZ balance: 99999908180300
// [EXPECTED] User QUX balance: 99999951231802
// [EXPECTED] Pool BAZ balance: 91819700
// [EXPECTED] Pool QUX balance: 48768198
// [EXPECTED] Protocol fee BAZ balance: 0
// [EXPECTED] Protocol fee QUX balance: 0
//
// [SCENARIO] 2. ExactInput Swap with Mixed Positions
// [INFO] Swapping 200000 BAZ -> QUX (exact input)
// [INFO] Swap - In: 200000 Out: -199860
// [INFO] Tick: 0 -> -4
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactInput Swap
// [EXPECTED] User BAZ balance: 99999907980300
// [EXPECTED] User QUX balance: 99999951431662
// [EXPECTED] Pool BAZ balance: 92019700
// [EXPECTED] Pool QUX balance: 48568338
// [EXPECTED] Protocol fee BAZ balance: 0
// [EXPECTED] Protocol fee QUX balance: 0
// [INFO] Validating balance changes for ExactInput
// [EXPECTED] User BAZ change: -200000
// [EXPECTED] User QUX change: 199860
// [EXPECTED] Pool BAZ change: 200000
// [EXPECTED] Pool QUX change: -199860
// [EXPECTED] Protocol Fee BAZ change: 0
// [EXPECTED] Protocol Fee QUX change: 0
// [EXPECTED] Exact balance conservation verified for ExactInput
//
// [SCENARIO] 3. ExactOutput Swap with Mixed Positions
// [INFO] Swapping QUX -> 80000 BAZ (exact output)
// [INFO] Swap - In: -80000 Out: 80016
// [INFO] Tick: -4 -> -3
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactOutput Swap
// [EXPECTED] User BAZ balance: 99999908060300
// [EXPECTED] User QUX balance: 99999951351646
// [EXPECTED] Pool BAZ balance: 91939700
// [EXPECTED] Pool QUX balance: 48648354
// [EXPECTED] Protocol fee BAZ balance: 0
// [EXPECTED] Protocol fee QUX balance: 0
// [INFO] Validating balance changes for ExactOutput
// [EXPECTED] User BAZ change: 80000
// [EXPECTED] User QUX change: -80016
// [EXPECTED] Pool BAZ change: -80000
// [EXPECTED] Pool QUX change: 80016
// [EXPECTED] Protocol Fee BAZ change: 0
// [EXPECTED] Protocol Fee QUX change: 0
// [EXPECTED] Exact balance conservation verified for ExactOutput
//
// [SCENARIO] Complete - All mixed position validations passed
