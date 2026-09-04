// PKGPATH: gno.land/r/gnoswap/pool/oracle_twap_after_liquidity_exhaustion

package oracle_twap_after_liquidity_exhaustion

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
	"gno.land/r/onbloc/foo"
)

const (
	fee100            uint32 = 100
	maxApprove        int64  = 9223372036854775806
	liquidity                = "10000000000"
	swapAmount               = "60183363"
	windowSeconds     uint32 = 5
	fullWindowSeconds uint32 = 15
	maxPrice                 = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	positionRealm   = testing.NewUserRealm(positionAddr)
	routerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
)

func main(cur realm) {
	println("[SCENARIO] TWAP after liquidity exhaustion reaches the upper price boundary")
	println("[SCENARIO] 1. Create a limit position over ticks [0, 120]")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, pool.GetPoolCreationFee())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)
	pool.CreatePool(cross(cur), barPath, fooPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	pool.IncreaseObservationCardinalityNext(cross(cur), barPath, fooPath, fee100, 2)

	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, fooPath, fee100, 0, 120, liquidity, adminAddr)
	poolPath := pool.GetPoolPath(barPath, fooPath, fee100)
	p, _ := pool.GetPools().Get(poolPath).(*pool.Pool)
	println("[INFO] Initial tick:", p.Slot0Tick())
	println("[INFO] Initial active liquidity:", p.Liquidity().ToString())

	println("[SCENARIO] 2. Record a pre-exhaustion observation at tick 0")
	testing.SkipHeights(1)
	println("[INFO] Elapsed seconds before swap:", windowSeconds)
	println()

	println("[SCENARIO] 3. Exhaust the limit position and reach the price boundary")
	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross(cur), barPath, fooPath, fee100, adminAddr, false, swapAmount, maxPrice,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			testing.SetRealm(adminRealm)
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(0, cur, barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(0, cur, fooPath, poolAddr, amount1Delta)
			}
			return nil
		},
	)
	if amount0 != "-59817377" || amount1 != "60183362" {
		panic("unexpected limit-exhaustion swap amounts")
	}
	println("[INFO] Swap amounts:", amount0, amount1)

	p, _ = pool.GetPools().Get(poolPath).(*pool.Pool)
	if p.Slot0Tick() != 887271 || !p.Liquidity().IsZero() {
		panic("expected the exhausted pool at the upper price boundary")
	}
	println("[INFO] Tick after exhaustion:", p.Slot0Tick())
	println("[INFO] Active liquidity after exhaustion:", p.Liquidity().ToString())
	println()

	println("[SCENARIO] 4. Consult TWAP after ten seconds at the upper boundary")
	testing.SkipHeights(2)
	recentTick, _, err := pool.OracleConsult(poolPath, windowSeconds)
	if err != nil {
		panic(err)
	}
	fullTick, _, err := pool.OracleConsult(poolPath, fullWindowSeconds)
	if err != nil {
		panic(err)
	}
	if recentTick != 887271 || fullTick != 591514 {
		panic("unexpected TWAP after liquidity exhaustion")
	}

	println("[INFO] Slot tick after exhaustion:", p.Slot0Tick())
	println("[INFO] TWAP for final 5 seconds:", recentTick)
	println("[INFO] TWAP across all 15 seconds:", fullTick)
	println("[RESULT] Oracle records the upper-boundary tick after liquidity exhaustion")
}

// Output:
// [SCENARIO] TWAP after liquidity exhaustion reaches the upper price boundary
// [SCENARIO] 1. Create a limit position over ticks [0, 120]
// [INFO] Initial tick: 0
// [INFO] Initial active liquidity: 10000000000
// [SCENARIO] 2. Record a pre-exhaustion observation at tick 0
// [INFO] Elapsed seconds before swap: 5
//
// [SCENARIO] 3. Exhaust the limit position and reach the price boundary
// [INFO] Swap amounts: -59817377 60183362
// [INFO] Tick after exhaustion: 887271
// [INFO] Active liquidity after exhaustion: 0
//
// [SCENARIO] 4. Consult TWAP after ten seconds at the upper boundary
// [INFO] Slot tick after exhaustion: 887271
// [INFO] TWAP for final 5 seconds: 887271
// [INFO] TWAP across all 15 seconds: 591514
// [RESULT] Oracle records the upper-boundary tick after liquidity exhaustion
