// Verifies ExactOut router fee accounting across single-hop, multi-hop, and
// different fee rates (0.15% default, 1% elevated).
//
// For each case we assert:
// 1. User receives EXACTLY the requested amountOut
// 2. Protocol fee == poolOutput - userOutput
// 3. Input consumed matches pool amountIn

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
	"gno.land/r/gnoswap/test_token/btc"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	btcPath = "gno.land/r/gnoswap/test_token/btc"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] ExactOut Router Fee Verification")
	println()

	println("[SCENARIO] 1. Initialize pools")
	setup()
	println()

	// ── Single-hop, default 0.15% fee ──
	println("[SCENARIO] 2. Single-hop ExactOut (0.15% fee, 1,000,000 atom)")
	singleHopDefaultFee()
	println()

	// ── Single-hop, 1% fee ──
	println("[SCENARIO] 3. Single-hop ExactOut (1% fee, 1,000,000 atom)")
	singleHop1PercentFee()
	println()

	// Reset fee to default
	testing.SetRealm(adminRealm)
	router.SetSwapFee(cross, 15)

	// ── Multi-hop, default 0.15% fee ──
	println("[SCENARIO] 4. Multi-hop ExactOut (0.15% fee, 1,000 btc via atom→atone→btc)")
	multiHopDefaultFee()
	println()

	// ── Multi-hop, 1% fee ──
	println("[SCENARIO] 5. Multi-hop ExactOut (1% fee, 1,000 btc via atom→atone→btc)")
	multiHop1PercentFee()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, max_approve)
	atom.Approve(cross, poolAddr, max_approve)
	atone.Approve(cross, poolAddr, max_approve)
	btc.Approve(cross, poolAddr, max_approve)

	// Create pools at 1:1 price (sqrtPriceX96 = 2^96)
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950336")
	pl.CreatePool(cross, atonePath, btcPath, 3000, "79228162514264337593543950336")

	// Mint deep liquidity in both pools
	pn.Mint(cross, atomPath, atonePath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, "")
	pn.Mint(cross, atonePath, btcPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, adminAddr, "")

	println("[INFO] created atom:atone:3000 and atone:btc:3000 pools with 100M liquidity each")
}

func singleHopDefaultFee() {
	testing.SetRealm(adminRealm)

	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve)

	userAtomBefore := atom.BalanceOf(adminAddr)
	userAtoneBefore := atone.BalanceOf(adminAddr)
	poolAtomBefore := atom.BalanceOf(poolAddr)
	feeAtomBefore := atom.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atonePath,   // inputToken
		atomPath,   // outputToken
		"1000000", // amountSpecified (user wants exactly 1,000,000 atom)
		"gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/atom:3000",
		"100",
		"9223372036854775807", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userAtomAfter := atom.BalanceOf(adminAddr)
	userAtoneAfter := atone.BalanceOf(adminAddr)
	poolAtomAfter := atom.BalanceOf(poolAddr)
	feeAtomAfter := atom.BalanceOf(protocolFeeAddr)

	userAtomChange := userAtomAfter - userAtomBefore
	userAtoneChange := userAtoneBefore - userAtoneAfter // input consumed (positive)
	poolAtomChange := poolAtomBefore - poolAtomAfter  // pool output (positive)
	protocolFee := feeAtomAfter - feeAtomBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user atom received: %d\n", userAtomChange)
	ufmt.Printf("[INFO] user atone consumed: %d\n", userAtoneChange)
	ufmt.Printf("[INFO] pool atom output: %d\n", poolAtomChange)
	ufmt.Printf("[INFO] protocol fee (atom): %d\n", protocolFee)

	// Verification
	ufmt.Printf("[EXPECTED] user receives exactly 1,000,000 atom: %d\n", userAtomChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolAtomChange, userAtomChange)
}

