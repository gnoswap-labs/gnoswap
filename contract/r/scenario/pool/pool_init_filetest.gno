// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"strconv"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
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
	test_liquidityExpectStr = "1000"

	fee500 = uint32(500)

	minPrice = "4295128740"                                        // MIN_SQRT_RATIO + 1
	maxPrice = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

func main() {
	println("[SCENARIO] #1 Pool Initialization Test")
	println("[INFO] Starting scenario: Pool initialization and liquidity management tests")

	println("[INFO] Setting up pool and initial position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, poolCreationFee)
	println("[INFO] Creating bar-foo pool (fee: 500, tick: -1)")
	pool.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(-1).ToString())

	println("[INFO] Approving tokens for pool operations")
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	thisPool := pool.GetPool(barPath, fooPath, fee500)

	println("[INFO] Test 1: Minting position in range")
	// 1. returns in supply in range
	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-1000,
		1000,
		test_liquidityExpectStr,
		adminAddr,
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	currentLiq := thisPool.Liquidity().ToString()
	println("[INFO] Current liquidity:", currentLiq)
	println()

	println("[INFO] Test 2: Minting position above current tick")
	// 2. excludes supply at tick above current tick
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-2000,
		-1000,
		test_liquidityExpectStr,
		adminAddr,
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	nowLiq := thisPool.Liquidity().ToString()
	println("[INFO] Current liquidity:", currentLiq)
	println("[INFO] Now liquidity:", nowLiq)
	println("[EXPECTED] Current liquidity should be equal to now liquidity")
	println("[EXPECTED] Liquidity comparison:", currentLiq, "==", nowLiq)
	println()

	println("[INFO] Test 3: Minting position below current tick")
	// 3. excludes supply at tick below current tick
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		1000,
		2000,
		test_liquidityExpectStr,
		adminAddr,
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	nowLiq = thisPool.Liquidity().ToString()
	println("[INFO] Current liquidity:", currentLiq)
	println("[INFO] Now liquidity:", nowLiq)
	println("[EXPECTED] Current liquidity should be equal to now liquidity")
	println("[EXPECTED] Liquidity comparison:", currentLiq, "==", nowLiq)
	println()

	println("[INFO] Test 4: Updating liquidity when exiting range")
	// 4. updates correctly when exiting range
	beforeLiq := thisPool.Liquidity().ToString()
	println("[INFO] Before liquidity:", beforeLiq)

	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		0,
		10,
		test_liquidityExpectStr,
		adminAddr,
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	nowLiq = thisPool.Liquidity().ToString()
	println("[INFO] Now liquidity:", nowLiq)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	println("[INFO] Executing swap to move tick")
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1",
		minPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	poolTick := thisPool.Slot0Tick()
	println("[EXPECTED] Pool tick:", poolTick, "expected: -1")
	println()

	println("[INFO] Test 5: Updating liquidity when entering range")
	// 5. updates correctly when entering range
	beforeLiq = thisPool.Liquidity().ToString()
	println("[INFO] Before liquidity:", beforeLiq)

	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-10,
		0,
		test_liquidityExpectStr,
		adminAddr,
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	nowLiq = thisPool.Liquidity().ToString()
	println("[INFO] Now liquidity:", nowLiq)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/v1/router"))
	println("[INFO] Executing swap to move tick")
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"1",
		minPrice,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta string) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	thisPool = pool.GetPool(barPath, fooPath, fee500)
	poolTick = thisPool.Slot0Tick()
	println("[EXPECTED] Pool tick:", poolTick, "expected: -1")
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
// [SCENARIO] #1 Pool Initialization Test
// [INFO] Starting scenario: Pool initialization and liquidity management tests
// [INFO] Setting up pool and initial position
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 500, tick: -1)
// [INFO] Approving tokens for pool operations
// [INFO] Test 1: Minting position in range
// [INFO] Current liquidity: 1000
//
// [INFO] Test 2: Minting position above current tick
// [INFO] Current liquidity: 1000
// [INFO] Now liquidity: 1000
// [EXPECTED] Current liquidity should be equal to now liquidity
// [EXPECTED] Liquidity comparison: 1000 == 1000
//
// [INFO] Test 3: Minting position below current tick
// [INFO] Current liquidity: 1000
// [INFO] Now liquidity: 1000
// [EXPECTED] Current liquidity should be equal to now liquidity
// [EXPECTED] Liquidity comparison: 1000 == 1000
//
// [INFO] Test 4: Updating liquidity when exiting range
// [INFO] Before liquidity: 1000
// [INFO] Now liquidity: 1000
// [INFO] Executing swap to move tick
// [EXPECTED] Pool tick: -1 expected: -1
//
// [INFO] Test 5: Updating liquidity when entering range
// [INFO] Before liquidity: 1000
// [INFO] Now liquidity: 2000
// [INFO] Executing swap to move tick
// [EXPECTED] Pool tick: -1 expected: -1
//
// [INFO] Scenario completed
