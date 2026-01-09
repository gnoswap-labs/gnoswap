// Scenario: Swap Balance Validation - Single In-Range Position
// Purpose: Validate exact balance conservation for basic in-range position swaps

// PKGPATH: gno.land/r/gnoswap/pool/swap_balance_single

package swap_balance_single

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
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
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
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
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
	userBar        int64
	userFoo        int64
	poolBar        int64
	poolFoo        int64
	protocolFeeBar int64
	protocolFeeFoo int64
}

func main() {
	println("[SCENARIO] Swap Balance Validation - Single In-Range Position")
	println("[INFO] Purpose: Validate exact balance conservation for basic in-range swaps")
	println()

	println("[SCENARIO] 1. Setup Pool with In-Range Position")
	initial := setupPool()
	printBalanceSnapshot("After Pool Setup", initial)
	println()

	println("[SCENARIO] 2. ExactInput Swap (BAR -> FOO)")
	afterExactIn := testExactInputSwap(initial)
	printBalanceSnapshot("After ExactInput Swap", afterExactIn)
	validateBalanceChange(initial, afterExactIn, "ExactInput")
	println()

	println("[SCENARIO] 3. ExactOutput Swap (FOO -> BAR)")
	afterExactOut := testExactOutputSwap(afterExactIn)
	printBalanceSnapshot("After ExactOutput Swap", afterExactOut)
	validateBalanceChange(afterExactIn, afterExactOut, "ExactOutput")
	println()

	println("[SCENARIO] Complete - All in-range position validations passed")
}

func getBalanceSnapshot() BalanceSnapshot {
	return BalanceSnapshot{
		userBar:        bar.BalanceOf(adminAddr),
		userFoo:        foo.BalanceOf(adminAddr),
		poolBar:        bar.BalanceOf(poolAddr),
		poolFoo:        foo.BalanceOf(poolAddr),
		protocolFeeBar: bar.BalanceOf(protocolFeeAddr),
		protocolFeeFoo: foo.BalanceOf(protocolFeeAddr),
	}
}

func printBalanceSnapshot(step string, snapshot BalanceSnapshot) {
	println("[INFO]", step)
	println("[EXPECTED] User BAR balance:", snapshot.userBar)
	println("[EXPECTED] User FOO balance:", snapshot.userFoo)
	println("[EXPECTED] Pool BAR balance:", snapshot.poolBar)
	println("[EXPECTED] Pool FOO balance:", snapshot.poolFoo)
	println("[EXPECTED] Protocol fee BAR balance:", snapshot.protocolFeeBar)
	println("[EXPECTED] Protocol fee FOO balance:", snapshot.protocolFeeFoo)
}

func setupPool() BalanceSnapshot {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, "79228162514264337593543950336")

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	testing.SetRealm(posRealm)
	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		"1000000000",
		adminAddr,
	)

	println("[INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)")
	println("[INFO] Minted amounts - bar:", amount0, "foo:", amount1)

	return getBalanceSnapshot()
}

func testExactInputSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping 100000 BAR -> FOO (exact input)")

	bar.Approve(cross, poolAddr, 100000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"100000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func testExactOutputSwap(before BalanceSnapshot) BalanceSnapshot {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := pools.Slot0Tick()
	liquidityBefore := pools.Liquidity().ToString()

	println("[INFO] Swapping FOO -> 50000 BAR (exact output)")

	foo.Approve(cross, poolAddr, 200000)

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		false,
		"-50000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := pools.Slot0Tick()
	liquidityAfter := pools.Liquidity().ToString()

	println("[INFO] Swap - In:", swapAmount0, "Out:", swapAmount1)
	println("[INFO] Tick:", tickBefore, "->", tickAfter)
	println("[INFO] Liquidity: before:", liquidityBefore, "after:", liquidityAfter)

	return getBalanceSnapshot()
}

