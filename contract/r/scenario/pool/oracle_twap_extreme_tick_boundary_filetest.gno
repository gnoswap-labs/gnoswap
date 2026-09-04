// PKGPATH: gno.land/r/gnoswap/pool/oracle_twap_extreme_tick_boundary

package oracle_twap_extreme_tick_boundary

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
	_ "gno.land/r/onbloc/foo"
	_ "gno.land/r/onbloc/qux"
)

const (
	fee500          uint32 = 500
	windowSeconds   uint32 = 5
	poolCreationFee int64  = 100_000_000

	minSqrtRatio = "4295128739"
	maxSqrtRatio = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	bazPath = "gno.land/r/onbloc/baz.BAZ"
	quxPath = "gno.land/r/onbloc/qux.QUX"
)

func main(cur realm) {
	println("[SCENARIO] TWAP at extreme valid tick boundaries")

	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, poolCreationFee)
	pool.CreatePool(cross(cur), barPath, fooPath, fee500, minSqrtRatio)

	gns.Approve(cross(cur), poolAddr, poolCreationFee)
	pool.CreatePool(cross(cur), bazPath, quxPath, fee500, maxSqrtRatio)

	// Two five-second blocks ensure the observation window is fully available.
	testing.SkipHeights(2)

	minPoolPath := pool.GetPoolPath(barPath, fooPath, fee500)
	minTick, minLiquidity, err := pool.OracleConsult(minPoolPath, windowSeconds)
	if err != nil {
		panic(err)
	}
	if minTick != -887272 || minLiquidity != "0" {
		panic("unexpected minimum-boundary TWAP")
	}

	maxPoolPath := pool.GetPoolPath(bazPath, quxPath, fee500)
	maxTick, maxLiquidity, err := pool.OracleConsult(maxPoolPath, windowSeconds)
	if err != nil {
		panic(err)
	}
	if maxTick != 887271 || maxLiquidity != "0" {
		panic("unexpected maximum-boundary TWAP")
	}

	println("[INFO] Minimum valid tick TWAP:", minTick, "liquidity:", minLiquidity)
	println("[INFO] Maximum valid tick TWAP:", maxTick, "liquidity:", maxLiquidity)
	println("[RESULT] TWAP preserves both extreme valid ticks")
}

// Output:
// [SCENARIO] TWAP at extreme valid tick boundaries
// [INFO] Minimum valid tick TWAP: -887272 liquidity: 0
// [INFO] Maximum valid tick TWAP: 887271 liquidity: 0
// [RESULT] TWAP preserves both extreme valid ticks
