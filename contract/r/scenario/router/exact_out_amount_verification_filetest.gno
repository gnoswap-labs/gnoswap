// Comprehensive ExactOut amount verification across various routes, hops, and amounts.
//
// For every case, the core invariant is verified:
//   user receives EXACTLY the requested amountOut
//   protocol fee == pool output - user output
//
// Cases:
//   1. 1-route 1-hop, amount=1,000,000 (standard)
//   2. 1-route 2-hop, amount=1,000,000 (multi-hop)
//   3. 1-route 3-hop, amount=100,000 (max-hop)
//   4. 2-route 1-hop each (50/50 split), amount=1,000,000
//   5. 1-route 1-hop, amount=1 (minimum, rounding boundary)
//   6. 1-route 1-hop, amount=9,000,000,000,000 (large, near int64 scale)
//   7. 1-route 1-hop, different pool fee tier (500 vs 3000)

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
	"gno.land/r/onbloc/qux"
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
	quxPath = "gno.land/r/onbloc/qux"

	min_tick    int32 = -887220
	max_tick    int32 = 887220
	max_timeout int64 = 9999999999
	max_approve int64 = 9223372036854775806
)

func main() {
	println("[SCENARIO] Comprehensive ExactOut Amount Verification")
	println()

	println("[SCENARIO] 1. Setup pools")
	setup()
	println()

	println("[SCENARIO] 2. 1-route 1-hop: ExactOut 1,000,000 bar (baz→bar:3000)")
	singleRouteSingleHop()
	println()

	println("[SCENARIO] 3. 1-route 2-hop: ExactOut 1,000,000 foo (bar→baz→foo)")
	singleRoute2Hop()
	println()

	println("[SCENARIO] 4. 1-route 3-hop: ExactOut 100,000 qux (bar→baz→foo→qux)")
	singleRoute3Hop()
	println()

	println("[SCENARIO] 5. 2-route split (50/50): ExactOut 1,000,000 bar (baz→bar:3000, baz→bar:500)")
	twoRouteSplit()
	println()

	println("[SCENARIO] 6. 1-route 1-hop minimum: ExactOut 1 bar")
	singleHopMinimum()
	println()

	println("[SCENARIO] 7. 1-route 1-hop large: ExactOut 9,000,000,000,000 bar")
	singleHopLarge()
	println()

	println("[SCENARIO] 8. 1-route 1-hop low-fee pool (500): ExactOut 1,000,000 bar")
	singleHopLowFeePool()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, max_approve)
	bar.Approve(cross, poolAddr, max_approve)
	baz.Approve(cross, poolAddr, max_approve)
	foo.Approve(cross, poolAddr, max_approve)
	qux.Approve(cross, poolAddr, max_approve)

	bar.Approve(cross, routerAddr, max_approve)
	baz.Approve(cross, routerAddr, max_approve)
	foo.Approve(cross, routerAddr, max_approve)
	qux.Approve(cross, routerAddr, max_approve)

	sqrtPrice1to1 := "79228162514264337593543950336" // encodePriceSqrt(1, 1)

	// Pool 1: bar:baz fee 3000 (0.3%)
	pl.CreatePool(cross, barPath, bazPath, 3000, sqrtPrice1to1)
	pn.Mint(cross, barPath, bazPath, 3000, min_tick, max_tick,
		"20000000000000", "20000000000000", "0", "0", max_timeout, "")

	// Pool 2: baz:foo fee 3000 (0.3%)
	pl.CreatePool(cross, bazPath, fooPath, 3000, sqrtPrice1to1)
	pn.Mint(cross, bazPath, fooPath, 3000, min_tick, max_tick,
		"20000000000000", "20000000000000", "0", "0", max_timeout, "")

	// Pool 3: foo:qux fee 3000 (0.3%)
	pl.CreatePool(cross, fooPath, quxPath, 3000, sqrtPrice1to1)
	pn.Mint(cross, fooPath, quxPath, 3000, min_tick, max_tick,
		"20000000000000", "20000000000000", "0", "0", max_timeout, "")

	// Pool 4: bar:baz fee 500 (0.05%) — second pool for split route
	pl.CreatePool(cross, barPath, bazPath, 500, sqrtPrice1to1)
	pn.Mint(cross, barPath, bazPath, 500, min_tick, max_tick,
		"20000000000000", "20000000000000", "0", "0", max_timeout, "")

	println("[INFO] created 4 pools: bar:baz:3000, baz:foo:3000, foo:qux:3000, bar:baz:500")
	println("[INFO] all pools at 1:1 price with 20T liquidity each")
}

