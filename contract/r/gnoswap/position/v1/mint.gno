package v1

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

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
		liquidity,
		feeGrowthInside0LastX128,
		feeGrowthInside1LastX128,
		u256.Zero(),
		u256.Zero(),
		amount0,
		amount1,
		false,
		zeroAddress,
	)

	// The position ID should not exist at the time of minting
	p.mustUpdatePosition(id, *position)
	p.incrementNextId()

	return id, liquidity, amount0, amount1
}

// processMintInput processes and validates user input for minting liquidity.
// It handles token ordering, amount validation, and native token wrapping.
func (p *positionV1) processMintInput(input MintInput) (ProcessedMintInput, error) {
	assertValidNumberString(input.amount0Desired)
	assertValidNumberString(input.amount1Desired)
	assertValidNumberString(input.amount0Min)
	assertValidNumberString(input.amount1Min)

	// process tokens
	token0, token1, token0IsNative, token1IsNative, wrappedAmount, err := p.processTokens(
		input.token0,
		input.token1,
		input.amount0Desired,
		input.amount1Desired,
		input.caller,
	)
	if err != nil {
		return ProcessedMintInput{}, err
	}

	pair := TokenPair{
		token0:         token0,
		token1:         token1,
		token0IsNative: token0IsNative,
		token1IsNative: token1IsNative,
		wrappedAmount:  wrappedAmount,
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
		pair.token0IsNative, pair.token1IsNative = pair.token1IsNative, pair.token0IsNative
	}

	return ProcessedMintInput{
		tokenPair:      pair,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		poolPath:       computePoolPath(pair.token0, pair.token1, input.fee),
	}, nil
}

// processTokens validates token paths and handles native token wrapping.
// Panics if validation fails or native token wrapping encounters issues.
func (p *positionV1) processTokens(
	token0 string,
	token1 string,
	amount0Desired string,
	amount1Desired string,
	caller address,
) (string, string, bool, bool, int64, error) {
	err := validateTokenPath(token0, token1)
	if err != nil {
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	token0IsNative := false
	token1IsNative := false
	wrappedAmount := int64(0)

	if isNative(token0) {
		token0 = WUGNOT_PATH
		token0IsNative = true

		wrappedAmount, _, err = p.wrapNativeTokenIfAllowed(token0, amount0Desired, caller, true)
		if err != nil {
			return "", "", false, false, 0, err
		}
	} else if isNative(token1) {
		token1 = WUGNOT_PATH
		token1IsNative = true

		wrappedAmount, _, err = p.wrapNativeTokenIfAllowed(token1, amount1Desired, caller, true)
		if err != nil {
			return "", "", false, false, 0, err
		}
	}

	return token0, token1, token0IsNative, token1IsNative, wrappedAmount, nil
}

// increaseLiquidity increases the liquidity of an existing position.
func (p *positionV1) increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string, error) {
	caller := params.caller
	position := p.mustGetPosition(params.positionId)

	poolKey := position.PoolKey()
	tickLower := position.TickLower()
	tickUpper := position.TickUpper()

	liquidity, amount0, amount1 := p.addLiquidity(
		AddLiquidityParams{
			poolKey:        poolKey,
			tickLower:      tickLower,
			tickUpper:      tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
			caller:         caller,
		},
	)

	positionKey := computePositionKey(tickLower, tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)

	positionLiquidity := position.Liquidity()
	calculatedToken0Balance, calculatedToken1Balance := calculatePositionBalances(poolKey, tickLower, tickUpper, positionLiquidity)

	feeGrowth := FeeGrowthInside{
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
	}
	tokensOwed0, tokensOwed1 := p.calculateFees(position, feeGrowth)

	liquidityAmount, overflow := u256.Zero().AddOverflow(u256.Zero().Set(positionLiquidity), liquidity)
	if overflow {
		return 0, nil, nil, nil, "", errOverflow
	}
	token0Balance, overflow := u256.Zero().AddOverflow(u256.Zero().Set(calculatedToken0Balance), amount0)
	if overflow {
		return 0, nil, nil, nil, "", errOverflow
	}
	token1Balance, overflow := u256.Zero().AddOverflow(u256.Zero().Set(calculatedToken1Balance), amount1)
	if overflow {
		return 0, nil, nil, nil, "", errOverflow
	}

	position.SetTokensOwed0(tokensOwed0)
	position.SetTokensOwed1(tokensOwed1)

	position.SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128)
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128)

	position.SetLiquidity(liquidityAmount)
	position.SetToken0Balance(token0Balance)
	position.SetToken1Balance(token1Balance)
	position.SetBurned(false)

	err := p.setPosition(params.positionId, *position)
	if err != nil {
		return 0, nil, nil, nil, "", makeErrorWithDetails(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not increase liquidity for non-existent position(%d)", params.positionId),
		)
	}

	return params.positionId, liquidity, amount0, amount1, poolKey, nil
}

// validateTokenPath validates token paths are not identical, not conflicting, and in valid format.
func validateTokenPath(token0, token1 string) error {
	if token0 == token1 {
		return errInvalidTokenPath
	}
	if (token0 == common.GNOT_DENOM && token1 == WUGNOT_PATH) ||
		(token0 == WUGNOT_PATH && token1 == common.GNOT_DENOM) {
		return errInvalidTokenPath
	}
	if (!isNative(token0) && !isValidTokenPath(token0)) ||
		(!isNative(token1) && !isValidTokenPath(token1)) {
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

// computePoolPath returns the pool path based on token pair and fee tier.
func computePoolPath(token0, token1 string, fee uint32) string {
	return pl.GetPoolPath(token0, token1, fee)
}
