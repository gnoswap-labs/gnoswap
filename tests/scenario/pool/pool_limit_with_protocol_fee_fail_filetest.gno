package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	prbac "gno.land/p/gnoswap/rbac"
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

	MAX_UINT128 string = "340282366920938463463374607431768211455"
)

// Variables for test addresses and realms
var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = std.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = std.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = std.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
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
	pool.SetFeeProtocolByAdmin(cross, 4, 4)
}

func main() {
	println("[SCENARIO] Limit Order Thru Negative 1 With Fee")
	println("[INFO] Starting scenario: Limit order thru negative 1 with fee")

	println("[INFO] Setting up pool with specific tick")

	println("[INFO] Approving pool creation fee")
	println()
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-1).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee500)

	println("[SCENARIO] 1. Minting position spanning current tick")
	testing.SetRealm(posRealm)
	mint0, mint1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		positionAddr,
		-120,
		0,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[EXPECTED] mint0:", mint0, "expected: 499988")
	println("[EXPECTED] mint1:", mint1, "expected: 59317416")
	println()

	println("[SCENARIO] 2. Swapping 0 -> 1")
	testing.SetRealm(rouRealm)
	swap0, swap1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"60283363",
		MIN_PRICE,
		adminAddr,
	)
	println("[EXPECTED] swap0:", swap0, "expected: 59707210")
	println("[EXPECTED] swap1:", swap1, "expected: -59317415")
	println()

	println("[SCENARIO] 3. Burning position")
	testing.SetRealm(posRealm)
	burn0, burn1 := pool.Burn(
		cross,
		barPath,
		fooPath,
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
		barPath,
		fooPath,
		fee500,
		adminAddr,
		-120,
		0,
		MAX_UINT128,
		MAX_UINT128,
	)
	println("[EXPECTED] collect0:", collect0, "expected: 60177342")
	println("[EXPECTED] collect1:", collect1, "expected: 0")
	println()

	slotTick := thisPool.Slot0Tick()
	println("[EXPECTED] Pool tick:", slotTick, "expected: < -120")
	uassert.True(t, slotTick < -120, ufmt.Sprintf("tick(%d) should be < -120", slotTick))
	println()
	println("[INFO] Scenario completed")
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
// [EXPECTED] collect0: 60177342 expected: 60177342
// [EXPECTED] collect1: 0 expected: 0
//
// [EXPECTED] Pool tick: -887272 expected: < -120
//
// [INFO] Scenario completed