// Case 2: standard 1-route 1-hop
func singleRouteSingleHop() {
	testing.SetRealm(adminRealm)

	userBefore := bar.BalanceOf(adminAddr)
	feeBefore := bar.BalanceOf(protocolFeeAddr)
	poolBefore := bar.BalanceOf(poolAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, bazPath, barPath, "1000000",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000", "100",
		"9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := bar.BalanceOf(adminAddr) - userBefore
	poolChange := poolBefore - bar.BalanceOf(poolAddr)
	feeChange := bar.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 1000000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee: %d = pool(%d) - user(%d)\n", feeChange, poolChange, userChange)
}

// Case 3: 1-route 2-hop (bar → baz → foo)
func singleRoute2Hop() {
	testing.SetRealm(adminRealm)

	userBefore := foo.BalanceOf(adminAddr)
	feeBefore := foo.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, barPath, fooPath, "1000000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:3000",
		"100", "9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := foo.BalanceOf(adminAddr) - userBefore
	feeChange := foo.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 1000000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee (foo): %d\n", feeChange)
}

// Case 4: 1-route 3-hop (bar → baz → foo → qux)
func singleRoute3Hop() {
	testing.SetRealm(adminRealm)

	userBefore := qux.BalanceOf(adminAddr)
	feeBefore := qux.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, barPath, quxPath, "100000",
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/foo:3000*POOL*gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:3000",
		"100", "9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := qux.BalanceOf(adminAddr) - userBefore
	feeChange := qux.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 100000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee (qux): %d\n", feeChange)
}

// Case 5: 2-route split 50/50 (baz→bar via fee3000 and fee500)
func twoRouteSplit() {
	testing.SetRealm(adminRealm)

	userBefore := bar.BalanceOf(adminAddr)
	feeBefore := bar.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, bazPath, barPath, "1000000",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000,gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500",
		"50,50", "9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := bar.BalanceOf(adminAddr) - userBefore
	feeChange := bar.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 1000000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee (bar): %d\n", feeChange)
}

// Case 6: minimum amount (1 token)
func singleHopMinimum() {
	testing.SetRealm(adminRealm)

	userBefore := bar.BalanceOf(adminAddr)
	feeBefore := bar.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, bazPath, barPath, "1",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000", "100",
		"9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := bar.BalanceOf(adminAddr) - userBefore
	feeChange := bar.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 1)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee: %d (want: 0, truncated)\n", feeChange)
}

// Case 7: large amount (9T)
func singleHopLarge() {
	testing.SetRealm(adminRealm)

	userBefore := bar.BalanceOf(adminAddr)
	feeBefore := bar.BalanceOf(protocolFeeAddr)
	poolBefore := bar.BalanceOf(poolAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, bazPath, barPath, "9000000000000",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000", "100",
		"9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := bar.BalanceOf(adminAddr) - userBefore
	poolChange := poolBefore - bar.BalanceOf(poolAddr)
	feeChange := bar.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 9000000000000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee: %d = pool(%d) - user(%d)\n", feeChange, poolChange, userChange)
}

// Case 8: low-fee pool (500 = 0.05%)
func singleHopLowFeePool() {
	testing.SetRealm(adminRealm)

	userBefore := bar.BalanceOf(adminAddr)
	feeBefore := bar.BalanceOf(protocolFeeAddr)

	amountIn, amountOut := router.ExactOutSwapRoute(
		cross, bazPath, barPath, "1000000",
		"gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500", "100",
		"9223372036854775807", time.Now().Add(time.Hour).Unix(), "",
	)

	userChange := bar.BalanceOf(adminAddr) - userBefore
	feeChange := bar.BalanceOf(protocolFeeAddr) - feeBefore

	ufmt.Printf("[INFO] amountIn=%s amountOut=%s\n", amountIn, amountOut)
	ufmt.Printf("[EXPECTED] user received: %d (want: 1000000)\n", userChange)
	ufmt.Printf("[EXPECTED] protocol fee (bar): %d\n", feeChange)
}

// Output:
// [SCENARIO] Comprehensive ExactOut Amount Verification
//
// [SCENARIO] 1. Setup pools
// [INFO] created 4 pools: bar:baz:3000, baz:foo:3000, foo:qux:3000, bar:baz:500
// [INFO] all pools at 1:1 price with 20T liquidity each
//
// [SCENARIO] 2. 1-route 1-hop: ExactOut 1,000,000 bar (baz→bar:3000)
// [INFO] amountIn=1004517 amountOut=-1000000
// [EXPECTED] user received: 1000000 (want: 1000000)
// [EXPECTED] protocol fee: 1502 = pool(1001502) - user(1000000)
//
// [SCENARIO] 3. 1-route 2-hop: ExactOut 1,000,000 foo (bar→baz→foo)
// [INFO] amountIn=1007543 amountOut=-1000000
// [EXPECTED] user received: 1000000 (want: 1000000)
// [EXPECTED] protocol fee (foo): 1502
//
// [SCENARIO] 4. 1-route 3-hop: ExactOut 100,000 qux (bar→baz→foo→qux)
// [INFO] amountIn=101062 amountOut=-100000
// [EXPECTED] user received: 100000 (want: 100000)
// [EXPECTED] protocol fee (qux): 150
//
// [SCENARIO] 5. 2-route split (50/50): ExactOut 1,000,000 bar (baz→bar:3000, baz→bar:500)
// [INFO] amountIn=1003262 amountOut=-1000000
// [EXPECTED] user received: 1000000 (want: 1000000)
// [EXPECTED] protocol fee (bar): 1502
//
// [SCENARIO] 6. 1-route 1-hop minimum: ExactOut 1 bar
// [INFO] amountIn=3 amountOut=-1
// [EXPECTED] user received: 1 (want: 1)
// [EXPECTED] protocol fee: 0 (want: 0, truncated)
//
// [SCENARIO] 7. 1-route 1-hop large: ExactOut 9,000,000,000,000 bar
// [INFO] amountIn=16457760709370 amountOut=-9000000000000
// [EXPECTED] user received: 9000000000000 (want: 9000000000000)
// [EXPECTED] protocol fee: 13520280420 = pool(9013520280420) - user(9000000000000)
//
// [SCENARIO] 8. 1-route 1-hop low-fee pool (500): ExactOut 1,000,000 bar
// [INFO] amountIn=1002005 amountOut=-1000000
// [EXPECTED] user received: 1000000 (want: 1000000)
// [EXPECTED] protocol fee (bar): 1502

