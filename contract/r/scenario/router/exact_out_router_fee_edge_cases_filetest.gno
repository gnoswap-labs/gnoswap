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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"

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
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)

	// Create pool at 1:1 with very deep liquidity for large amount tests
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950336")
	pn.Mint(cross, atomPath, atonePath, 3000, min_tick, max_tick, "50000000000000", "50000000000000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] created atom:atone:3000 pool with 50T liquidity")
}

func exactOutSmallAmount() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve)

	userAtomBefore := atom.BalanceOf(adminAddr)
	feeAtomBefore := atom.BalanceOf(protocolFeeAddr)

	// Request exactly 1 token output
	// At 0.15%: grossUp = 1 * 10000 / 9985 = 1.0015 → truncated to 1
	// fee = 1 * 15 / 10000 = 0 → user gets 1, no fee
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atonePath,
		atomPath,
		"1", // 1 token
		"gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userAtomAfter := atom.BalanceOf(adminAddr)
	feeAtomAfter := atom.BalanceOf(protocolFeeAddr)

	userAtomChange := userAtomAfter - userAtomBefore
	protocolFee := feeAtomAfter - feeAtomBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user atom received: %d\n", userAtomChange)
	ufmt.Printf("[INFO] protocol fee (atom): %d\n", protocolFee)

	// With amount=1 and 0.15% fee, gross-up and fee both truncate:
	// poolAmount = 1 * 10000 / 9985 = 1 (truncated), fee = 1 * 15 / 10000 = 0
	// So user receives 1 token, zero fee
	ufmt.Printf("[EXPECTED] user receives exactly 1 atom: %d\n", userAtomChange)
	ufmt.Printf("[EXPECTED] protocol fee is 0 (truncated): %d\n", protocolFee)
}

func exactOutLargeAmount() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve)

	userAtomBefore := atom.BalanceOf(adminAddr)
	feeAtomBefore := atom.BalanceOf(protocolFeeAddr)
	poolAtomBefore := atom.BalanceOf(poolAddr)

	// Request 9T tokens
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atonePath,
		atomPath,
		"9000000000000", // 9,000,000,000,000 tokens
		"gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userAtomAfter := atom.BalanceOf(adminAddr)
	feeAtomAfter := atom.BalanceOf(protocolFeeAddr)
	poolAtomAfter := atom.BalanceOf(poolAddr)

	userAtomChange := userAtomAfter - userAtomBefore
	poolAtomChange := poolAtomBefore - poolAtomAfter
	protocolFee := feeAtomAfter - feeAtomBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user atom received: %d\n", userAtomChange)
	ufmt.Printf("[INFO] pool atom output: %d\n", poolAtomChange)
	ufmt.Printf("[INFO] protocol fee (atom): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 9,000,000,000,000 atom: %d\n", userAtomChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolAtomChange, userAtomChange)
}

// Output:
// [SCENARIO] ExactOut Router Fee Edge Cases
//
// [SCENARIO] 1. Initialize pool
// [INFO] created atom:atone:3000 pool with 50T liquidity
//
// [SCENARIO] 2. ExactOut very small amount (1 token)
// [INFO] amountIn: 3, amountOut: -1
// [INFO] user atom received: 1
// [INFO] protocol fee (atom): 0
// [EXPECTED] user receives exactly 1 atom: 1
// [EXPECTED] protocol fee is 0 (truncated): 0
//
// [SCENARIO] 3. ExactOut large amount (9,000,000,000,000 tokens)
// [INFO] amountIn: 11028810316105, amountOut: -9000000000000
// [INFO] user atom received: 9000000000000
// [INFO] pool atom output: 9013520280420
// [INFO] protocol fee (atom): 13520280420
// [EXPECTED] user receives exactly 9,000,000,000,000 atom: 9000000000000
// [EXPECTED] protocol fee = pool output - user received: 13520280420 = 9013520280420 - 9000000000000
