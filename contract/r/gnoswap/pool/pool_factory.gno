package pool

import (
	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
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
	poolInfo = poolInfo.updateWithWrapping()

	if !poolInfo.isInOrder() {
		panic(addDetailToError(
			errTokenSortOrder,
			ufmt.Sprintf("expected token0Path(%s) < token1Path(%s)", token0Path, token1Path),
		))
	}
	return poolInfo
}
