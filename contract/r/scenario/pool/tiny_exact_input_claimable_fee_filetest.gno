// PKGPATH: gno.land/r/gnoswap/pool/tiny_exact_input_claimable_fee

package tiny_exact_input_claimable_fee

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee500      uint32 = 500
	maxApprove  int64  = 9223372036854775806
	positionLiq        = "1"
	tinyExactIn        = "1"
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	positionRealm   = testing.NewUserRealm(positionAddr)
	routerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
)

func main(cur realm) {
	println("[SCENARIO] A tiny exact-input fee becomes claimable after an empty-range cross")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	pool.CreatePool(cross(cur), barPath, bazPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	// The only LP becomes active when the swap crosses tick 100.
	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, bazPath, fee500, 100, 200, positionLiq, adminAddr)

	poolPath := pool.GetPoolPath(barPath, bazPath, fee500)
	p, _ := pool.GetPools().Get(poolPath).(*pool.Pool)
	if !p.Liquidity().IsZero() {
		panic("expected zero active liquidity before the swap")
	}

	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross(cur), barPath, bazPath, fee500, adminAddr, false, tinyExactIn,
		gnsmath.TickMathGetSqrtRatioAtTick(150).ToString(),
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			testing.SetRealm(adminRealm)
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(0, cur, barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(0, cur, bazPath, poolAddr, amount1Delta)
			}
			return nil
		},
	)

	p, _ = pool.GetPools().Get(poolPath).(*pool.Pool)
	if amount0 != "0" || amount1 != tinyExactIn {
		panic("expected the one-unit input to be charged with no output")
	}
	if p.Slot0Tick() != 100 || p.Liquidity().ToString() != positionLiq {
		panic("expected tick 100 to activate the LP")
	}
	if p.FeeGrowthGlobal1X128().IsZero() {
		panic("expected the fee to be recorded for active liquidity")
	}

	// Zero burn realizes the position's fee-growth entitlement before collection.
	testing.SetRealm(positionRealm)
	pool.Burn(cross(cur), barPath, bazPath, fee500, 100, 200, "0", adminAddr)
	collected0, collected1 := pool.Collect(
		cross(cur), barPath, bazPath, fee500, adminAddr, 100, 200, "1", "1",
	)
	if collected0 != "0" || collected1 != "1" {
		panic("expected the activated LP to collect the one-unit fee")
	}

	println("[INFO] Swap amounts:", amount0, amount1)
	println("[INFO] Tick after swap:", p.Slot0Tick())
	println("[INFO] Collected LP fees:", collected0, collected1)
	println("[RESULT] The crossed LP collected the one-unit fee")
}

// Output:
// [SCENARIO] A tiny exact-input fee becomes claimable after an empty-range cross
// [INFO] Swap amounts: 0 1
// [INFO] Tick after swap: 100
// [INFO] Collected LP fees: 0 1
// [RESULT] The crossed LP collected the one-unit fee
