package position

import (
	// @notJoon JSON
	"std"
	"testing"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/foo"

	"gno.land/r/demo/gns"

	i256 "gno.land/p/demo/gnoswap/int256"
)

func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetPrevAddr(test1)
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()
	gns.Faucet()

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE)
	pl.CreatePool(barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(1).ToString())
}

func TestMintPositionFullInRange(t *testing.T) {
	std.TestSetPrevAddr(test1)
	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	tokenId, liquidity, amount0, amount1 := Mint(
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
		test1.String(),
	)
	shouldEQ(t, tokenId, 1)
	shouldEQ(t, getNextId(), 2)

	position := positions[tokenId]

	currentX96 := common.TickMathGetSqrtRatioAtTick(1)
	lowerX96 := common.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperX96 := common.TickMathGetSqrtRatioAtTick(position.tickUpper)

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		i256.FromUint256(position.liquidity),
	)
}
