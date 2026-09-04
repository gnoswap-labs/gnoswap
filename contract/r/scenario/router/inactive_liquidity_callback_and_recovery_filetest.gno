// PKGPATH: gno.land/r/gnoswap/scenario/router/inactive_liquidity_callback_and_recovery

package inactive_liquidity_callback_and_recovery

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	rt "gno.land/r/gnoswap/router"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee       uint32 = 100
	maxApprove int64  = 9223372036854775807
	deadline   int64  = 9999999999
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	barPath      = "gno.land/r/onbloc/bar.BAR"
	bazPath      = "gno.land/r/onbloc/baz.BAZ"
	poolPath     = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	forwardRoute = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	reverseRoute = "gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100"
	middleLiquidity string
)

func main(cur realm) {
	println("[SCENARIO] Router inactive-liquidity callback and recovery")
	println()
	println("[STEP 1] Initialize pool at tick 0")
	setup(cur)

	println()
	println("[STEP 2] Mint active and out-of-range positions")
	println("[INFO] Active range: [-50, 50], out-of-range: [100, 200]")
	mintMiddleAndOutOfRangeLiquidity(cur)
	assertActiveLiquidity(false, "minting the middle position")

	println()
	println("[STEP 3] Remove the active middle position")
	println("[ACTION] Decrease all liquidity from position ID=1")
	removeMiddleLiquidity(cur)
	assertActiveLiquidity(true, "removing the middle position")

	// There is no initialized liquidity below tick 0. Pool.Swap calls the router
	// callback with zero deltas, and router SwapCallback must abort with the
	// insufficient-liquidity error. The failed callback is caught with revive;
	// the pool has already traversed the inactive interval to the lower terminal.
	println()
	println("[STEP 4] Swap toward the empty lower side")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=100000")
	assertCallbackPanicTowardEmptySide(cur)
	assertTick(-887271, "tick after empty-side callback abort")

	// The opposite direction first crosses inactive ticks, enters [100, 200],
	// consumes that liquidity, then reaches the upper terminal tick.
	println()
	println("[STEP 5] Cross remaining [100, 200] liquidity and reach the upper terminal")
	println("[ACTION] Execute baz -> bar ExactIn swap with input=100000 and explicit price limit")
	moveTowardOutOfRangeLiquidityAndTerminal(cur)
	assertTick(887270, "tick after crossing out-of-range liquidity")

	// The middle position stays removed. A bounded reverse swap must re-enter
	// the remaining [100, 200] position and reactivate its liquidity.
	println()
	println("[STEP 6] Recover from the upper terminal")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=1000")
	recoverToOutOfRangeLiquidity(cur)
	assertTickInRange(100, 200, "tick after recovery swap")
	assertActiveLiquidity(false, "re-entering the out-of-range position")
	println("[SUCCESS] Re-entered and reactivated the [100, 200] position")

	println("[RESULT] Router callback panic and inactive-liquidity recovery verified")
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)
	println("[INFO] Set pool creation fee to 0")
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())
	pl.SetPoolCreationFee(cross(cur), 0)
	println("[INFO] Create bar:baz:100 pool")
	pl.CreatePool(cross(cur), barPath, bazPath, fee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), routerAddr, maxApprove)
	baz.Approve(cross(cur), routerAddr, maxApprove)
}

func mintMiddleAndOutOfRangeLiquidity(cur realm) {
	testing.SetRealm(adminRealm)
	_, middleLiquidity, _, _ = pn.Mint(cross(cur), barPath, bazPath, fee, -50, 50, "10000", "10000", "1", "1", deadline, adminAddr, "")
	_, outLiquidity, _, _ := pn.Mint(cross(cur), barPath, bazPath, fee, 100, 200, "10000", "10000", "0", "0", deadline, adminAddr, "")
	ufmt.Printf("[SUCCESS] Minted middle liquidity=%s, out-of-range liquidity=%s\n", middleLiquidity, outLiquidity)
}

func removeMiddleLiquidity(cur realm) {
	testing.SetRealm(adminRealm)
	_, removed, _, _, _, _, _ := pn.DecreaseLiquidity(cross(cur), 1, middleLiquidity, "0", "0", deadline)
	ufmt.Printf("[RESULT] Removed middle liquidity: %s\n", removed)
	if removed != middleLiquidity {
		panic("middle position liquidity must be fully removed")
	}
}

