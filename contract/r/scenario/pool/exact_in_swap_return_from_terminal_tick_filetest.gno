// PKGPATH: gno.land/r/gnoswap/scenario/pool/swap_return_from_terminal_tick

package swap_return_from_terminal_tick

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

// This drives Pool.Swap directly.  The callback only settles the token owed
// to the pool; no router swap logic participates in the state transition.
func main(cur realm) {
	println("[SCENARIO] Pool returns from terminal tick without full-range liquidity")
	println()
	println("[STEP 1] Initialize pool with a single narrow position")
	setup(cur)

	println("[STEP 2] Move the pool to the lower terminal tick")
	println("[ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=100000")
	testing.SetRealm(routerRealm)
	forward0, forward1 := pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, true, "100000", minPrice, settleSwap)
	ufmt.Printf("[RESULT] Forward swap: amount0=%s amount1=%s\n", forward0, forward1)
	assertTick(-887272, "lower")

	println()
	println("[STEP 3] Recover from the lower terminal tick")
	println("[ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=1000")
	testing.SetRealm(routerRealm)
	reverse0, reverse1 := pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, false, "1000", maxPrice, settleSwap)
	ufmt.Printf("[RESULT] Recovery swap: amount0=%s amount1=%s\n", reverse0, reverse1)
	assertTickInRange(-50, 50, "lower")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println()
	println("[STEP 4] Move the pool to the upper terminal tick")
	println("[ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=100000")
	testing.SetRealm(routerRealm)
	forward0, forward1 = pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, false, "100000", maxPrice, settleSwap)
	ufmt.Printf("[RESULT] Forward swap: amount0=%s amount1=%s\n", forward0, forward1)
	assertTick(887271, "upper")

	println()
	println("[STEP 5] Recover from the upper terminal tick")
	println("[ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=1000")
	testing.SetRealm(routerRealm)
	reverse0, reverse1 = pl.Swap(cross(cur), barPath, bazPath, fee, adminAddr, true, "1000", minPrice, settleSwap)
	ufmt.Printf("[RESULT] Recovery swap: amount0=%s amount1=%s\n", reverse0, reverse1)
	assertTickInRange(-50, 50, "upper")
	println("[SUCCESS] Returned to the active [-50, 50] range")

	println("[RESULT] Pool returned from both terminal ticks to active liquidity")
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

func assertTick(want int32, terminal string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] Tick after %s terminal swap: %d\n", terminal, got)
	if got != want {
		panic(ufmt.Sprintf("expected terminal tick %d, got %d", want, got))
	}
}

func assertTickInRange(lower, upper int32, terminal string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] Tick after %s recovery swap: %d\n", terminal, got)
	if got < lower || got > upper {
		panic(ufmt.Sprintf("expected tick in [%d, %d], got %d", lower, upper, got))
	}
}

// Output:
// [SCENARIO] Pool returns from terminal tick without full-range liquidity
//
// [STEP 1] Initialize pool with a single narrow position
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool at tick 0
// [SUCCESS] Minted the only position in range [-50, 50]
// [STEP 2] Move the pool to the lower terminal tick
// [ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=100000
// [RESULT] Forward swap: amount0=10028 amount1=-9999
// [EXPECTED] Tick after lower terminal swap: -887272
//
// [STEP 3] Recover from the lower terminal tick
// [ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=1000
// [RESULT] Recovery swap: amount0=-1003 amount1=1000
// [EXPECTED] Tick after lower recovery swap: -45
// [SUCCESS] Returned to the active [-50, 50] range
//
// [STEP 4] Move the pool to the upper terminal tick
// [ACTION] Call Pool.Swap directly with baz -> bar ExactIn input=100000
// [RESULT] Forward swap: amount0=-19021 amount1=19030
// [EXPECTED] Tick after upper terminal swap: 887271
//
// [STEP 5] Recover from the upper terminal tick
// [ACTION] Call Pool.Swap directly with bar -> baz ExactIn input=1000
// [RESULT] Recovery swap: amount0=1000 amount1=-1003
// [EXPECTED] Tick after upper recovery swap: 44
// [SUCCESS] Returned to the active [-50, 50] range
// [RESULT] Pool returned from both terminal ticks to active liquidity
