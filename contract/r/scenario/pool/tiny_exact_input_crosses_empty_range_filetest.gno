// PKGPATH: gno.land/r/gnoswap/pool/tiny_exact_input_crosses_empty_range

package tiny_exact_input_crosses_empty_range

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
	fee500       uint32 = 500
	maxApprove   int64  = 9223372036854775806
	positionLiq         = "1000000000"
	tinyExactIn         = "1"
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
	println("[SCENARIO] A one-unit exact-input swap crosses an empty range")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	pool.CreatePool(cross(cur), barPath, bazPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	// The pool starts with no active liquidity. Crossing tick 100 activates this position.
	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, bazPath, fee500, 100, 200, positionLiq, adminAddr)

	poolPath := pool.GetPoolPath(barPath, bazPath, fee500)
	p, _ := pool.GetPools().Get(poolPath).(*pool.Pool)
	if !p.Liquidity().IsZero() {
		panic("expected zero active liquidity before the swap")
	}
	println("[INFO] Active liquidity before swap: 0")

	// Uniswap V3 moves to tick 100 at zero cost, then charges this one unit as fee
	// after liquidity becomes active. It must not consume the input before the tick cross.
	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		bazPath,
		fee500,
		adminAddr,
		false,
		tinyExactIn,
		gnsmath.TickMathGetSqrtRatioAtTick(150).ToString(),
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			testing.SetRealm(adminRealm)
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(cross(cur), barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(cross(cur), bazPath, poolAddr, amount1Delta)
			}
			return nil
		},
	)

	p, _ = pool.GetPools().Get(poolPath).(*pool.Pool)
	if amount0 != "0" || amount1 != tinyExactIn {
		panic("expected the one-unit input to be charged with no output")
	}
	if p.Slot0Tick() != 100 {
		panic("expected the zero-liquidity step to cross tick 100")
	}
	if p.Liquidity().IsZero() {
		panic("expected liquidity to become active after crossing tick 100")
	}
	if p.FeeGrowthGlobal1X128().IsZero() {
		panic("expected the one-unit fee to be attributed after liquidity becomes active")
	}

	println("[INFO] Swap amounts:", amount0, amount1)
	println("[INFO] Tick after swap:", p.Slot0Tick())
	println("[INFO] Active liquidity after swap:", p.Liquidity().ToString())
	println("[RESULT] One-unit input crossed the empty range before fee attribution")
}

// Output:
// [SCENARIO] A one-unit exact-input swap crosses an empty range
// [INFO] Active liquidity before swap: 0
// [INFO] Swap amounts: 0 1
// [INFO] Tick after swap: 100
// [INFO] Active liquidity after swap: 1000000000
// [RESULT] One-unit input crossed the empty range before fee attribution
