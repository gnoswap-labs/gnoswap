package main

import (
	"std"
	"testing"
	"time"

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

const (
	barbaz500 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"
	bazbar500 = "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500"
)

func main() {
	println("[SCENARIO] #4 Basic Router Swap Test")
	println("[INFO] Starting scenario: Basic 1route 1hop swap tests")

	println("[INFO] Setting up pool and position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	println("[INFO] Creating bar-baz pool (fee: 500)")
	pl.CreatePool(cross, barPath, bazPath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Approving tokens for pool operations")
	bar.Approve(cross, poolAddr, 36790)
	baz.Approve(cross, poolAddr, 100000)

	// Mint
	println("[INFO] Minting position in bar-baz pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, barPath, bazPath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")

	println("[INFO] Executing dry swap to check expected output")
	_, dryResult, _ := router.DrySwapRoute(
		barPath,
		bazPath,
		"1000",
		"EXACT_IN",
		barbaz500,
		"100",
		"1",
	)

	println("[EXPECTED] dry swap result:", dryResult, "expected: 2711")

	println("[INFO] Test 1: ExactIn swap (bar → baz)")
	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, poolAddr, int64(1000))
	baz.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		barPath,
		bazPath,
		"1000",
		barbaz500,
		"100",
		"2700",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -2707")

	println("[INFO] Test 2: ExactOut swap (bar → baz)")
	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, poolAddr, int64(1000))
	baz.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut = router.ExactOutSwapRoute(
		cross,
		barPath,
		bazPath,
		"1000",
		barbaz500,
		"100",
		"371",
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 371")
	println("[EXPECTED] amountOut:", amountOut, "expected: -999")

	println("[INFO] Test 3: ExactIn swap (baz → bar)")
	println("[INFO] Approving tokens for swap")
	baz.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut = router.ExactInSwapRoute(
		cross,
		bazPath,
		barPath,
		"1000",
		bazbar500,
		"100",
		"360",
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -368")

	println("[INFO] Test 4: ExactOut swap (baz → bar)")
	println("[INFO] Approving tokens for swap")
	bar.Approve(cross, routerAddr, max_approve)

	amountIn, amountOut = router.ExactOutSwapRoute(
		cross,
		bazPath,
		barPath,
		"3000",
		bazbar500,
		"100",
		"8200",
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 8171")
	println("[EXPECTED] amountOut:", amountOut, "expected: -2996")

	println("[INFO] Scenario completed")
}

// Output:
// [SCENARIO] #4 Basic Router Swap Test
// [INFO] Starting scenario: Basic 1route 1hop swap tests
// [INFO] Setting up pool and position
// [INFO] Approving pool creation fee
// [INFO] Creating bar-baz pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in bar-baz pool
// [INFO] positionId: 1
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
// [INFO] Executing dry swap to check expected output
// [EXPECTED] dry swap result: 2711 expected: 2711
// [INFO] Test 1: ExactIn swap (bar → baz)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -2707 expected: -2707
// [INFO] Test 2: ExactOut swap (bar → baz)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 371 expected: 371
// [EXPECTED] amountOut: -999 expected: -999
// [INFO] Test 3: ExactIn swap (baz → bar)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -368 expected: -368
// [INFO] Test 4: ExactOut swap (baz → bar)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 8171 expected: 8171
// [EXPECTED] amountOut: -2996 expected: -2996
// [INFO] Scenario completed
