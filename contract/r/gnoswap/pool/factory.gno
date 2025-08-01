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
) (*poolCreateConfig, error) {
	poolInfo := newPoolParams(token0Path, token1Path, fee, sqrtPriceX96, tickSpacing)

	// Validate the sqrtPriceX96 is within valid range before processing
	if err := validateSqrtPriceX96(poolInfo.sqrtPriceX96); err != nil {
		return nil, err
	}

	// check if token0Path == token1Path
	if poolInfo.isSameTokenPath() {
		return nil, makeErrorWithDetails(
			errDuplicateTokenInPool,
			ufmt.Sprintf(
				"expected token0Path(%s) != token1Path(%s)",
				poolInfo.token0Path, poolInfo.token1Path,
			),
		)
	}

	if !poolInfo.isSupportedFee(fee) {
		return nil, makeErrorWithDetails(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		)
	}

	var err error
	poolInfo, err = poolInfo.updateWithWrapping()
	if err != nil {
		return nil, err
	}

	common.MustRegistered(poolInfo.token0Path)
	common.MustRegistered(poolInfo.token1Path)

	if !poolInfo.isInOrder() {
		return nil, makeErrorWithDetails(
			errTokenSortOrder,
			ufmt.Sprintf("expected token0Path(%s) < token1Path(%s)", token0Path, token1Path),
		)
	}

	return poolInfo, nil
}
