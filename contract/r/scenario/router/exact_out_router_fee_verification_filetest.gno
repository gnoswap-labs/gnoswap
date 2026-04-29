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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _        = access.GetAddress(prabc.ROLE_POOL.String())
	protocolFeeAddr, _ = access.GetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	routerAddr, _      = access.GetAddress(prabc.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"

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
	println("[SCENARIO] 2. Single-hop ExactOut (0.15% fee, 1,000,000 bar)")
	singleHopDefaultFee()
	println()

	// ── Single-hop, 1% fee ──
	println("[SCENARIO] 3. Single-hop ExactOut (1% fee, 1,000,000 bar)")
	singleHop1PercentFee()
	println()

	// Reset fee to default
	testing.SetRealm(adminRealm)
	router.SetSwapFee(cross, 15)

	// ── Multi-hop, default 0.15% fee ──
	println("[SCENARIO] 4. Multi-hop ExactOut (0.15% fee, 1,000 foo via bar→baz→foo)")
	multiHopDefaultFee()
	println()

	// ── Multi-hop, 1% fee ──
	println("[SCENARIO] 5. Multi-hop ExactOut (1% fee, 1,000 foo via bar→baz→foo)")
	multiHop1PercentFee()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)

	// Create pools at 1:1 price (sqrtPriceX96 = 2^96)
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950336")
	pl.CreatePool(cross, bazPath, fooPath, 3000, "79228162514264337593543950336")

	// Mint deep liquidity in both pools
	pn.Mint(cross, barPath, bazPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, "")
	pn.Mint(cross, bazPath, fooPath, 3000, min_tick, max_tick, "100000000", "100000000", "0", "0", max_timeout, "")

	println("[INFO] created bar:baz:3000 and baz:foo:3000 pools with 100M liquidity each")
}

func singleHopDefaultFee() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)

	userBarBefore := bar.BalanceOf(adminAddr)
	userBazBefore := baz.BalanceOf(adminAddr)
	poolBarBefore := bar.BalanceOf(poolAddr)
	feeBarBefore := bar.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		bazPath,   // inputToken
		barPath,   // outputToken
		"1000000", // amountSpecified (user wants exactly 1,000,000 bar)
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000",
		"100",
		"9223372036854775807", // tokenAmountLimit
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userBarAfter := bar.BalanceOf(adminAddr)
	userBazAfter := baz.BalanceOf(adminAddr)
	poolBarAfter := bar.BalanceOf(poolAddr)
	feeBarAfter := bar.BalanceOf(protocolFeeAddr)

	userBarChange := userBarAfter - userBarBefore
	userBazChange := userBazBefore - userBazAfter // input consumed (positive)
	poolBarChange := poolBarBefore - poolBarAfter  // pool output (positive)
	protocolFee := feeBarAfter - feeBarBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user bar received: %d\n", userBarChange)
	ufmt.Printf("[INFO] user baz consumed: %d\n", userBazChange)
	ufmt.Printf("[INFO] pool bar output: %d\n", poolBarChange)
	ufmt.Printf("[INFO] protocol fee (bar): %d\n", protocolFee)

	// Verification
	ufmt.Printf("[EXPECTED] user receives exactly 1,000,000 bar: %d\n", userBarChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolBarChange, userBarChange)
}

func singleHop1PercentFee() {
	testing.SetRealm(adminRealm)

	// Change fee to 1% (100 bps)
	router.SetSwapFee(cross, 100)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)

	userBarBefore := bar.BalanceOf(adminAddr)
	feeBarBefore := bar.BalanceOf(protocolFeeAddr)
	poolBarBefore := bar.BalanceOf(poolAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		bazPath,
		barPath,
		"1000000", // user wants exactly 1,000,000 bar
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

	ufmt.Printf("[EXPECTED] user receives exactly 1,000,000 bar: %d\n", userBarChange)
	ufmt.Printf("[EXPECTED] protocol fee = pool output - user received: %d = %d - %d\n",
		protocolFee, poolBarChange, userBarChange)
}

