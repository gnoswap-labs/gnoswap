// Verifies ExactOut router fee edge cases:
// 1. Very small amount (rounding boundary: fee truncates to 0)
// 2. Large amount (near pool liquidity limit)

package main

import (
	"testing"
	"time"

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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] ExactOut Router Fee Edge Cases")
	println()

	println("[SCENARIO] 1. Initialize pool")
	setup()
	println()

	println("[SCENARIO] 2. ExactOut very small amount (1 token)")
	exactOutSmallAmount()
	println()

	println("[SCENARIO] 3. ExactOut large amount (9,000,000,000,000 tokens)")
	exactOutLargeAmount()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)

	// Create pool at 1:1 with very deep liquidity for large amount tests
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950336")
	pn.Mint(cross, barPath, bazPath, 3000, min_tick, max_tick, "50000000000000", "50000000000000", "0", "0", max_timeout, "")

	println("[INFO] created bar:baz:3000 pool with 50T liquidity")
}

func exactOutSmallAmount() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)

	userBarBefore := bar.BalanceOf(adminAddr)
	feeBarBefore := bar.BalanceOf(protocolFeeAddr)

	// Request exactly 1 token output
	// At 0.15%: grossUp = 1 * 10000 / 9985 = 1.0015 → truncated to 1
	// fee = 1 * 15 / 10000 = 0 → user gets 1, no fee
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		bazPath,
		barPath,
		"1", // 1 token
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userBarAfter := bar.BalanceOf(adminAddr)
	feeBarAfter := bar.BalanceOf(protocolFeeAddr)

	userBarChange := userBarAfter - userBarBefore
	protocolFee := feeBarAfter - feeBarBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user bar received: %d\n", userBarChange)
	ufmt.Printf("[INFO] protocol fee (bar): %d\n", protocolFee)

	// With amount=1 and 0.15% fee, gross-up and fee both truncate:
	// poolAmount = 1 * 10000 / 9985 = 1 (truncated), fee = 1 * 15 / 10000 = 0
	// So user receives 1 token, zero fee
	ufmt.Printf("[EXPECTED] user receives exactly 1 bar: %d\n", userBarChange)
	ufmt.Printf("[EXPECTED] protocol fee is 0 (truncated): %d\n", protocolFee)
}

func exactOutLargeAmount() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)

	userBarBefore := bar.BalanceOf(adminAddr)
	feeBarBefore := bar.BalanceOf(protocolFeeAddr)
	poolBarBefore := bar.BalanceOf(poolAddr)

	// Request 9T tokens
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		bazPath,
		barPath,
		"9000000000000", // 9,000,000,000,000 tokens
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userBarAfter := bar.BalanceOf(adminAddr)
	feeBarAfter := bar.BalanceOf(protocolFeeAddr)
	poolBarAfter := bar.BalanceOf(poolAddr)

	userBarChange := userBarAfter - userBarBefore
	poolBarChange := poolBarBefore - poolBarAfter
	protocolFee := feeBarAfter - feeBarBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user bar received: %d\n", userBarChange)
	ufmt.Printf("[INFO] pool bar output: %d\n", poolBarChange)
	ufmt.Printf("[INFO] protocol fee (bar): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 9,000,000,000,000 bar: %d\n", userBarChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolBarChange, userBarChange)
}

// Output:
// [SCENARIO] ExactOut Router Fee Edge Cases
//
// [SCENARIO] 1. Initialize pool
// [INFO] created bar:baz:3000 pool with 50T liquidity
//
// [SCENARIO] 2. ExactOut very small amount (1 token)
// [INFO] amountIn: 3, amountOut: -1
// [INFO] user bar received: 1
// [INFO] protocol fee (bar): 0
// [EXPECTED] user receives exactly 1 bar: 1
// [EXPECTED] protocol fee is 0 (truncated): 0
//
// [SCENARIO] 3. ExactOut large amount (9,000,000,000,000 tokens)
// [INFO] amountIn: 11028810316105, amountOut: -9000000000000
// [INFO] user bar received: 9000000000000
// [INFO] pool bar output: 9013520280420
// [INFO] protocol fee (bar): 13520280420
// [EXPECTED] user receives exactly 9,000,000,000,000 bar: 9000000000000
// [EXPECTED] protocol fee = pool output - user received: 13520280420 = 9013520280420 - 9000000000000