func validateBalanceChange(before, after BalanceSnapshot, swapType string) {
	println("[INFO] Validating balance changes for", swapType)

	userBarDiff := after.userBar - before.userBar
	userFooDiff := after.userFoo - before.userFoo
	poolBarDiff := after.poolBar - before.poolBar
	poolFooDiff := after.poolFoo - before.poolFoo
	protocolFeeBarDiff := after.protocolFeeBar - before.protocolFeeBar
	protocolFeeFooDiff := after.protocolFeeFoo - before.protocolFeeFoo

	println("[EXPECTED] User BAR change:", userBarDiff)
	println("[EXPECTED] User FOO change:", userFooDiff)
	println("[EXPECTED] Pool BAR change:", poolBarDiff)
	println("[EXPECTED] Pool FOO change:", poolFooDiff)
	println("[EXPECTED] Protocol Fee BAR change:", protocolFeeBarDiff)
	println("[EXPECTED] Protocol Fee FOO change:", protocolFeeFooDiff)

	// Exact conservation: user + pool + protocol fee changes must sum to 0
	totalBarChange := userBarDiff + poolBarDiff + protocolFeeBarDiff
	totalFooChange := userFooDiff + poolFooDiff + protocolFeeFooDiff

	if totalBarChange != 0 {
		panic(ufmt.Sprintf("[ERROR] BAR not conserved! Total change: %d", totalBarChange))
	}
	if totalFooChange != 0 {
		panic(ufmt.Sprintf("[ERROR] FOO not conserved! Total change: %d", totalFooChange))
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
// [SCENARIO] Swap Balance Validation - Single In-Range Position
// [INFO] Purpose: Validate exact balance conservation for basic in-range swaps
//
// [SCENARIO] 1. Setup Pool with In-Range Position
// [INFO] Pool created at 1:1 price with in-range position (-1000 to 1000)
// [INFO] Minted amounts - bar: 48768198 foo: 48768198
// [INFO] After Pool Setup
// [EXPECTED] User BAR balance: 99999951231802
// [EXPECTED] User FOO balance: 99999951231802
// [EXPECTED] Pool BAR balance: 48768198
// [EXPECTED] Pool FOO balance: 48768198
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
//
// [SCENARIO] 2. ExactInput Swap (BAR -> FOO)
// [INFO] Swapping 100000 BAR -> FOO (exact input)
// [INFO] Swap - In: 100000 Out: -99940
// [INFO] Tick: 0 -> -2
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactInput Swap
// [EXPECTED] User BAR balance: 99999951131802
// [EXPECTED] User FOO balance: 99999951331742
// [EXPECTED] Pool BAR balance: 48868198
// [EXPECTED] Pool FOO balance: 48668258
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
// [INFO] Validating balance changes for ExactInput
// [EXPECTED] User BAR change: -100000
// [EXPECTED] User FOO change: 99940
// [EXPECTED] Pool BAR change: 100000
// [EXPECTED] Pool FOO change: -99940
// [EXPECTED] Protocol Fee BAR change: 0
// [EXPECTED] Protocol Fee FOO change: 0
// [EXPECTED] Exact balance conservation verified for ExactInput
//
// [SCENARIO] 3. ExactOutput Swap (FOO -> BAR)
// [INFO] Swapping FOO -> 50000 BAR (exact output)
// [INFO] Swap - In: -50000 Out: 50019
// [INFO] Tick: -2 -> -1
// [INFO] Liquidity: before: 1000000000 after: 1000000000
// [INFO] After ExactOutput Swap
// [EXPECTED] User BAR balance: 99999951181802
// [EXPECTED] User FOO balance: 99999951281723
// [EXPECTED] Pool BAR balance: 48818198
// [EXPECTED] Pool FOO balance: 48718277
// [EXPECTED] Protocol fee BAR balance: 0
// [EXPECTED] Protocol fee FOO balance: 0
// [INFO] Validating balance changes for ExactOutput
// [EXPECTED] User BAR change: 50000
// [EXPECTED] User FOO change: -50019
// [EXPECTED] Pool BAR change: -50000
// [EXPECTED] Pool FOO change: 50019
// [EXPECTED] Protocol Fee BAR change: 0
// [EXPECTED] Protocol Fee FOO change: 0
// [EXPECTED] Exact balance conservation verified for ExactOutput
//
// [SCENARIO] Complete - All in-range position validations passed