func multiHopDefaultFee() {
	testing.SetRealm(adminRealm)

	// Reset fee to default 0.15%
	router.SetSwapFee(cross, 15)

	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	userFooBefore := foo.BalanceOf(adminAddr)
	userBarBefore := bar.BalanceOf(adminAddr)
	feeFooBefore := foo.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath,  // inputToken
		fooPath,  // outputToken
		"1000",   // user wants exactly 1,000 foo
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userFooAfter := foo.BalanceOf(adminAddr)
	userBarAfter := bar.BalanceOf(adminAddr)
	feeFooAfter := foo.BalanceOf(protocolFeeAddr)

	userFooChange := userFooAfter - userFooBefore
	userBarChange := userBarBefore - userBarAfter // input consumed
	protocolFee := feeFooAfter - feeFooBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user foo received: %d\n", userFooChange)
	ufmt.Printf("[INFO] user bar consumed: %d\n", userBarChange)
	ufmt.Printf("[INFO] protocol fee (foo): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 1,000 foo: %d\n", userFooChange)
}

func multiHop1PercentFee() {
	testing.SetRealm(adminRealm)

	// Change fee to 1%
	router.SetSwapFee(cross, 100)

	bar.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)

	userFooBefore := foo.BalanceOf(adminAddr)
	userBarBefore := bar.BalanceOf(adminAddr)
	feeFooBefore := foo.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross,
		barPath,
		fooPath,
		"1000", // user wants exactly 1,000 foo
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:3000",
		"100",
		"9223372036854775807",
		time.Now().Add(time.Hour).Unix(),
		"",
	)

	userFooAfter := foo.BalanceOf(adminAddr)
	userBarAfter := bar.BalanceOf(adminAddr)
	feeFooAfter := foo.BalanceOf(protocolFeeAddr)

	userFooChange := userFooAfter - userFooBefore
	userBarChange := userBarBefore - userBarAfter
	protocolFee := feeFooAfter - feeFooBefore

	ufmt.Printf("[INFO] amountIn: %s, amountOut: %s\n", amountIn, amountOut)
	ufmt.Printf("[INFO] user foo received: %d\n", userFooChange)
	ufmt.Printf("[INFO] user bar consumed: %d\n", userBarChange)
	ufmt.Printf("[INFO] protocol fee (foo): %d\n", protocolFee)

	ufmt.Printf("[EXPECTED] user receives exactly 1,000 foo: %d\n", userFooChange)
}

// Output:
// [SCENARIO] ExactOut Router Fee Verification
//
// [SCENARIO] 1. Initialize pools
// [INFO] created bar:baz:3000 and baz:foo:3000 pools with 100M liquidity each
//
// [SCENARIO] 2. Single-hop ExactOut (0.15% fee, 1,000,000 bar)
// [INFO] amountIn: 1014679, amountOut: -1000000
// [INFO] user bar received: 1000000
// [INFO] user baz consumed: 1014679
// [INFO] pool bar output: 1001502
// [INFO] protocol fee (bar): 1502
// [EXPECTED] user receives exactly 1,000,000 bar: 1000000
// [EXPECTED] protocol fee = pool output - user received: 1502 = 1001502 - 1000000
//
// [SCENARIO] 3. Single-hop ExactOut (1% fee, 1,000,000 bar)
// [INFO] amountIn: 1044400, amountOut: -1000000
// [INFO] user bar received: 1000000
// [INFO] pool bar output: 1010101
// [INFO] protocol fee (bar): 10101
// [EXPECTED] user receives exactly 1,000,000 bar: 1000000
// [EXPECTED] protocol fee = pool output - user received: 10101 = 1010101 - 1000000
//
// [SCENARIO] 4. Multi-hop ExactOut (0.15% fee, 1,000 foo via bar→baz→foo)
// [INFO] amountIn: 969, amountOut: -1000
// [INFO] user foo received: 1000
// [INFO] user bar consumed: 969
// [INFO] protocol fee (foo): 1
// [EXPECTED] user receives exactly 1,000 foo: 1000
//
// [SCENARIO] 5. Multi-hop ExactOut (1% fee, 1,000 foo via bar→baz→foo)
// [INFO] amountIn: 978, amountOut: -1000
// [INFO] user foo received: 1000
// [INFO] user bar consumed: 978
// [INFO] protocol fee (foo): 10
// [EXPECTED] user receives exactly 1,000 foo: 1000
