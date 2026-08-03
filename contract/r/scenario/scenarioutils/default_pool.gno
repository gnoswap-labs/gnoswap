package scenarioutils

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
)

const (
	DefaultPoolToken0Path = "gno.land/r/gnoland/wugnot.wugnot"
	DefaultPoolToken1Path = "gno.land/r/gnoswap/gns.GNS"
	DefaultPoolFee        = uint32(3000)
)

func EnsureCanonicalDefaultPool(cur realm) {
	poolPath := pool.GetPoolPath(DefaultPoolToken0Path, DefaultPoolToken1Path, DefaultPoolFee)
	if pool.ExistsPoolPath(poolPath) {
		return
	}

	adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.SetPoolCreationFee(cross(cur), 0)
	pool.CreatePool(
		cross(cur),
		DefaultPoolToken0Path,
		DefaultPoolToken1Path,
		DefaultPoolFee,
		gnsmath.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}
