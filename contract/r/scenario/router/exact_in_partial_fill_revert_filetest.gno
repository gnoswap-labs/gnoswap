// PKGPATH: gno.land/r/gnoswap/scenario/router/exact_in_partial_fill_revert

package exact_in_partial_fill_revert

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
	fee        uint32 = 100
	maxApprove int64  = 9223372036854775807
	deadline   int64  = 9999999999
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	barPath      = "gno.land/r/onbloc/bar.BAR"
	bazPath      = "gno.land/r/onbloc/baz.BAZ"
	poolPath     = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	forwardRoute = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"
	reverseRoute = "gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:100"
)

// An exact-in swap must consume its entire requested input. When the pool's
// liquidity runs out before the input is exhausted (a partial fill), the router
// reverts instead of silently settling for the smaller amount. Intentional
// partial fills remain possible by passing an explicit sqrtPriceLimitX96.
func main(cur realm) {
	println("[SCENARIO] Router reverts exact-in partial fills unless a price limit is set")
	println()
	println("[STEP 1] Initialize pool with a single narrow position")
	setup(cur)

	// The single [-50, 50] position cannot absorb input=100000, so the swap
	// would only partially fill. DrySwapRoute must predict the revert without
	// touching any state.
	println()
	println("[STEP 2] Dry-run the unbounded swap that would partially fill")
	println("[ACTION] DrySwapRoute bar -> baz ExactIn with input=100000")
	dryIn, dryOut, dryErr := rt.DrySwapRoute(barPath, bazPath, "100000", "EXACT_IN", forwardRoute, "100", "1")
	if dryErr == nil {
		panic("expected DrySwapRoute to report the partial fill as an error")
	}
	ufmt.Printf("[RESULT] Dry-run rejected: in=%s out=%s err=%v\n", dryIn, dryOut, dryErr)
	assertTick(0, "dry-run")

	println()
	println("[STEP 3] Partial fill is allowed with an explicit price limit")
	println("[ACTION] Execute the same swap with sqrtPriceLimitX96 at the lower terminal")
	limitedIn, limitedOut := rt.ExactInSingleSwapRoute(cross(cur), barPath, bazPath, "100000", forwardRoute, "0", lowerTerminalLimit(), deadline, "")
	ufmt.Printf("[RESULT] Price-limited swap: in=%s out=%s\n", limitedIn, limitedOut)
	assertTick(-887271, "price-limited swap")
	println("[SUCCESS] Explicit price limit opts in to the partial fill")

	println()
	println("[STEP 4] Swap back into the active range")
	println("[ACTION] Execute baz -> bar ExactIn swap with input=1000")
	reverseIn, reverseOut := rt.ExactInSwapRoute(cross(cur), bazPath, barPath, "1000", reverseRoute, "100", "0", deadline, "")
	ufmt.Printf("[RESULT] Recovery swap: in=%s out=%s (fully consumed)\n", reverseIn, reverseOut)

	// Without a price limit the same partial fill must abort the whole
	// transaction. Here the abort is caught with revive for inspection only;
	// on-chain the panic reverts every state change of the swap.
	println()
	println("[STEP 5] The unbounded swap reverts on the partial fill")
	println("[ACTION] Execute bar -> baz ExactIn swap with input=100000 and no price limit")
	r := revive(func() {
		rt.ExactInSwapRoute(cross(cur), barPath, bazPath, "100000", forwardRoute, "100", "0", deadline, "")
	})
	if r == nil {
		panic("expected the unbounded exact-in swap to abort on partial fill")
	}
	ufmt.Printf("[RESULT] Unbounded swap aborted as expected: %v\n", r)

	println("[RESULT] Exact-in swaps settle in full or revert; price limits opt in to partial fills")
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

func assertTick(want int32, label string) {
	got, _ := pl.GetSlot0Tick(poolPath)
	ufmt.Printf("[EXPECTED] Tick after %s: %d\n", label, got)
	if got != want {
		panic(ufmt.Sprintf("expected tick %d after %s, got %d", want, label, got))
	}
}

// Output:
// [SCENARIO] Router reverts exact-in partial fills unless a price limit is set
//
// [STEP 1] Initialize pool with a single narrow position
// [INFO] Set pool creation fee to 0
// [INFO] Create bar:baz:100 pool at tick 0
// [SUCCESS] Minted the only position in range [-50, 50]
//
// [STEP 2] Dry-run the unbounded swap that would partially fill
// [ACTION] DrySwapRoute bar -> baz ExactIn with input=100000
// [RESULT] Dry-run rejected: in=10028 out=9985 err=consumed input does not match requested (requested=100000, consumed=10028)
// [EXPECTED] Tick after dry-run: 0
//
// [STEP 3] Partial fill is allowed with an explicit price limit
// [ACTION] Execute the same swap with sqrtPriceLimitX96 at the lower terminal
// [RESULT] Price-limited swap: in=10028 out=9985
// [EXPECTED] Tick after price-limited swap: -887271
// [SUCCESS] Explicit price limit opts in to the partial fill
//
// [STEP 4] Swap back into the active range
// [ACTION] Execute baz -> bar ExactIn swap with input=1000
// [RESULT] Recovery swap: in=1000 out=1002 (fully consumed)
//
// [STEP 5] The unbounded swap reverts on the partial fill
// [ACTION] Execute bar -> baz ExactIn swap with input=100000 and no price limit
// [RESULT] Unbounded swap aborted as expected: [GNOSWAP-ROUTER-020] insufficient liquidity for swap || consumed input does not match requested (requested=100000, consumed=1005)
// [RESULT] Exact-in swaps settle in full or revert; price limits opt in to partial fills
