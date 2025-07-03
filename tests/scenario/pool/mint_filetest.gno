package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
)

var t *testing.T

// Constants for fee tiers
const (
	fee500 uint32 = 500
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm     = std.NewCodeRealm(consts.ROUTER_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

// Test variables
var (
	test_tickLower  = int32(-6000)
	test_tickUpper  = int32(6000)
	poolCreationFee = int64(100_000_000)

	test_liquidityExpectStr = "1000"
)

func main() {
	println("[SCENARIO] Mint Miscellaneous")
	println("[INFO] Starting scenario: Mint miscellaneous")

	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString()) // tick

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee500)

	println("[SCENARIO] 1. returns 0 before initialization")
	println("[EXPECTED] liquidity:", thisPool.Liquidity().ToString(), "expected: 0")
	println()

	println("[SCENARIO] 2. mint to right of the current price")
	testing.SetRealm(posRealm)
	liqBefore := thisPool.Liquidity().ToString()

	amount0, amount1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		positionAddr,
		1000,
		2000,
		test_liquidityExpectStr,
		adminAddr,
	)

	liqAfter := thisPool.Liquidity().ToString()
	println("[EXPECTED] liquidity:", liqAfter, "expected: ", liqBefore)
	println("[EXPECTED] amount0:", amount0, "expected: 0")
	println("[EXPECTED] amount1:", amount1, "expected: 0")
	println()

	println("[SCENARIO] 3. mint to left of the current price")
	testing.SetRealm(posRealm)
	liqBefore = thisPool.Liquidity().ToString()

	amount0, amount1 = pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		positionAddr,
		-2000,
		-1000,
		test_liquidityExpectStr,
		adminAddr,
	)

	liqAfter = thisPool.Liquidity().ToString()
	println("[EXPECTED] liquidity:", liqAfter, "expected: ", liqBefore)
	println("[EXPECTED] amount0:", amount0, "expected: 0")
	println("[EXPECTED] amount1:", amount1, "expected: 0")
	println()

	println("[SCENARIO] 4. cannot remove more than the entire position")
	testing.SetRealm(posRealm)
	expectedPanic := `[GNOSWAP-POOL-009] invalid liquidity calculated || Condition failed: (z must be < x) (x: 0, y: -1001, z:115792089237316195423570985008687907853269984665640564039457584007913129638935)`
	uassert.AbortsWithMessage(
		t,
		expectedPanic,
		func() {
			pool.Burn(
				cross,
				barPath,
				fooPath,
				fee500,
				test_tickLower,
				test_tickUpper,
				"1001",
				adminAddr,
			)
		},
	)
	println("[EXPECTED] panic: ", expectedPanic)
	println()
	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] Mint Miscellaneous
// [INFO] Starting scenario: Mint miscellaneous
// [SCENARIO] 1. returns 0 before initialization
// [EXPECTED] liquidity: 0 expected: 0
//
// [SCENARIO] 2. mint to right of the current price
// [EXPECTED] liquidity: 0 expected:  0
// [EXPECTED] amount0: 47 expected: 0
// [EXPECTED] amount1: 0 expected: 0
//
// [SCENARIO] 3. mint to left of the current price
// [EXPECTED] liquidity: 0 expected:  0
// [EXPECTED] amount0: 0 expected: 0
// [EXPECTED] amount1: 47 expected: 0
//
// [SCENARIO] 4. cannot remove more than the entire position
// [EXPECTED] panic:  [GNOSWAP-POOL-009] invalid liquidity calculated || Condition failed: (z must be < x) (x: 0, y: -1001, z:115792089237316195423570985008687907853269984665640564039457584007913129638935)
//
// [INFO] Scenario completed
