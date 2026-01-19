// Scenario: Swap with Zero Amount Delta
// Purpose: Verify that swaps can complete successfully even when token deltas are zero
// This tests the refactoring that removed the panic on zero swap amounts

// PKGPATH: gno.land/r/gnoswap/pool/swap_zero_amount

package swap_zero_amount

import (
	"testing"

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

var (
	callbackAmount0Delta int64
	callbackAmount1Delta int64
	callbackCalled       bool
)

func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 6, 6)
}

func main() {
	println("[SCENARIO] Swap with Zero Amount Delta")
	println("[INFO] Purpose: Verify swaps complete successfully with zero deltas")
	println()

	println("[SCENARIO] 1. Setup Pool")
	setupPool()
	println()

	println("[SCENARIO] 2. Execute Swap with Minimal Amount (amount1=0 case)")
	testZeroAmountSwap()
	println()

	println("[SCENARIO] Complete - Zero amount swap handled correctly")
}

func setupPool() {
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
		-887220,
		887220,
		"1000000",
		adminAddr,
	)

	println("[INFO] Pool created at 1:1 price")
	println("[EXPECTED] Minted amounts - bar:", amount0, "foo:", amount1)
}

func testZeroAmountSwap() {
	testing.SetRealm(adminRealm)

	pools, _ := pool.GetPool(barPath, fooPath, fee500)
	tickBefore := pools.Slot0Tick()

	println("[INFO] Attempting swap with amount: 1")

	bar.Approve(cross, poolAddr, 1)

	callbackCalled = false
	callbackAmount0Delta = 0
	callbackAmount1Delta = 0

	testing.SetRealm(routerRealm)
	swapAmount0, swapAmount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return zeroAmountSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	pools, _ = pool.GetPool(barPath, fooPath, fee500)
	tickAfter := pools.Slot0Tick()

	println("[INFO] Swap completed successfully")
	println("[EXPECTED] Swap result - amount0:", swapAmount0, "amount1:", swapAmount1)
	println("[EXPECTED] Tick change:", tickBefore, "->", tickAfter)

	if callbackCalled {
		println("[INFO] Callback was invoked")
		println("[EXPECTED] Callback amount0Delta:", callbackAmount0Delta)
		println("[EXPECTED] Callback amount1Delta:", callbackAmount1Delta)

		if callbackAmount0Delta == 0 && callbackAmount1Delta == 0 {
			println("[EXPECTED] Both deltas are zero - edge case handled correctly")
		} else if callbackAmount0Delta == 0 {
			println("[EXPECTED] amount0Delta is zero - partial zero handled correctly")
		} else if callbackAmount1Delta == 0 {
			println("[EXPECTED] amount1Delta is zero - partial zero handled correctly")
		} else {
			println("[EXPECTED] Normal swap with callback - amount0Delta:", callbackAmount0Delta, "amount1Delta:", callbackAmount1Delta)
		}
	} else {
		println("[INFO] Callback was not invoked (amounts too small for transfer)")
		println("[EXPECTED] Swap completed without panic despite zero amounts")
	}
}

func zeroAmountSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	callbackCalled = true
	callbackAmount0Delta = amount0Delta
	callbackAmount1Delta = amount1Delta

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Swap with Zero Amount Delta
// [INFO] Purpose: Verify swaps complete successfully with zero deltas
//
// [SCENARIO] 1. Setup Pool
// [INFO] Pool created at 1:1 price
// [EXPECTED] Minted amounts - bar: 1000000 foo: 1000000
//
// [SCENARIO] 2. Execute Swap with Minimal Amount (amount1=0 case)
// [INFO] Attempting swap with amount: 1
// [INFO] Swap completed successfully
// [EXPECTED] Swap result - amount0: 1 amount1: 0
// [EXPECTED] Tick change: 0 -> -1
// [INFO] Callback was invoked
// [EXPECTED] Callback amount0Delta: 1
// [EXPECTED] Callback amount1Delta: 0
// [EXPECTED] amount1Delta is zero - partial zero handled correctly
//
// [SCENARIO] Complete - Zero amount swap handled correctly

