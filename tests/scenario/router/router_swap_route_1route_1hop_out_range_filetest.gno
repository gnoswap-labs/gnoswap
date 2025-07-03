package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/router"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	"gno.land/r/gnoswap/v1/gns"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	routerAddr, _ = access.GetAddress(access.ROLE_ROUTER)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

var (
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	tier1 uint64 = 1
)

var t *testing.T

func main() {
	println("[SCENARIO] #3 Out of Range Swap Test")
	println("[INFO] Starting scenario: Out of range swap with slippage check failure")

	println("[INFO] Setting up pool and position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	println("[INFO] Creating bar-baz pool (fee: 500, tick: 10000)")
	pl.CreatePool(cross, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(10000).ToString())

	println("[INFO] Checking pool creation")
	jsonStr := pl.ApiGetPools()
	root, err := json.Unmarshal([]byte(jsonStr))
	if err != nil {
		panic(err.Error())
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err.Error())
	}

	println("[EXPECTED] Number of pools:", response.Size(), "expected: 1")

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)

	// Mint
	println("[INFO] Minting position in bar-baz pool (tick range: 8000-12000)")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, barPath, bazPath, fee500, int32(8000), int32(12000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] liquidity:", liquidity, "expected: 637408")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")

	// check pool liquidity
	poolLiquidity := pl.PoolGetLiquidity("gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500")
	println("[EXPECTED] pool liquidity:", poolLiquidity, "expected: 637408")

	println("[INFO] Executing dry swap to check expected output")
	_, dryResult, _ := router.DrySwapRoute(
		bazPath,    // inputToken
		barPath,    // outputToken
		"1000",     // amountSpecified
		"EXACT_IN", // swapType
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
		"100", // quoteArr
		"1",   // tokenAmountLimit
	)

	println("[EXPECTED] dry swap result:", dryResult, "expected: 367")

	println("[INFO] Attempting ExactIn swap with high slippage tolerance")
	println("[INFO] Expected to fail due to slippage check")
	println("[EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-002] slippage check failed || ExactIn: too few received (min:2710, got:367)")

	uassert.AbortsWithMessage(
		t,
		`[GNOSWAP-ROUTER-002] slippage check failed || ExactIn: too few received (min:2710, got:367)`,
		func() {
			router.ExactInSwapRoute(
				cross,
				bazPath, // inputToken
				barPath, // outputToken
				"1000",  // amountSpecified
				"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", // strRouteArr
				"100",  // quoteArr
				"2710", // tokenAmountLimit ( too few recieved (expected 2710, got 300))
				time.Now().Add(time.Hour).Unix(),
				"", // referrer
			)
		},
	)

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #3 Out of Range Swap Test
// [INFO] Starting scenario: Out of range swap with slippage check failure
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 500, tick: 10000)
// [INFO] Checking pool creation
// [EXPECTED] Number of pools: 1 expected: 1
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool (tick range: 8000-12000)
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] liquidity: 637408 expected: 637408
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
// [EXPECTED] pool liquidity: 637408 expected: 637408
// [INFO] Executing dry swap to check expected output
// [EXPECTED] dry swap result: 367 expected: 367
// [INFO] Attempting ExactIn swap with high slippage tolerance
// [INFO] Expected to fail due to slippage check
// [EXPECTED] Swap should fail with error: [GNOSWAP-ROUTER-002] slippage check failed || ExactIn: too few received (min:2710, got:367)
// [INFO] Scenario completed
