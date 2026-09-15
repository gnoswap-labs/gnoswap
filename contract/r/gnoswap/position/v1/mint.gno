package position

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
)

// mint creates a new liquidity position by adding liquidity to a pool and minting an NFT.
// Panics if position ID already exists or adding liquidity fails.
//
// Parameters:
//   - _: leading realm-call discriminator forwarded to nested position, pool, and NFT operations; callers pass 0
//   - rlm: propagated realm context used by nested calls, which cross with cross(rlm)
//   - params: mint request containing token pair, fee tier, tick range, desired and minimum amounts, recipient, and caller
//
// Returns:
//   - positionId: newly allocated position NFT ID
//   - liquidity: liquidity minted for the new position
//   - amount0: token0 amount actually deposited into the pool
//   - amount1: token1 amount actually deposited into the pool
func (p *positionV1) mint(_ int, rlm realm, params MintParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint) {
	poolKey := pl.GetPoolPath(params.token0, params.token1, params.fee)
	liquidity, amount0, amount1 := p.addLiquidity(
		0,
		rlm,
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

	p.nftAccessor.Mint(0, rlm, params.mintTo, positionIdFrom(id))

	positionKey := computePositionKey(params.tickLower, params.tickUpper)
	feeGrowthInside0LastX128, feeGrowthInside1LastX128, err := pl.GetPositionFeeGrowthInsideLastX128(poolKey, positionKey)
	if err != nil {
		panic(err)
	}

	position := position.NewPosition(
		poolKey,
		params.tickLower,
		params.tickUpper,
		liquidity.ToString(),
		feeGrowthInside0LastX128,
		feeGrowthInside1LastX128,
		0,
		0,
		false,
		zeroAddress,
	)

	// The position ID should not exist at the time of minting
	p.mustUpdatePosition(0, rlm, id, *position)
	p.incrementNextId(0, rlm)

	return id, liquidity, amount0, amount1
}

// processMintInput processes and validates user input for minting liquidity.
// It handles token ordering and amount validation.
//
// Parameters:
//   - input: user-supplied token pair, fee, tick range, decimal amount strings, deadline, recipient, and caller
//
// Returns:
//   - processedInput: normalized token order, parsed amounts, adjusted ticks, and derived pool path
//   - err: nil when token paths are distinct and registered; errInvalidTokenPath when validation fails
func (p *positionV1) processMintInput(input MintInput) (ProcessedMintInput, error) {
	token0, token1 := input.token0, input.token1
	if err := validateTokenPath(token0, token1); err != nil {
		return ProcessedMintInput{}, makeErrorWithDetails(err.Error(), ufmt.Sprintf("token0(%s), token1(%s)", token0, token1))
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
//
// Parameters:
//   - _: leading realm-call discriminator forwarded to nested position and pool operations; callers pass 0
//   - rlm: propagated realm context used by nested calls, which cross with cross(rlm)
//   - params: increase request containing position ID, desired and minimum amounts, deadline, and caller
//
// Returns:
//   - positionId: existing position NFT ID processed
//   - liquidity: liquidity delta added to the position
//   - amount0: token0 amount actually deposited into the pool
//   - amount1: token1 amount actually deposited into the pool
//   - poolPath: pool identifier associated with the position
//   - err: nil on success; non-nil when fee-growth retrieval or the position update fails
func (p *positionV1) increaseLiquidity(_ int, rlm realm, params IncreaseLiquidityParams) (uint64, *u256.Uint, *u256.Uint, *u256.Uint, string, error) {
	caller := params.caller
	position := p.mustGetPosition(params.positionId)

	liquidity, amount0, amount1 := p.addLiquidity(
		0,
		rlm,
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
	feeGrowthInside0LastX128Str, feeGrowthInside1LastX128Str, err := pl.GetPositionFeeGrowthInsideLastX128(position.PoolKey(), positionKey)
	if err != nil {
		return 0, nil, nil, nil, "", err
	}

	feeGrowth := FeeGrowthInside{
		feeGrowthInside0LastX128: u256.MustFromDecimal(feeGrowthInside0LastX128Str),
		feeGrowthInside1LastX128: u256.MustFromDecimal(feeGrowthInside1LastX128Str),
	}
	tokensOwed0, tokensOwed1 := p.calculateFees(position, feeGrowth)

	posLiquidity := u256.MustFromDecimal(position.Liquidity())
	liquidityAmount, overflow := u256.Zero().AddOverflow(posLiquidity, liquidity)
	if overflow {
		return 0, nil, nil, nil, "", errors.New(errOverflow)
	}

	position.SetTokensOwed0(tokensOwed0)
	position.SetTokensOwed1(tokensOwed1)

	position.SetFeeGrowthInside0LastX128(feeGrowthInside0LastX128Str)
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1LastX128Str)

	position.SetLiquidity(liquidityAmount.ToString())
	position.SetBurned(false)

	err = p.setPosition(0, rlm, params.positionId, *position)
	if err != nil {
		return 0, nil, nil, nil, "", makeErrorWithDetails(
			errPositionDoesNotExist,
			ufmt.Sprintf("cannot increase liquidity for non-existent position(%d)", params.positionId),
		)
	}

	return params.positionId, liquidity, amount0, amount1, position.PoolKey(), nil
}

// validateTokenPath validates token paths are distinct and registered.
//
// Parameters:
//   - token0: first token contract path to validate
//   - token1: second token contract path to validate
//
// Returns:
//   - err: nil when the paths differ and both are registered; errInvalidTokenPath otherwise
func validateTokenPath(token0, token1 string) error {
	if token0 == token1 {
		return errors.New(errInvalidTokenPath)
	}
	if !isValidTokenPath(token0) || !isValidTokenPath(token1) {
		return errors.New(errInvalidTokenPath)
	}
	return nil
}

// isValidTokenPath reports whether a token path is registered in the common
// token registry.
//
// Parameters:
//   - tokenPath: token contract path to look up in the registry
//
// Returns:
//   - valid: true when common.IsRegistered(tokenPath) succeeds
func isValidTokenPath(tokenPath string) bool {
	return common.IsRegistered(tokenPath) == nil
}

// parseAmounts converts decimal amount strings to uint256 values.
//
// Parameters:
//   - amount0Desired: decimal desired amount of token0
//   - amount1Desired: decimal desired amount of token1
//   - amount0Min: decimal minimum acceptable amount of token0
//   - amount1Min: decimal minimum acceptable amount of token1
//
// Returns:
//   - amount0DesiredUint: parsed token0 desired amount
//   - amount1DesiredUint: parsed token1 desired amount
//   - amount0MinUint: parsed token0 minimum amount
//   - amount1MinUint: parsed token1 minimum amount
//
// Invalid decimal strings panic through u256.MustFromDecimal.
func parseAmounts(amount0Desired, amount1Desired, amount0Min, amount1Min string) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint) {
	return u256.MustFromDecimal(amount0Desired), u256.MustFromDecimal(amount1Desired), u256.MustFromDecimal(amount0Min), u256.MustFromDecimal(amount1Min)
}