func assertCallbackPanicTowardEmptySide(cur realm) {
	testing.SetRealm(adminRealm)
	r := revive(func() {
		rt.ExactInSwapRoute(cross(cur), barPath, bazPath, "100000", forwardRoute, "100", "0", deadline, "")
	})
	if r == nil {
		panic("expected router callback to abort in the empty direction")
	}
	ufmt.Printf("[RESULT] Empty-side swap aborted as expected: %v\n", r)
}

// The terminal-driving swap intentionally consumes less input than requested,
// so it must set an explicit sqrtPriceLimitX96: without one the router now
// reverts on any exact-in swap that cannot consume the full input.
func moveTowardOutOfRangeLiquidityAndTerminal(cur realm) {
	testing.SetRealm(adminRealm)
	limit := new(u256.Uint).Sub(gnsmath.TickMathGetSqrtRatioAtTick(887271), u256.One()).ToString()
	in, out := rt.ExactInSingleSwapRoute(cross(cur), bazPath, barPath, "100000", reverseRoute, "0", limit, deadline, "")
	ufmt.Printf("[RESULT] Forward swap: in=%s out=%s\n", in, out)
}

func recoverToOutOfRangeLiquidity(cur realm) {
	testing.SetRealm(adminRealm)
	in, out := rt.ExactInSwapRoute(cross(cur), barPath, bazPath, "1000", forwardRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s\n", in, out)
}

func assertTick(want int32, label string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] %s: %d\n", label, got)
	if got != want {
		panic(ufmt.Sprintf("expected tick %d, got %d", want, got))
	}
}

func assertTickInRange(lower, upper int32, label string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] %s: %d\n", label, got)
	if got < lower || got > upper {
		panic(ufmt.Sprintf("expected tick in [%d, %d], got %d", lower, upper, got))
	}
}

func assertActiveLiquidity(wantZero bool, label string) {
	p, _ := pl.GetPools().Get(poolPath).(*pl.Pool)
	zero := p.Liquidity().IsZero()
	ufmt.Printf("[EXPECTED] Active liquidity is zero after %s: %t\n", label, zero)
	if zero != wantZero {
		panic(ufmt.Sprintf("unexpected active liquidity state: zero=%t", zero))
	}
}

// Output:
// [SCENARIO] Router inactive-liquidity callback and recovery
//
// [STEP 1] Initialize pool at tick 0
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool
//
// [STEP 2] Mint active and out-of-range positions
// [INFO] Active range: [-50, 50], out-of-range: [100, 200]
// [SUCCESS] Minted middle liquidity=4005202, out-of-range liquidity=2015154
// [EXPECTED] Active liquidity is zero after minting the middle position: false
//
// [STEP 3] Remove the active middle position
// [ACTION] Decrease all liquidity from position ID=1
// [RESULT] Removed middle liquidity: 4005202
// [EXPECTED] Active liquidity is zero after removing the middle position: true
//
// [STEP 4] Swap toward the empty lower side
// [ACTION] Execute bar -> baz ExactIn swap with input=100000
// [RESULT] Empty-side swap aborted as expected: [GNOSWAP-ROUTER-020] insufficient liquidity for swap || swap entirely within 0-liquidity region
// [EXPECTED] tick after empty-side callback abort: -887271
//
// [STEP 5] Cross remaining [100, 200] liquidity and reach the upper terminal
// [ACTION] Execute baz -> bar ExactIn swap with input=100000 and explicit price limit
// [RESULT] Forward swap: in=10154 out=9985
// [EXPECTED] tick after crossing out-of-range liquidity: 887270
//
// [STEP 6] Recover from the upper terminal
// [ACTION] Execute bar -> baz ExactIn swap with input=1000
// [RESULT] Recovery swap: in=1000 out=1017
// [EXPECTED] tick after recovery swap: 189
// [EXPECTED] Active liquidity is zero after re-entering the out-of-range position: false
// [SUCCESS] Re-entered and reactivated the [100, 200] position
// [RESULT] Router callback panic and inactive-liquidity recovery verified
