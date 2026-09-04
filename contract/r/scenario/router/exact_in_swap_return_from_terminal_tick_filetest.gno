// PKGPATH: gno.land/r/gnoswap/scenario/router/swap_return_from_terminal_tick

package swap_return_from_terminal_tick

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

	barPath  = "gno.land/r/onbloc/bar.BAR"
	bazPath  = "gno.land/r/onbloc/baz.BAZ"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	forwardRoute = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	reverseRoute = "gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100"
)

// This is intentionally a single narrow position.  There is no full-range
// liquidity to mask a failure to leave a terminal, inactive-liquidity state.
// Terminal-driving swaps intentionally consume less input than requested, so
// they must set an explicit sqrtPriceLimitX96: without one the router now
// reverts on any exact-in swap that cannot consume the full input.
func main(cur realm) {
	println("[SCENARIO] Router returns from terminal tick without full-range liquidity")
	println()
	println("[STEP 1] Initialize pool with a single narrow position")
	setup(cur)

	println("[STEP 2] Move the pool to the lower terminal tick")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=100000 and explicit price limit")
	forwardIn, forwardOut := rt.ExactInSingleSwapRoute(cross(cur), barPath, bazPath, "100000", forwardRoute, "0", lowerTerminalLimit(), deadline, "")
	ufmt.Printf("[RESULT] Forward swap: in=%s out=%s\n", forwardIn, forwardOut)
	assertTick(poolPath, -887271, "lower")

	println()
	println("[STEP 3] Recover from the lower terminal tick")
	println("[ACTION] Execute baz -> bar ExactIn swap with input=1000")
	reverseIn, reverseOut := rt.ExactInSwapRoute(cross(cur), bazPath, barPath, "1000", reverseRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s\n", reverseIn, reverseOut)
	assertTickInRange(poolPath, -50, 50, "lower")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println()
	println("[STEP 4] Move the pool to the upper terminal tick")
	println("[ACTION] Execute baz -> bar ExactIn swap with input=100000 and explicit price limit")
	forwardIn, forwardOut = rt.ExactInSingleSwapRoute(cross(cur), bazPath, barPath, "100000", reverseRoute, "0", upperTerminalLimit(), deadline, "")
	ufmt.Printf("[RESULT] Forward swap: in=%s out=%s\n", forwardIn, forwardOut)
	assertTick(poolPath, 887270, "upper")

	println()
	println("[STEP 5] Recover from the upper terminal tick")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=1000")
	reverseIn, reverseOut = rt.ExactInSwapRoute(cross(cur), barPath, bazPath, "1000", forwardRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s\n", reverseIn, reverseOut)
	assertTickInRange(poolPath, -50, 50, "upper")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println("[RESULT] Router returned from both terminal ticks to active liquidity")
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)
	println("[INFO] Set pool creation fee to 0")
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())
	pl.SetPoolCreationFee(cross(cur), 0)
	println("[INFO] Create bar:baz:100 pool at tick 0")
	pl.CreatePool(cross(cur), barPath, bazPath, fee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	bar.Approve(cross(cur), routerAddr, maxApprove)
	baz.Approve(cross(cur), routerAddr, maxApprove)

	pn.Mint(cross(cur), barPath, bazPath, fee, -50, 50, "10000", "10000", "1", "1", deadline, adminAddr, "")
	println("[SUCCESS] Minted the only position in range [-50, 50]")
}

// lowerTerminalLimit matches the router's default forward limit for fee=100:
// sqrtRatioAtTick(minTick+1) + 1, i.e. the price at the lower terminal tick.
func lowerTerminalLimit() string {
	limit := gnsmath.TickMathGetSqrtRatioAtTick(-887271)
	return new(u256.Uint).Add(limit, u256.One()).ToString()
}

// upperTerminalLimit matches the router's default backward limit for fee=100:
// sqrtRatioAtTick(maxTick-1) - 1, i.e. the price at the upper terminal tick.
func upperTerminalLimit() string {
	limit := gnsmath.TickMathGetSqrtRatioAtTick(887271)
	return new(u256.Uint).Sub(limit, u256.One()).ToString()
}

func assertTick(path string, want int32, terminal string) {
	got, _ := pl.GetSlot0Tick(path)
	ufmt.Printf("[EXPECTED] Tick after %s terminal swap: %d\n", terminal, got)
	if got != want {
		panic(ufmt.Sprintf("expected terminal tick %d, got %d", want, got))
	}
}

func assertTickInRange(path string, lower, upper int32, terminal string) {
	got, _ := pl.GetSlot0Tick(path)
	ufmt.Printf("[EXPECTED] Tick after %s recovery swap: %d\n", terminal, got)
	if got < lower || got > upper {
		panic(ufmt.Sprintf("expected tick in [%d, %d], got %d", lower, upper, got))
	}
}

// Output:
// [SCENARIO] Router returns from terminal tick without full-range liquidity
//
// [STEP 1] Initialize pool with a single narrow position
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool at tick 0
// [SUCCESS] Minted the only position in range [-50, 50]
// [STEP 2] Move the pool to the lower terminal tick
// [ACTION] Execute bar -> baz ExactIn swap with input=100000 and explicit price limit
// [RESULT] Forward swap: in=10028 out=9985
// [EXPECTED] Tick after lower terminal swap: -887271
//
// [STEP 3] Recover from the lower terminal tick
// [ACTION] Execute baz -> bar ExactIn swap with input=1000
// [RESULT] Recovery swap: in=1000 out=1002
// [EXPECTED] Tick after lower recovery swap: -45
// [SUCCESS] Returned to the active [-50, 50] range
//
// [STEP 4] Move the pool to the upper terminal tick
// [ACTION] Execute baz -> bar ExactIn swap with input=100000 and explicit price limit
// [RESULT] Forward swap: in=19030 out=18993
// [EXPECTED] Tick after upper terminal swap: 887270
//
// [STEP 5] Recover from the upper terminal tick
// [ACTION] Execute bar -> baz ExactIn swap with input=1000
// [RESULT] Recovery swap: in=1000 out=1002
// [EXPECTED] Tick after upper recovery swap: 44
// [SUCCESS] Returned to the active [-50, 50] range
// [RESULT] Router returned from both terminal ticks to active liquidity
