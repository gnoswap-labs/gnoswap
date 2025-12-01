// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	plp "gno.land/p/gnoswap/gnsmath"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

// Constants for fee tiers
const (
	fee100 uint32 = 100
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
	liquidityExpect = "100000000000"
	poolCreationFee = int64(100_000_000)

	MIN_PRICE string = "4295128740"
)

func main() {
	println("[SCENARIO] Tick Transaction Test")
	println("[INFO] Starting scenario: Tick transaction and liquidity management tests")

	println("[INFO] Setting up pool with specific tick")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, poolCreationFee)

	println("[INFO] Creating bar-foo pool (fee: 100, tick: -24081)")
	testSqrt := common.TickMathGetSqrtRatioAtTick(-24081)
	testSqrt = testSqrt.Add(testSqrt, u256.One())
	pool.CreatePool(cross, barPath, fooPath, fee100, testSqrt.ToString())

	thisPool := pool.GetPool(barPath, fooPath, fee100)

	println("[EXPECTED] Initial pool liquidity:", thisPool.Liquidity().ToString(), "expected: 0")
	println("[EXPECTED] Initial pool tick:", thisPool.Slot0Tick(), "expected: -24081")

	println("[INFO] Setting up positions and liquidity")
	liqToMint := "10000000000" // 10_000_000_000
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	println("[SCENARIO] 1. Minting position spanning current tick")
	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee100,
		-24082,
		-24080,
		liqToMint,
		adminAddr,
	)
	thisPool = pool.GetPool(barPath, fooPath, fee100)
	println("[EXPECTED] Pool liquidity after first mint:", thisPool.Liquidity().ToString(), "expected: 10000000000")
	println()

	println("[SCENARIO] 2. Minting position ending at current tick")
	testing.SetRealm(posRealm)
	pool.Mint(
		cross,
		barPath,
		fooPath,
		fee100,
		-24082,
		-24081,
		liqToMint,
		adminAddr,
	)
	thisPool = pool.GetPool(barPath, fooPath, fee100)
	println("[EXPECTED] Pool liquidity after second mint:", thisPool.Liquidity().ToString(), "expected: 10000000000")
	println()

	println("[SCENARIO] 3. Computing swap step")
	testSqrtSubOne := new(u256.Uint).Sub(testSqrt, u256.One())
	{
		println("[INFO] Computing swap step with sqrt price change")
		sqrtQ, amountIn, amountOut, feeAmount := plp.SwapMathComputeSwapStep(
			testSqrt,
			testSqrtSubOne,
			u256.MustFromDecimal(liqToMint),
			i256.MustFromDecimal("100"),
			uint64(3000),
		)

		println("[EXPECTED] sqrtQ:", sqrtQ.ToString(), "expected:", testSqrtSubOne.ToString())
		println("[EXPECTED] amountIn:", amountIn.ToString(), "expected: 1")
		println("[EXPECTED] amountOut:", amountOut.ToString(), "expected: 0")
		println("[EXPECTED] feeAmount:", feeAmount.ToString(), "expected: 1")
	}
	println()

	println("[SCENARIO] 4. Executing swap to move tick")

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(
		cross,
		barPath,
		fooPath,
		fee100,
		adminAddr,
		true,
		"100",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta)
		},
	)

	testing.SetRealm(adminRealm)
	thisPool = pool.GetPool(barPath, fooPath, fee100)
	println("[EXPECTED] Pool tick after swap:", thisPool.Slot0Tick(), "expected: -24082")
	println("[EXPECTED] Pool sqrt price after swap:", thisPool.Slot0SqrtPriceX96().ToString(), "expected: 23768044726356341008264205109")
	println("[EXPECTED] Pool liquidity after swap:", thisPool.Liquidity().ToString(), "expected: 20000000000")
	println()
	println("[INFO] Scenario completed")
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if amount0Delta > 0 {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] Tick Transaction Test
// [INFO] Starting scenario: Tick transaction and liquidity management tests
// [INFO] Setting up pool with specific tick
// [INFO] Approving pool creation fee
// [INFO] Creating bar-foo pool (fee: 100, tick: -24081)
// [EXPECTED] Initial pool liquidity: 0 expected: 0
// [EXPECTED] Initial pool tick: -24081 expected: -24081
// [INFO] Setting up positions and liquidity
// [SCENARIO] 1. Minting position spanning current tick
// [EXPECTED] Pool liquidity after first mint: 10000000000 expected: 10000000000
//
// [SCENARIO] 2. Minting position ending at current tick
// [EXPECTED] Pool liquidity after second mint: 10000000000 expected: 10000000000
//
// [SCENARIO] 3. Computing swap step
// [INFO] Computing swap step with sqrt price change
// [EXPECTED] sqrtQ: 23768044760938258284793355980 expected: 23768044760938258284793355980
// [EXPECTED] amountIn: 1 expected: 1
// [EXPECTED] amountOut: 0 expected: 0
// [EXPECTED] feeAmount: 1 expected: 1
//
// [SCENARIO] 4. Executing swap to move tick
// [EXPECTED] Pool tick after swap: -24082 expected: -24082
// [EXPECTED] Pool sqrt price after swap: 23768044726356341008264205109 expected: 23768044726356341008264205109
// [EXPECTED] Pool liquidity after swap: 20000000000 expected: 20000000000
//
// [INFO] Scenario completed
