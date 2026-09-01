// PKGPATH: gno.land/r/gnoswap/scenario/pool/exact_out_swap_return_from_terminal_tick

package exact_out_swap_return_from_terminal_tick

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/demo/defi/grc20reg"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee        uint32 = 100
	maxApprove int64  = 9223372036854775807
	minPrice          = "4295128740"
	maxPrice          = "1461446703485210103287273052203988822378723970341"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())
	routerRealm  = testing.NewCodeRealm("gno.land/r/gnoswap/router")

	barPath  = "gno.land/r/onbloc/bar.BAR"
	bazPath  = "gno.land/r/onbloc/baz.BAZ"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
)

// Pool.Swap uses a negative amountSpecified for ExactOut.  The callback only
// settles the amount owed to the pool, keeping router behavior out of this test.
func main(cur realm) {
	println("[SCENARIO] Pool ExactOut returns from terminal ticks without full-range liquidity")
	println()
	println("[STEP 1] Initialize pool with a single narrow position")
	setup(cur)

	println("[STEP 2] Move the pool to the lower terminal tick")
	println("[ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=100000")
	testing.SetRealm(routerRealm)
	forward0, forward1 := pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, true, "100000", minPrice, settleSwap)
	ufmt.Printf("[RESULT] Forward swap: amount0=%s amount1=%s\n", forward0, forward1)
	assertTick(-887272, "lower terminal")

	println()
	println("[STEP 3] Recover from the lower terminal tick with ExactOut")
	println("[ACTION] Request 1000 bar by calling Pool.Swap directly")
	testing.SetRealm(routerRealm)
	in0, out1 := pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, false, "-1000", maxPrice, settleSwap)
	ufmt.Printf("[RESULT] Recovery swap: amount0=%s amount1=%s\n", in0, out1)
	assertInRange("lower ExactOut reverse")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println()
	println("[STEP 4] Move the pool to the upper terminal tick")
	println("[ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=100000")
	testing.SetRealm(routerRealm)
	forward0, forward1 = pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, false, "100000", maxPrice, settleSwap)
	ufmt.Printf("[RESULT] Forward swap: amount0=%s amount1=%s\n", forward0, forward1)
	assertTick(887271, "upper terminal")

	println()
	println("[STEP 5] Recover from the upper terminal tick with ExactOut")
	println("[ACTION] Request 1000 baz by calling Pool.Swap directly")
	testing.SetRealm(routerRealm)
	in0, out1 = pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, true, "-1000", minPrice, settleSwap)
	ufmt.Printf("[RESULT] Recovery swap: amount0=%s amount1=%s\n", in0, out1)
	assertInRange("upper ExactOut reverse")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println("[RESULT] Pool ExactOut returned from both terminal ticks")
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
	pn.Mint(cross(cur), barPath, bazPath, fee, -50, 50, "10000", "10000", "1", "1", 9999999999, adminAddr, "")
	println("[SUCCESS] Minted the only position in range [-50, 50]")
}

func settleSwap(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
	testing.SetRealm(adminRealm)
	if amount0Delta > 0 {
		grc20reg.Transfer(0, cur, barPath, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		grc20reg.Transfer(0, cur, bazPath, poolAddr, amount1Delta)
	}
	return nil
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
// [SCENARIO] Pool ExactOut returns from terminal ticks without full-range liquidity
//
// [STEP 1] Initialize pool with a single narrow position
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool at tick 0
// [SUCCESS] Minted the only position in range [-50, 50]
// [STEP 2] Move the pool to the lower terminal tick
// [ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=100000
// [RESULT] Forward swap: amount0=10028 amount1=-9999
// [EXPECTED] Tick after lower terminal: -887272
//
// [STEP 3] Recover from the lower terminal tick with ExactOut
// [ACTION] Request 1000 bar by calling Pool.Swap directly
// [RESULT] Recovery swap: amount0=-1000 amount1=997
// [EXPECTED] Tick after lower ExactOut reverse: -46
// [SUCCESS] Returned to the active [-50, 50] range
//
// [STEP 4] Move the pool to the upper terminal tick
// [ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=100000
// [RESULT] Forward swap: amount0=-19024 amount1=19034
// [EXPECTED] Tick after upper terminal: 887271
//
// [STEP 5] Recover from the upper terminal tick with ExactOut
// [ACTION] Request 1000 baz by calling Pool.Swap directly
// [RESULT] Recovery swap: amount0=997 amount1=-1000
// [EXPECTED] Tick after upper ExactOut reverse: 45
// [SUCCESS] Returned to the active [-50, 50] range
// [RESULT] Pool ExactOut returned from both terminal ticks
