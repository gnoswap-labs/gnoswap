package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/common"
)

func createPool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
	tickSpacing int32,
) *createPoolParams {
	poolInfo := newPoolParams(token0Path, token1Path, fee, sqrtPriceX96, tickSpacing)
	// check if token0Path == token1Path
	if poolInfo.isSameTokenPath() {
		panic(addDetailToError(
			errDuplicateTokenInPool,
			ufmt.Sprintf(
				"expected token0Path(%s) != token1Path(%s)",
				poolInfo.token0Path, poolInfo.token1Path,
			),
		))
	}
	if !poolInfo.isSupportedFee(fee) {
		panic(addDetailToError(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	poolInfo = poolInfo.updateWithWrapping()

	assertOnlyRegistered(poolInfo.token0Path)
	assertOnlyRegistered(poolInfo.token1Path)

	if !poolInfo.isInOrder() {
		panic(addDetailToError(
			errTokenSortOrder,
			ufmt.Sprintf("expected token0Path(%s) < token1Path(%s)", token0Path, token1Path),
		))
	}
	return poolInfo
}
