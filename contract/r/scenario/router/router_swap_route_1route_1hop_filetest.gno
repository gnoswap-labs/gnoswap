package main

import (
	"testing"
	"time"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"

	"gno.land/r/gnoswap/gns"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	routerAddr, _ = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

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
	atomatone500 = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500"
	atoneatom500 = "gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:500"
)

func main() {
	println("[SCENARIO] #4 Basic Router Swap Test")
	println("[INFO] Starting scenario: Basic 1route 1hop swap tests")

	println("[INFO] Setting up pool and position")
	testing.SetRealm(adminRealm)

	println("[INFO] Approving pool creation fee")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	println("[INFO] Creating atom-atone pool (fee: 500)")
	pl.CreatePool(cross, atomPath, atonePath, fee500, "130621891405341611593710811006") // tick =  10_000, ratio = 2.71814592682522526700950038502924144268035888671875

	println("[INFO] Approving tokens for pool operations")
	atom.Approve(cross, poolAddr, 36790)
	atone.Approve(cross, poolAddr, 100000)

	// Mint
	println("[INFO] Minting position in atom-atone pool")
	positionId, liquidity, amount0, amount1 := pn.Mint(cross, atomPath, atonePath, fee500, int32(9000), int32(11000), "100000", "100000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] positionId:", positionId)
	println("[INFO] amount0:", amount0)
	println("[INFO] amount1:", amount1)
	println("[INFO] liquidity:", liquidity)

	println("[EXPECTED] positionId:", positionId, "expected: 1")
	println("[EXPECTED] amount0:", amount0, "expected: 36790")
	println("[EXPECTED] amount1:", amount1, "expected: 100000")

	println("[INFO] Executing dry swap to check expected output")
	_, dryResult, _ := router.DrySwapRoute(
		atomPath,
		atonePath,
		"1000",
		"EXACT_IN",
		atomatone500,
		"100",
		"1",
	)

	println("[EXPECTED] dry swap result:", dryResult, "expected: 2711")

	println("[INFO] Test 1: ExactIn swap (atom → atone)")
	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, int64(1000))
	atone.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut := router.ExactInSwapRoute(
		cross,
		atomPath,
		atonePath,
		"1000",
		atomatone500,
		"100",
		"2700",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -2707")

	println("[INFO] Test 2: ExactOut swap (atom → atone)")
	println("[INFO] Approving tokens for swap")
	atom.Approve(cross, routerAddr, int64(1000))
	atone.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut = router.ExactOutSwapRoute(
		cross,
		atomPath,
		atonePath,
		"1000",
		atomatone500,
		"100",
		"371",
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 371")
	println("[EXPECTED] amountOut:", amountOut, "expected: -999")

	println("[INFO] Test 3: ExactIn swap (atone → atom)")
	println("[INFO] Approving tokens for swap")
	atone.Approve(cross, routerAddr, max_approve)
	atom.Approve(cross, routerAddr, max_approve) // ITS FOR 0.15% fee

	amountIn, amountOut = router.ExactInSwapRoute(
		cross,
		atonePath,
		atomPath,
		"1000",
		atoneatom500,
		"100",
		"360",
		time.Now().Add(time.Hour).Unix(),
		"", // referrer
	)

	println("[EXPECTED] amountIn:", amountIn, "expected: 1000")
	println("[EXPECTED] amountOut:", amountOut, "expected: -368")

	println("[INFO] Test 4: ExactOut swap (atone → atom)")
	println("[INFO] Approving tokens for swap")
	atone.Approve(cross, routerAddr, max_approve)
	atom.Approve(cross, routerAddr, max_approve)

	amountIn, amountOut = router.ExactOutSwapRoute(
		cross,
		atonePath,
		atomPath,
		"3000",
		atoneatom500,
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
// [INFO] Creating atom-atone pool (fee: 500)
// [INFO] Approving tokens for pool operations
// [INFO] Minting position in atom-atone pool
// [INFO] positionId: 1
// [INFO] amount0: 36790
// [INFO] amount1: 100000
// [INFO] liquidity: 1243732
// [EXPECTED] positionId: 1 expected: 1
// [EXPECTED] amount0: 36790 expected: 36790
// [EXPECTED] amount1: 100000 expected: 100000
// [INFO] Executing dry swap to check expected output
// [EXPECTED] dry swap result: 2707 expected: 2711
// [INFO] Test 1: ExactIn swap (atom → atone)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -2707 expected: -2707
// [INFO] Test 2: ExactOut swap (atom → atone)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 371 expected: 371
// [EXPECTED] amountOut: -1000 expected: -999
// [INFO] Test 3: ExactIn swap (atone → atom)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 1000 expected: 1000
// [EXPECTED] amountOut: -368 expected: -368
// [INFO] Test 4: ExactOut swap (atone → atom)
// [INFO] Approving tokens for swap
// [EXPECTED] amountIn: 8182 expected: 8171
// [EXPECTED] amountOut: -3000 expected: -2996
// [INFO] Scenario completed
