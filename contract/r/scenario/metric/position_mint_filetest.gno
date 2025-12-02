// position mint swap burn

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/scenario/metric"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _      = access.GetAddress(prbac.ROLE_ROUTER.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	routerRealm        = testing.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath        = "gno.land/r/onbloc/bar"
	fooPath        = "gno.land/r/onbloc/foo"
	fee500  uint32 = 500
)

func main() {
	initPool()

	mintPosition()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(100000000)

	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintPosition() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	metric.PrintMetricsBy("Position Mint", func() {
		position.Mint(
			cross,
			barPath,
			fooPath,
			fee500,
			-1000,
			1000,
			"50000000",
			"50000000",
			"0",
			"0",
			time.Now().Unix()+3600,
			aliceAddr,
			aliceAddr,
			"",
		)
	})
}