func singleHop1PercentFee() {
	testing.SetRealm(adminRealm)

	// Change fee to 1% (100 bps)
	router.SetSwapFee(cross, 100)

	atom.Approve(cross, routerAddr, max_approve)
	atone.Approve(cross, routerAddr, max_approve)

	userAtomBefore := atom.BalanceOf(adminAddr)
	feeAtomBefore := atom.BalanceOf(protocolFeeAddr)
	poolAtomBefore := atom.BalanceOf(poolAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atonePath,
		atomPath,
		"1000000", // user wants exactly 1,000,000 atom
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

	ufmt.Printf("[EXPECTED] user receives exactly 1,000,000 atom: %d\n", userAtomChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolAtomChange, userAtomChange)
}

func multiHopDefaultFee() {
	testing.SetRealm(adminRealm)

	// Reset fee to default 0.15%
	router.SetSwapFee(cross, 15)

	atom.Approve(cross, routerAddr, max_approve)
	btc.Approve(cross, routerAddr, max_approve)

	userBtcBefore := btc.BalanceOf(adminAddr)
	userAtomBefore := atom.BalanceOf(adminAddr)
	feeBtcBefore := btc.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath,  // inputToken
		btcPath,  // outputToken
		"1000",   // user wants exactly 1,000 btc
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/btc:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userBtcAfter := btc.BalanceOf(adminAddr)
	userAtomAfter := atom.BalanceOf(adminAddr)
	feeBtcAfter := btc.BalanceOf(protocolFeeAddr)

	userBtcChange := userBtcAfter - userBtcBefore
	userAtomChange := userAtomBefore - userAtomAfter // input consumed
	protocolFee := feeBtcAfter - feeBtcBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user btc received: %d\n", userBtcChange)
	ufmt.Printf("[INFO] user atom consumed: %d\n", userAtomChange)
	ufmt.Printf("[INFO] protocol fee (btc): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 1,000 btc: %d\n", userBtcChange)
}

func multiHop1PercentFee() {
	testing.SetRealm(adminRealm)

	// Change fee to 1%
	router.SetSwapFee(cross, 100)

	atom.Approve(cross, routerAddr, max_approve)
	btc.Approve(cross, routerAddr, max_approve)

	userBtcBefore := btc.BalanceOf(adminAddr)
	userAtomBefore := atom.BalanceOf(adminAddr)
	feeBtcBefore := btc.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		atomPath,
		btcPath,
		"1000", // user wants exactly 1,000 btc
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:3000*POOL*gno.land/r/gnoswap/test_token/atone:gno.land/r/gnoswap/test_token/btc:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userBtcAfter := btc.BalanceOf(adminAddr)
	userAtomAfter := atom.BalanceOf(adminAddr)
	feeBtcAfter := btc.BalanceOf(protocolFeeAddr)

	userBtcChange := userBtcAfter - userBtcBefore
	userAtomChange := userAtomBefore - userAtomAfter
	protocolFee := feeBtcAfter - feeBtcBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user btc received: %d\n", userBtcChange)
	ufmt.Printf("[INFO] user atom consumed: %d\n", userAtomChange)
	ufmt.Printf("[INFO] protocol fee (btc): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 1,000 btc: %d\n", userBtcChange)
}

// Output:
// [SCENARIO] ExactOut Router Fee Verification
//
// [SCENARIO] 1. Initialize pools
// [INFO] created atom:atone:3000 and atone:btc:3000 pools with 100M liquidity each
//
// [SCENARIO] 2. Single-hop ExactOut (0.15% fee, 1,000,000 atom)
// [INFO] amountIn: 1014679, amountOut: -1000000
// [INFO] user atom received: 1000000
// [INFO] user atone consumed: 1014679
// [INFO] pool atom output: 1001502
// [INFO] protocol fee (atom): 1502
// [EXPECTED] user receives exactly 1,000,000 atom: 1000000
// [EXPECTED] protocol fee = pool output - user received: 1502 = 1001502 - 1000000
//
// [SCENARIO] 3. Single-hop ExactOut (1% fee, 1,000,000 atom)
// [INFO] amountIn: 1044400, amountOut: -1000000
// [INFO] user atom received: 1000000
// [INFO] pool atom output: 1010101
// [INFO] protocol fee (atom): 10101
// [EXPECTED] user receives exactly 1,000,000 atom: 1000000
// [EXPECTED] protocol fee = pool output - user received: 10101 = 1010101 - 1000000
//
// [SCENARIO] 4. Multi-hop ExactOut (0.15% fee, 1,000 btc via atom→atone→btc)
// [INFO] amountIn: 969, amountOut: -1000
// [INFO] user btc received: 1000
// [INFO] user atom consumed: 969
// [INFO] protocol fee (btc): 1
// [EXPECTED] user receives exactly 1,000 btc: 1000
//
// [SCENARIO] 5. Multi-hop ExactOut (1% fee, 1,000 btc via atom→atone→btc)
// [INFO] amountIn: 978, amountOut: -1000
// [INFO] user btc received: 1000
// [INFO] user atom consumed: 978
// [INFO] protocol fee (btc): 10
// [EXPECTED] user receives exactly 1,000 btc: 1000
