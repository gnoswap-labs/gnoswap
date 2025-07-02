package main

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/gns"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm     = std.NewCodeRealm(consts.ROUTER_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR

	poolCreationFee int64 = 100_000_000
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

var (
	test_tickLower          = int32(-6000)
	test_tickUpper          = int32(6000)
	test_liquidityExpectStr = "10000000000"

	fee100 = uint32(100)
	fee500 = uint32(500)

	minPrice = "4295128740"
	maxPrice = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var t *testing.T

func main() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee500)

	println("[SCENARIO] 1. Mint Position (Limit selling 0 for 1 at tick 0 thru 1)")
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

	println("[EXPECTED] Mint 0:", mint0, "expected: 0")
	println("[EXPECTED] Mint 1:", mint1, "expected: 59817378")
	println()

	// SWAP 0 -> 1
	println("[INFO] Swap 0 -> 1")
	testing.SetRealm(rouRealm)
	swap0, swap1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"60283363",
		consts.MIN_PRICE,
		adminAddr,
	)

	println("[EXPECTED] Swap 0:", swap0, "expected: 60207447")
	println("[EXPECTED] Swap 1:", swap1, "expected: -59817377")
	println()

	println("[INFO] Burn Position (Burn liquidity from tick 0 to 120)")
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

	println("[EXPECTED] Burn 0:", burn0, "expected: 60177342")
	println("[EXPECTED] Burn 1:", burn1, "expected: 0")
	println()

	println("[INFO] Collect Fees (Collect all fees from position)")
	testing.SetRealm(posRealm)
	collect0, collect1 := pool.Collect(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		-120,
		0,
		consts.MAX_UINT128,
		consts.MAX_UINT128,
	)

	println("[EXPECTED] Collect 0:", collect0, "expected: 60207445")
	println("[EXPECTED] Collect 1:", collect1, "expected: 0")
	println()

	slotTick := thisPool.Slot0Tick()
	println("[EXPECTED] slot tick should be < -120")
	if slotTick >= -120 {
		panic(ufmt.Sprintf("tick(%d) should be < -120", slotTick))
	}
	println()
	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] 1. Mint Position (Limit selling 0 for 1 at tick 0 thru 1)
// [EXPECTED] Mint 0: 0 expected: 0
// [EXPECTED] Mint 1: 59817378 expected: 59817378
//
// [INFO] Swap 0 -> 1
// [EXPECTED] Swap 0: 60207447 expected: 60207447
// [EXPECTED] Swap 1: -59817377 expected: -59817377
//
// [INFO] Burn Position (Burn liquidity from tick 0 to 120)
// [EXPECTED] Burn 0: 60177342 expected: 60177342
// [EXPECTED] Burn 1: 0 expected: 0
//
// [INFO] Collect Fees (Collect all fees from position)
// [EXPECTED] Collect 0: 60207445 expected: 60207445
// [EXPECTED] Collect 1: 0 expected: 0
//
// [EXPECTED] slot tick should be < -120
//
// [INFO] Scenario completed
