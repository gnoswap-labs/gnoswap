// PKGPATH: gno.land/r/gnoswap/pool/swap_cross_into_inactive_liquidity

package swap_cross_into_inactive_liquidity

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/demo/defi/grc20reg"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee500      uint32 = 500
	maxApprove  int64  = 9223372036854775806
	positionLiq        = "1000000000"
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
	println("[SCENARIO] Swap crosses into an initially inactive liquidity range")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	pool.CreatePool(cross(cur), barPath, bazPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	// This position exists, but is not active while the pool is at tick 0.
	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, bazPath, fee500, 100, 200, positionLiq, adminAddr)

	poolPath := pool.GetPoolPath(barPath, bazPath, fee500)
	p, _ := pool.GetPools().Get(poolPath).(*pool.Pool)
	if !p.Liquidity().IsZero() {
		panic("expected zero active liquidity before crossing tick 100")
	}
	println("[INFO] Active liquidity before swap: 0")

	// DrySwap must traverse the same inactive interval without changing pool state.
	dryAmount0, dryAmount1, dryErr := pool.DrySwap(
		barPath,
		bazPath,
		fee500,
		false,
		"6000000",
		gnsmath.TickMathGetSqrtRatioAtTick(150).ToString(),
	)
	if dryErr != nil || dryAmount0 == "0" || dryAmount1 == "0" {
		panic("expected DrySwap to quote the reachable inactive range")
	}
	println("[INFO] DrySwap amounts:", dryAmount0, dryAmount1)

	// BAZ is token1, so this oneForZero swap moves the price upward into [100, 200).
	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		bazPath,
		fee500,
		adminAddr,
		false,
		"6000000",
		gnsmath.TickMathGetSqrtRatioAtTick(150).ToString(),
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			testing.SetRealm(adminRealm)
			if amount0Delta > 0 {
				grc20reg.Transfer(0, cur, barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				grc20reg.Transfer(0, cur, bazPath, poolAddr, amount1Delta)
			}
			return nil
		},
	)

	p, _ = pool.GetPools().Get(poolPath).(*pool.Pool)
	if amount0 == "0" || amount1 == "0" {
		panic("expected non-zero swap amounts after entering the range")
	}
	if amount0 != dryAmount0 || amount1 != dryAmount1 {
		panic("expected DrySwap and Swap amounts to match")
	}
	if p.Slot0Tick() < 100 || p.Slot0Tick() >= 200 {
		panic("expected the swap to finish inside the [100, 200) range")
	}
	if p.Liquidity().IsZero() {
		panic("expected liquidity to become active after crossing tick 100")
	}

	println("[INFO] Swap amounts:", amount0, amount1)
	println("[INFO] Tick after swap:", p.Slot0Tick())
	println("[INFO] Active liquidity after swap:", p.Liquidity().ToString())
	println("[RESULT] Successfully crossed into inactive liquidity")
}

// Output:
// [SCENARIO] Swap crosses into an initially inactive liquidity range
// [INFO] Active liquidity before swap: 0
// [INFO] DrySwap amounts: -2484300 2516808
// [INFO] Swap amounts: -2484300 2516808
// [INFO] Tick after swap: 150
// [INFO] Active liquidity after swap: 1000000000
// [RESULT] Successfully crossed into inactive liquidity
