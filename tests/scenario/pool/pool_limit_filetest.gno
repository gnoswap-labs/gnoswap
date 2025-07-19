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

// Variables for test addresses and realms
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

	minPrice = "4295128740"                                        // MIN_SQRT_RATIO + 1
	maxPrice = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

func main() {
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, poolCreationFee)
	pool.CreatePool(cross, barPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee100)

	println("[SCENARIO] 1. Initialize Pool (Create pool with bar/foo tokens, fee 100)")
	testing.SetRealm(posRealm)
	mint0, mint1 := pool.Mint(
		cross,
		barPath,
		fooPath,
		fee100,
		positionAddr,
		0,
		120,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[INFO] Mint 0:", mint0)
	println("[INFO] Mint 1:", mint1)
	println()

	println("[SCENARIO] 2. Mint Position (Limit selling 0 for 1 at tick 0 thru 120)")
	testing.SetRealm(rouRealm)
	swap0, swap1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		false,
		"60183363",
		maxPrice,
		adminAddr,
	)

	println("[INFO] Swap 1 -> 0")
	println("[INFO] Swap 0:", swap0)
	println("[INFO] Swap 1:", swap1)
	println()

	// BURN
	println("[SCENARIO] 3. Burn Position (Burn liquidity from tick 0 to 120)")
	testing.SetRealm(posRealm)
	burn0, burn1 := pool.Burn(
		cross,
		barPath,
		fooPath,
		fee100,
		0,
		120,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[INFO] Burn 0:", burn0)
	println("[INFO] Burn 1:", burn1)
	println()

	// COLLECT
	println("[SCENARIO] 4. Collect Fees (Collect all fees from position)")
	collect0, collect1 := pool.Collect(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		0,
		120,
		consts.MAX_UINT128,
		consts.MAX_UINT128,
	)
	println("[INFO] Collect 0:", collect0)
	println("[INFO] Collect 1:", collect1)
	println()

	println("[SCENARIO] 5. Verify Final State (Check slot tick >= 120)")
	slotTick := thisPool.Slot0Tick()
	println("[INFO] slot tick should be >= 120")
	println("[INFO] Slot tick:", slotTick)
	if slotTick < 120 {
		panic(ufmt.Sprintf("tick(%d) should be >= 120", slotTick))
	}
	println()
	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] 1. Initialize Pool (Create pool with bar/foo tokens, fee 100)
// [INFO] Mint 0: 59817378
// [INFO] Mint 1: 0
//
// [SCENARIO] 2. Mint Position (Limit selling 0 for 1 at tick 0 thru 120)
// [INFO] Swap 1 -> 0
// [INFO] Swap 0: -59817377
// [INFO] Swap 1: 60183363
//
// [SCENARIO] 3. Burn Position (Burn liquidity from tick 0 to 120)
// [INFO] Burn 0: 0
// [INFO] Burn 1: 60177342
//
// [SCENARIO] 4. Collect Fees (Collect all fees from position)
// [INFO] Collect 0: 0
// [INFO] Collect 1: 60183360
//
// [SCENARIO] 5. Verify Final State (Check slot tick >= 120)
// [INFO] slot tick should be >= 120
// [INFO] Slot tick: 120
//
// [INFO] Scenario completed
