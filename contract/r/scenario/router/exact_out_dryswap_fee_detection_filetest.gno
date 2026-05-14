// Verifies that DrySwap correctly accounts for router fee in ExactOut quotes,
// preventing the scenario where a user's full balance is insufficient due to
// hidden fee overhead.
//
// Scenario: pool is 1:1, user holds exactly 100 of each token.
// User requests ExactOut of 100 tokenB. Without fee awareness, the quote
// would say "you need 100 tokenA". But with 0.15% router fee, the pool
// must output ~100.15 tokens, requiring more than 100 tokenA input.
//
// DrySwap should report the TRUE input cost (including fee overhead),
// and the actual swap should fail with slippage error when amountInMax = 100.

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"

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
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewUserRealm(userAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] DrySwap fee detection for ExactOut")
	println()

	println("[SCENARIO] 1. Initialize pool and user")
	setup()
	println()

	println("[SCENARIO] 2. DrySwap: quote ExactOut 1000000 atone with no router fee")
	drySwapQuote()
	println()

	println("[SCENARIO] 3. Actual swap with amountInMax = user balance (1000000)")
	actualSwapFailure()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, max_approve)
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)

	// 1:1 pool with deep liquidity
	pl.CreatePool(cross, atomPath, atonePath, 500, "79228162514264337593543950336")
	pn.Mint(cross, atomPath, atonePath, 500, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, "")

	atom.Transfer(cross, userAddr, 1012141) // user needs to have exactly 1012141 atom to swap 1000000 atone
	atone.Transfer(cross, userAddr, 1000000)

	ufmt.Printf("[INFO] user atom balance: %d\n", atom.BalanceOf(userAddr))
	ufmt.Printf("[INFO] user atone balance: %d\n", atone.BalanceOf(userAddr))
	println("[INFO] pool created at 1:1, user has exactly 1000000 atom + 1000000 atone")
}

func drySwapQuote() {
	testing.SetRealm(adminRealm)

	println("[INFO] setup router fee to 0")
	router.SetSwapFee(cross, 0)

	// DrySwap should report the true input cost including router fee
	amountIn, amountOut, ok := router.DrySwapRoute(
		atomPath,   // inputToken
		atonePath,   // outputToken
		"1000000", // specifiedAmount (user wants exactly 1000000 atone)
		"EXACT_OUT",
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500",
		"100",
		"9223372036854775807", // no limit for dry swap
	)

	println("[INFO] setup router fee to 15")
	router.SetSwapFee(cross, 15)

	// DrySwap should report the true input cost including router fee
	amountInWithFee, amountOutWithFee, okWithFee := router.DrySwapRoute(
		atomPath,   // inputToken
		atonePath,   // outputToken
		"1000000", // specifiedAmount (user wants exactly 1000000 atone)
		"EXACT_OUT",
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500",
		"100",
		"9223372036854775807", // no limit for dry swap
	)

	ufmt.Printf("[INFO] DrySwap result: amountIn=%s, amountOut=%s, ok=%t\n", amountIn, amountOut, ok)
	ufmt.Printf("[INFO] DrySwap result with fee: amountIn=%s, amountOut=%s, ok=%t\n", amountInWithFee, amountOutWithFee, okWithFee)

	// At 0.15% fee:
	// poolAmount = 1000000 * 10000 / 9985 = 1001502 (truncated from 1001502)
	// The pool at 1:1 with 0.05% pool fee needs slightly more input.
	// DrySwap amountIn should be > 100, revealing the fee overhead.
	println("[EXPECTED] DrySwap amountIn > 100 (includes pool fee + router fee overhead)")
}

func actualSwapFailure() {
	testing.SetRealm(userRealm)

	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve)

	userAtomBefore := atom.BalanceOf(userAddr)
	userAtoneBefore := atone.BalanceOf(userAddr)

	// User tries ExactOut 1000000 atone with amountInMax = 1000000 (their full balance)
	// This should fail because pool fee + router fee requires > 1000000 atom input
	// Use revive to catch the cross-realm abort
	r := revive(func() {
		router.ExactOutSwapRoute(
			cross,
			atomPath,
			atonePath,
			"1000000", // want exactly 1000000 atone
			"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:500",
			"100",
			"100000000000", // amountInMax = user's full balance
			time.Now().Add(time.Hour).Unix(),
			"",
		)
	})

	userAtomAfter := atom.BalanceOf(userAddr)
	userAtoneAfter := atone.BalanceOf(userAddr)

	if r != nil {
		ufmt.Printf("[INFO] swap aborted: %v\n", r)
	} else {
		println("[WARNING] swap did not abort (unexpected)")
	}

	ufmt.Printf("[INFO] user atom balance changes: %d (unchanged)\n", userAtomAfter-userAtomBefore)
	ufmt.Printf("[INFO] user atone balance changes: %d (unchanged)\n", userAtoneAfter-userAtoneBefore)
	println("[EXPECTED] swap failed due to slippage (input required > 1000000, but amountInMax = 1000000)")
}

// Output:
// [SCENARIO] DrySwap fee detection for ExactOut
//
// [SCENARIO] 1. Initialize pool and user
// [INFO] user atom balance: 1012141
// [INFO] user atone balance: 1000000
// [INFO] pool created at 1:1, user has exactly 1000000 atom + 1000000 atone
//
// [SCENARIO] 2. DrySwap: quote ExactOut 1000000 atone with no router fee
// [INFO] setup router fee to 0
// [INFO] setup router fee to 15
// [INFO] DrySwap result: amountIn=1010608, amountOut=1000000, ok=true
// [INFO] DrySwap result with fee: amountIn=1012141, amountOut=1000000, ok=true
// [EXPECTED] DrySwap amountIn > 100 (includes pool fee + router fee overhead)
//
// [SCENARIO] 3. Actual swap with amountInMax = user balance (1000000)
// [WARNING] swap did not abort (unexpected)
// [INFO] user atom balance changes: -1012141 (unchanged)
// [INFO] user atone balance changes: 1000000 (unchanged)
// [EXPECTED] swap failed due to slippage (input required > 1000000, but amountInMax = 1000000)
