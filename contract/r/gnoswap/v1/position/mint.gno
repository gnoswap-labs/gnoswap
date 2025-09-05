package position

import (
	"std"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gnft"
	pl "gno.land/r/gnoswap/v1/pool"
)

const (
	WRAPPED_WUGNOT string = "gno.land/r/gnoland/wugnot"
	UGNOT          string = "ugnot"
	GNOT           string = "gnot"
)

// mint creates a new liquidity position by adding liquidity to a pool and minting an NFT.
// Panics if position ID already exists or adding liquidity fails.
func mint(params MintParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint) {
	poolKey := pl.GetPoolPath(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := addLiquidity(
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

	id := GetNextId()
	if ExistPosition(id) {
		panic(newErrorWithDetail(
			errPositionExist,
			ufmt.Sprintf("positionId(%d)", id),
		))
	}

	gnft.Mint(cross, params.mintTo, positionIdFrom(id))

	positionKey := computePositionKey(params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(poolKey, positionKey)

	position := Position{
		nonce:                    u256.Zero(),
		operator:                 zeroAddress,
		poolKey:                  poolKey,
		tickLower:                params.tickLower,
		tickUpper:                params.tickUpper,
		liquidity:                liquidity,
		feeGrowthInside0LastX128: feeGrowthInside0LastX128,
		feeGrowthInside1LastX128: feeGrowthInside1LastX128,
		tokensOwed0:              u256.Zero(),
		tokensOwed1:              u256.Zero(),
		token0Balance:            amount0,
		token1Balance:            amount1,
		burned:                   false,
	}

	// The position ID should not exist at the time of minting
	updated := setPosition(id, position)
	if updated {
		panic(newErrorWithDetail(
			errPositionExist,
			ufmt.Sprintf("position ID(%d) already exists", id),
		))
	}
	incrementNextId()

	return id, liquidity, amount0, amount1
}

// processMintInput processes and validates user input for minting liquidity.
// It handles token ordering, amount validation, and native token wrapping.
func processMintInput(input MintInput) (ProcessedMintInput, error) {
	assertValidNumberString(input.amount0Desired)
	assertValidNumberString(input.amount1Desired)
	assertValidNumberString(input.amount0Min)
	assertValidNumberString(input.amount1Min)
	var result ProcessedMintInput

	// process tokens
	token0, token1, token0IsNative, token1IsNative, wrappedAmount, err := processTokens(
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

	poolPath := computePoolPath(pair.token0, pair.token1, input.fee)

	result = ProcessedMintInput{
		tokenPair:      pair,
		amount0Desired: amount0Desired,
		amount1Desired: amount1Desired,
		amount0Min:     amount0Min,
		amount1Min:     amount1Min,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		poolPath:       poolPath,
	}

	return result, nil
}

// processTokens validates token paths and handles native token wrapping.
// Panics if validation fails or native token wrapping encounters issues.
func processTokens(
	token0 string,
	token1 string,
	amount0Desired string,
	amount1Desired string,
	caller std.Address,
) (string, string, bool, bool, int64, error) {
	err := validateTokenPath(token0, token1)
	if err != nil {
		panic(newErrorWithDetail(err, ufmt.Sprintf("token0(%s), token1(%s)", token0, token1)))
	}

	token0IsNative := false
	token1IsNative := false
	wrappedAmount := int64(0)

	if isNative(token0) {
		token0 = WRAPPED_WUGNOT
		token0IsNative = true

		amount0DesiredInt := mustParseInt64(amount0Desired)
		wrappedAmount, err = safeWrapNativeToken(amount0DesiredInt, caller)
		if err != nil {
			return "", "", false, false, 0, err
		}
	} else if isNative(token1) {
		token1 = WRAPPED_WUGNOT
		token1IsNative = true

		amount1DesiredInt := mustParseInt64(amount1Desired)
		wrappedAmount, err = safeWrapNativeToken(amount1DesiredInt, caller)
		if err != nil {
			return "", "", false, false, 0, err
		}
	}

	return token0, token1, token0IsNative, token1IsNative, wrappedAmount, nil
}

// increaseLiquidity increases the liquidity of an existing position.
func increaseLiquidity(params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string, error) {
	caller := params.caller
	position, exist := GetPosition(params.positionId)
	if !exist {
		return 0, nil, nil, nil, "", makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) doesn't exist", params.positionId),
		)
	}

	liquidity, amount0, amount1 := addLiquidity(
		AddLiquidityParams{
			poolKey:        position.poolKey,
			tickLower:      position.tickLower,
			tickUpper:      position.tickUpper,
			amount0Desired: params.amount0Desired,
			amount1Desired: params.amount1Desired,
			amount0Min:     params.amount0Min,
			amount1Min:     params.amount1Min,
			caller:         caller,
		},
	)

	positionKey := computePositionKey(position.tickLower, position.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128 := pl.GetPositionFeeGrowthInsideLastX128(position.poolKey, positionKey)

	currentSqrtPriceX96 := pl.GetSlot0SqrtPriceX96(position.poolKey)
	lowerTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperTickSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(position.tickUpper)
	calculatedToken0BalanceStr, calculatedToken1BalanceStr := common.GetAmountsForLiquidity(
		currentSqrtPriceX96,
		lowerTickSqrtPriceX96,
		upperTickSqrtPriceX96,
		position.liquidity,
	)
	calculatedToken0Balance := u256.MustFromDecimal(calculatedToken0BalanceStr)
	calculatedToken1Balance := u256.MustFromDecimal(calculatedToken1BalanceStr)

	{
		diff := u256.Zero().Sub(feeGrowthInside0LastX128, position.feeGrowthInside0LastX128)
		mulDiv := u256.MulDiv(diff, u256.Zero().Set(position.liquidity), u256.MustFromDecimal(Q128))

		position.tokensOwed0 = u256.Zero().Add(position.tokensOwed0, mulDiv)
	}

	{
		diff := u256.Zero().Sub(feeGrowthInside1LastX128, position.feeGrowthInside1LastX128)
		mulDiv := u256.MulDiv(diff, u256.Zero().Set(position.liquidity), u256.MustFromDecimal(Q128))

		position.tokensOwed1 = u256.Zero().Add(position.tokensOwed1, mulDiv)
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128
	position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128

	liquidityAmount, overflow := u256.Zero().AddOverflow(u256.Zero().Set(position.liquidity), liquidity)
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

	position.liquidity = liquidityAmount
	position.token0Balance = token0Balance
	position.token1Balance = token1Balance
	position.burned = false

	updated := setPosition(params.positionId, position)
	if !updated {
		return 0, nil, nil, nil, "", makeErrorWithDetails(
			errPositionDoesNotExist,
			ufmt.Sprintf("can not increase liquidity for non-existent position(%d)", params.positionId),
		)
	}

	return params.positionId, liquidity, amount0, amount1, position.poolKey, nil
}

// validateTokenPath validates token paths are not identical, not conflicting, and in valid format.
func validateTokenPath(token0, token1 string) error {
	if token0 == token1 {
		return errInvalidTokenPath
	}
	if (token0 == GNOT && token1 == WRAPPED_WUGNOT) ||
		(token0 == WRAPPED_WUGNOT && token1 == GNOT) {
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
