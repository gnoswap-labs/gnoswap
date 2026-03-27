package v1

import (
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// mint creates a new liquidity position by adding liquidity to a pool and minting an NFT.
// Panics if position ID already exists or adding liquidity fails.
func (p *positionV1) mint(params MintParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint) {
	poolKey := pl.GetPoolPath(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := p.addLiquidity(
		AddLiquidityParams{
			poolKey:        poolKey,
			tickLower:      params.tickLower,
			tickUpper:      params.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
			caller:         params.caller,
		},
	)
	// Ensure liquidity is not zero before minting NFT
	if liquidity.IsZero() {
		panic(newErrorWithDetail(
			errZeroLiquidity,
			"Liquidity is zero, cannot mint position.",
		))
	}

	id := p.getNextId()

	if p.ExistPosition(id) {
		panic(newErrorWithDetail(
			errPositionExist,
			ufmt.Sprintf("positionId(%d)", id),
		))
	}

	p.nftAccessor.Mint(params.mintTo, positionIdFrom(id))

	positionKey := computePositionKey(params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(poolKey, positionKey)

	position := position.NewPosition(
		poolKey,
		params.tickLower,
		params.tickUpper,
		liquidity.ToString(),
		feeGrowthInside0LastX128,
		feeGrowthInside1LastX128,
		0,
		0,
		safeConvertToInt64(amount0),
		safeConvertToInt64(amount1),
		false,
		zeroAddress,
	)

	// The position ID should not exist at the time of minting
	p.mustUpdatePosition(id, *position)
	p.incrementNextId()

	return id, liquidity, amount0, amount1
}

// processMintInput processes and validates user input for minting liquidity.
// It handles token ordering and amount validation.
func (p *positionV1) processMintInput(input MintInput) (ProcessedMintInput, error) {
	token0, token1 := input.token0, input.token1
	if err := validateTokenPath(token0, token1); err != nil {
		return ProcessedMintInput{}, makeErrorWithDetails(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1))
	}

	pair := TokenPair{
		token0: token0,
		token1: token1,
	}

	// parse amounts
	amount0Desired, amount1Desired, amount0Min, amount1Min := parseAmounts(input.amount0Desired, input.amount1Desired, input.amount0Min, input.amount1Min)

	tickLower, tickUpper := input.tickLower, input.tickUpper

	// swap if token1 < token0
	if token1 < token0 {
		pair.token0, pair.token1 = pair.token1, pair.token0
		amount0Desired, amount1Desired = amount1Desired, amount0Desired
		amount0Min, amount1Min = amount1Min, amount0Min
		tickLower, tickUpper = -tickUpper, -tickLower
	}

	return ProcessedMintInput{
		tokenPair:      pair,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		poolPath:       pl.GetPoolPath(pair.token0, pair.token1, input.fee),
	}, nil
}

// increaseLiquidity increases the liquidity of an existing position.
func (p *positionV1) increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string, error) {
	caller := params.caller
	position := p.mustGetPosition(params.positionId)

	liquidity, amount0, amount1 := p.addLiquidity(
		AddLiquidityParams{
			poolKey:        position.PoolKey(),
			tickLower:      position.TickLower(),
			tickUpper:      position.TickUpper(),
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
			caller:         caller,
		},
	)

	positionKey := computePositionKey(position.TickLower(), position.TickUpper())
	feeGrowthInside0LastX128Str, feeGrowthInside1LastX128Str := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	calculatedToken0Balance, calculatedToken1Balance := calculatePositionBalances(position)

	feeGrowth := FeeGrowthInside{
		feeGrowthInside0LastX128: u256.MustFromDecimal(feeGrowthInside0LastX128Str),
		feeGrowthInside1LastX128: u256.MustFromDecimal(feeGrowthInside1LastX128Str),
	}
	tokensOwed0, tokensOwed1 := p.calculateFees(position, feeGrowth)

	posLiquidity := u256.MustFromDecimal(position.Liquidity())
	liquidityAmount, overflow := u256.Zero().AddOverflow(posLiquidity, liquidity)
	if overflow {
		return 0, nil, nil, nil, "", errOverflow
	}
	token0Balance := safeAddInt64(calculatedToken0Balance, safeConvertToInt64(amount0))
	token1Balance := safeAddInt64(calculatedToken1Balance, safeConvertToInt64(amount1))

	position.SetTokensOwed0(tokensOwed0)
	position.SetTokensOwed1(tokensOwed1)

	position.SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128Str)
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128Str)

	position.SetLiquidity(liquidityAmount.ToString())
	position.SetToken0Balance(token0Balance)
	position.SetToken1Balance(token1Balance)
	position.SetBurned(false)

	err := p.setPosition(params.positionId, *position)
	if err != nil {
		return 0, nil, nil, nil, "", makeErrorWithDetails(
			errPositionDoesNotExist,
			ufmt.Sprintf("cannot increase liquidity for non-existent position(%d)", params.positionId),
		)
	}

	return params.positionId, liquidity, amount0, amount1, position.PoolKey(), nil
}

// validateTokenPath validates token paths are not identical, not conflicting, and in valid format.
func validateTokenPath(token0, token1 string) error {
	if token0 == token1 {
		return errInvalidTokenPath
	}
	if !isValidTokenPath(token0) || !isValidTokenPath(token1) {
		return errInvalidTokenPath
	}
	return nil
}

// isValidTokenPath checks if the token path is registered in the system.
func isValidTokenPath(tokenPath string) bool {
	return common.IsRegistered(tokenPath) == nil
}

// parseAmounts converts amount strings to u256.Uint values.
func parseAmounts(amount0Desired, amount1Desired, amount0Min, amount1Min string) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint) {
	return u256.MustFromDecimal(amount0Desired), u256.MustFromDecimal(amount1Desired), u256.MustFromDecimal(amount0Min), u256.MustFromDecimal(amount1Min)
}
