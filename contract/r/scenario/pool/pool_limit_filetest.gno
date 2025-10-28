// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"

	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806

	MAX_UINT128 string = "340282366920938463463374607431768211455"
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
		0,
		120,
		test_liquidityExpectStr,
		adminAddr,
	)
	println("[INFO] Mint 0:", mint0)
	println("[INFO] Mint 1:", mint1)
	println()

	println("[SCENARIO] 2. Mint Position (Limit selling 0 for 1 at tick 0 thru 120)")

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
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
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
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
		MAX_UINT128,
		MAX_UINT128,
	)
	println("[INFO] Collect 0:", collect0)
	println("[INFO] Collect 1:", collect1)
	println()

	println("[SCENARIO] 5. Verify Final State (Check slot tick >= 120)")

	thisPool = pool.GetPool(barPath, fooPath, fee100)
	slotTick := thisPool.Slot0Tick()
	println("[INFO] slot tick should be >= 120")
	println("[INFO] Slot tick:", slotTick)
	if slotTick < 120 {
		panic(ufmt.Sprintf("tick(%d) should be >= 120", slotTick))
	}
	println()
	println("[INFO] Scenario completed")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	amount0Int64, _ := strconv.ParseInt(amount0Delta, 10, 64)
	amount1Int64, _ := strconv.ParseInt(amount1Delta, 10, 64)

	if amount0Int64 > 0 {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Int64)
	}
	if amount1Int64 > 0 {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Int64}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Int64)
	}

	return nil
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
