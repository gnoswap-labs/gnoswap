// position increase decrease test

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"

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

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/scenario/metric"
)

const MIN_PRICE string = "4295128740"

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)
	poolAddr   = access.MustGetAddress(prbac.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500 uint32 = 500
)

func main() {
	initPool()
	mintInitialPosition()
	executeSwap()
	decreasePositionLiquidity()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee500,
		"130621891405341611593710811006",
	)
}

func mintInitialPosition() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	_, _, _, _ = position.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		8000,
		12000,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
		adminAddr,
		adminAddr,
		"",
	)
}

func increasePositionLiquidity() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 18394892)
	foo.Approve(cross, poolAddr, 50000000)

	_, _, _, _, _ = position.IncreaseLiquidity(
		cross,
		1,
		"50000000",
		"50000000",
		"0",
		"0",
		9999999999,
	)
}

func executeSwap() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 20000000)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	_, _ = pool.Swap(
		cross,
		barPath,
		fooPath,
		fee500,
		adminAddr,
		true,
		"20000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)
}

func decreasePositionLiquidity() {
	testing.SetRealm(adminRealm)

	bar.Approve(cross, poolAddr, 100000000)
	foo.Approve(cross, poolAddr, 100000000)

	_, _, _, _, _, _ = position.CollectFee(cross, 1, false)

	metric.PrintMetricsBy("Position Decrease Liquidity", func() {
		_, _, _, _, _, _, _ = position.DecreaseLiquidity(
			cross,
			1,
			"100000000",
			"0",
			"0",
			9999999999,
			false,
		)
	})
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}
