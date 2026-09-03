// PKGPATH: gno.land/r/gnoswap/router/dryswap_cross_into_inactive_liquidity

package dryswap_cross_into_inactive_liquidity

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/router/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	fee500      uint32 = 500
	maxApprove  int64  = 9223372036854775806
	positionLiq        = "1000000000"
	amountIn           = "6000000"
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	positionRealm   = testing.NewUserRealm(positionAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
	route   = "gno.land/r/onbloc/baz.BAZ:gno.land/r/onbloc/bar.BAR:500"
)

func main(cur realm) {
	println("[SCENARIO] Router DrySwap crosses into an initially inactive liquidity range")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), routerAddr, maxApprove)
	pool.CreatePool(cross(cur), barPath, bazPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, bazPath, fee500, 100, 887200, positionLiq, adminAddr)

	poolPath := pool.GetPoolPath(barPath, bazPath, fee500)
	p, _ := pool.GetPools().Get(poolPath).(*pool.Pool)
	if !p.Liquidity().IsZero() {
		panic("expected zero active liquidity before router quote")
	}
	println("[INFO] Active liquidity before quote: 0")

	testing.SetRealm(adminRealm)
	dryIn, dryOut, dryErr := func(cur realm) (string, string, error) {
		return router.DrySwapRoute(
			bazPath, barPath, amountIn, "EXACT_IN", route, "100", "1",
		)
	}(cross(cur))
	if dryErr != nil || dryIn == "0" || dryOut == "0" {
		panic("expected router DrySwapRoute to quote the reachable inactive range")
	}
	println("[INFO] Router DrySwap amounts:", dryIn, dryOut)

	actualIn, actualOut := router.ExactInSwapRoute(
		cross(cur), bazPath, barPath, amountIn, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)
	if actualIn != dryIn || actualOut != dryOut {
		panic("expected router DrySwapRoute and ExactInSwapRoute amounts to match")
	}

	p, _ = pool.GetPools().Get(poolPath).(*pool.Pool)
	if p.Slot0Tick() < 100 || p.Liquidity().IsZero() {
		panic("expected router swap to enter and activate the [100, 887200) range")
	}
	println("[INFO] Router Swap amounts:", actualIn, actualOut)
	println("[INFO] Tick after router swap:", p.Slot0Tick())
	println("[RESULT] Router quote and swap crossed into inactive liquidity")
}

// Output:
// [SCENARIO] Router DrySwap crosses into an initially inactive liquidity range
// [INFO] Active liquidity before quote: 0
// [INFO] Router DrySwap amounts: 6000000 5893260
// [INFO] Router Swap amounts: 6000000 5893260
// [INFO] Tick after router swap: 218
// [RESULT] Router quote and swap crossed into inactive liquidity
