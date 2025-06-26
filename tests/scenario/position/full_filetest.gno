package main

import (
	"std"
	"testing"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/gnoswap/v1/gns"
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	poolAddr     = consts.POOL_ADDR
)

var (
	fee500 uint32 = 500

	max_timeout int64 = 9999
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
)

func main() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	poolInitCreatePool()
	mintPositionFullInRange()
	increaseLiquidity()
	decreaseLiquidity()
	collectFee()
}

func poolInitCreatePool() {
	testing.SetRealm(adminRealm)

	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(1).ToString())
}

func mintPositionFullInRange() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-887270,
		887270,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	println("positionId", positionId)
	println("liquidity", liquidity)
	println("amount0", amount0)
	println("amount1", amount1)
}

func increaseLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	positionId, liquidity, amount0, amount1, poolPath := pn.IncreaseLiquidity(
		cross,
		uint64(1),
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
	)

	println("positionId", positionId)
	println("liquidity", liquidity)
	println("amount0", amount0)
	println("amount1", amount1)
	println("poolPath", poolPath)
}

func decreaseLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	positionId, liquidity, fee0, fee1, amount0, amount1, poolPath := pn.DecreaseLiquidity(
		cross,
		uint64(1),
		"50",
		"0",
		"0",
		max_timeout,
		false,
	)

	println("positionId", positionId)
	println("liquidity", liquidity)
	println("fee0", fee0)
	println("fee1", fee1)
	println("amount0", amount0)
	println("amount1", amount1)
	println("poolPath", poolPath)
}

func collectFee() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxApprove)
	foo.Approve(cross, poolAddr, maxApprove)

	positionId, fee0, fee1, poolPath, _, _ := pn.CollectFee(cross, uint64(1), false)

	println("positionId", positionId)
	println("fee0", fee0)
	println("fee1", fee1)
	println("poolPath", poolPath)
}
