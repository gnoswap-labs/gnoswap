// PKGPATH: gno.land/r/gnoswap/scenario/router/exact_out_swap_return_from_terminal_tick

package exact_out_swap_return_from_terminal_tick

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
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
)

// The forward swaps intentionally exhaust the only [-50, 50] liquidity range.
// Each reverse is ExactOut: it requests 1,000 output tokens at a bounded max input.
func main(cur realm) {
	println("[SCENARIO] Router ExactOut returns from terminal ticks without full-range liquidity")
	println()
	println("[STEP 1] Initialize pool with a single narrow position")
	setup(cur)

	println("[STEP 2] Move the pool to the lower terminal tick")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=100000")
	forwardIn, forwardOut := rt.ExactInSwapRoute(cross(cur), barPath, bazPath, "100000", forwardRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Forward swap: in=%s out=%s\n", forwardIn, forwardOut)
	assertTick(-887271, "lower terminal")

	println()
	println("[STEP 3] Recover from the lower terminal tick with ExactOut")
	println("[ACTION] Request 1000 bar with bounded max input=10000")
	in, out := rt.ExactOutSwapRoute(cross(cur), bazPath, barPath, "1000", reverseRoute, "100", "10000", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s\n", in, out)
	assertInRange("lower ExactOut reverse")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println()
	println("[STEP 4] Move the pool to the upper terminal tick")
	println("[ACTION] Execute baz -> bar ExactIn swap with input=100000")
	forwardIn, forwardOut = rt.ExactInSwapRoute(cross(cur), bazPath, barPath, "100000", reverseRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Forward swap: in=%s out=%s\n", forwardIn, forwardOut)
	assertTick(887270, "upper terminal")

	println()
	println("[STEP 5] Recover from the upper terminal tick with ExactOut")
	println("[ACTION] Request 1000 baz with bounded max input=10000")
	in, out = rt.ExactOutSwapRoute(cross(cur), barPath, bazPath, "1000", forwardRoute, "100", "10000", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s\n", in, out)
	assertInRange("upper ExactOut reverse")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println("[RESULT] Router ExactOut returned from both terminal ticks")
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

func assertTick(want int32, label string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] Tick after %s: %d\n", label, got)
	if got != want {
		panic(ufmt.Sprintf("expected %s tick %d, got %d", label, want, got))
	}
}

func assertInRange(label string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] Tick after %s: %d\n", label, got)
	if got < -50 || got > 50 {
		panic(ufmt.Sprintf("expected %s to return to [-50, 50], got %d", label, got))
	}
}

// Output:
// [SCENARIO] Router ExactOut returns from terminal ticks without full-range liquidity
//
// [STEP 1] Initialize pool with a single narrow position
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool at tick 0
// [SUCCESS] Minted the only position in range [-50, 50]
// [STEP 2] Move the pool to the lower terminal tick
// [ACTION] Execute bar -> baz ExactIn swap with input=100000
// [RESULT] Forward swap: in=10028 out=-9985
// [EXPECTED] Tick after lower terminal: -887271
//
// [STEP 3] Recover from the lower terminal tick with ExactOut
// [ACTION] Request 1000 bar with bounded max input=10000
// [RESULT] Recovery swap: in=998 out=-1000
// [EXPECTED] Tick after lower ExactOut reverse: -46
// [SUCCESS] Returned to the active [-50, 50] range
//
// [STEP 4] Move the pool to the upper terminal tick
// [ACTION] Execute baz -> bar ExactIn swap with input=100000
// [RESULT] Forward swap: in=19033 out=-18995
// [EXPECTED] Tick after upper terminal: 887270
//
// [STEP 5] Recover from the upper terminal tick with ExactOut
// [ACTION] Request 1000 baz with bounded max input=10000
// [RESULT] Recovery swap: in=998 out=-1000
// [EXPECTED] Tick after upper ExactOut reverse: 45
// [SUCCESS] Returned to the active [-50, 50] range
// [RESULT] Router ExactOut returned from both terminal ticks
