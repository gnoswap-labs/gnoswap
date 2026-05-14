// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

var t *testing.T

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806

	MAX_INT64 string = "9223372036854775807"
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = testing.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(12000)
	poolCreationFee = int64(100_000_000)

	test_liquidityExpectStr = "10000000000"

	MIN_PRICE string = "4295128740"
)

// turn protocol fee on
func init() {
	testing.SetRealm(adminRealm)
	pool.SetFeeProtocol(cross, 4, 4)
}

func main() {
	println("[SCENARIO] Limit Order Thru Negative 1 With Fee")
	println("[INFO] Starting scenario: Limit order thru negative 1 with fee")

	println("[INFO] Setting up pool with specific tick")

	println("[INFO] Approving pool creation fee")
	println()
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, atomPath, btcPath, fee500, common.TickMathGetSqrtRatioAtTick(-1).ToString())

	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)

	thisPool, _ := pool.GetPool(atomPath, btcPath, fee500)

	println("[SCENARIO] 1. Minting position spanning current tick")
	testing.SetRealm(posRealm)
	mint0, mint1 := pool.Mint(
		cross,
		atomPath,
		btcPath,
		fee500,
		-120,
		0,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[EXPECTED] mint0:", mint0, "expected: 499988")
	println("[EXPECTED] mint1:", mint1, "expected: 59317416")
	println()

	println("[SCENARIO] 2. Swapping 0 -> 1")

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	swap0, swap1 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		true,
		"60283363",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
	)
	println("[EXPECTED] swap0:", swap0, "expected: 59707210")
	println("[EXPECTED] swap1:", swap1, "expected: -59317415")
	println()

	println("[SCENARIO] 3. Burning position")
	testing.SetRealm(posRealm)
	burn0, burn1 := pool.Burn(
		cross,
		atomPath,
		btcPath,
		fee500,
		-120,
		0,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[EXPECTED] burn0:", burn0, "expected: 60177342")
	println("[EXPECTED] burn1:", burn1, "expected: 0")
	println()

	println("[SCENARIO] 4. Collecting position")
	testing.SetRealm(posRealm)
	collect0, collect1 := pool.Collect(
		cross,
		atomPath,
		btcPath,
		fee500,
		adminAddr,
		-120,
		0,
		MAX_INT64,
		MAX_INT64,
	)
	println("[EXPECTED] collect0:", collect0, "expected: 60199732")
	println("[EXPECTED] collect1:", collect1, "expected: 0")
	println()

	thisPool, _ = pool.GetPool(atomPath, btcPath, fee500)
	slotTick := thisPool.Slot0Tick()
	println("[EXPECTED] Pool tick:", slotTick, "expected: < -120")
	uassert.True(t, slotTick < -120, ufmt.Sprintf("tick(%d) should be < -120", slotTick))
	println()
	println("[INFO] Scenario completed")
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
// [SCENARIO] Limit Order Thru Negative 1 With Fee
// [INFO] Starting scenario: Limit order thru negative 1 with fee
// [INFO] Setting up pool with specific tick
// [INFO] Approving pool creation fee
//
// [SCENARIO] 1. Minting position spanning current tick
// [EXPECTED] mint0: 499988 expected: 499988
// [EXPECTED] mint1: 59317416 expected: 59317416
//
// [SCENARIO] 2. Swapping 0 -> 1
// [EXPECTED] swap0: 59707210 expected: 59707210
// [EXPECTED] swap1: -59317415 expected: -59317415
//
// [SCENARIO] 3. Burning position
// [EXPECTED] burn0: 60177342 expected: 60177342
// [EXPECTED] burn1: 0 expected: 0
//
// [SCENARIO] 4. Collecting position
// [EXPECTED] collect0: 60199732 expected: 60199732
// [EXPECTED] collect1: 0 expected: 0
//
// [EXPECTED] Pool tick: -887272 expected: < -120
//
// [INFO] Scenario completed
