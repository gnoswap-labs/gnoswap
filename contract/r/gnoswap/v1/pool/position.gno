package pool

import (
	"encoding/base64"

	"gno.land/p/nt/ufmt"
	plp "gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
)

const positionPackagePath = "gno.land/r/gnoswap/v1/position"

var convertedQ128 = u256.MustFromDecimal(Q128)

// getPositionKey generates a unique base64-encoded key for a liquidity position.
//
// Creates deterministic identifier for position tracking.
// Ensures unique positions per owner and price range.
// Used internally for position state management.
//
// Parameters:
//   - tickLower: Lower boundary tick of position range
//   - tickUpper: Upper boundary tick of position range
//
// Key Format:
//
//	base64(position_package_path + tickLower_bytes + tickUpper_bytes)
//
// Requirements:
//   - tickLower < tickUpper
//   - Both ticks within valid range [-887272, 887272]
//
// Returns base64-encoded position key or error.
// Combines position package path, tickLower, and tickUpper.
func getPositionKey(
	tickLower int32,
	tickUpper int32,
) (string, error) {
	if err := validateTicks(tickLower, tickUpper); err != nil {
		return "", err
	}

	positionKey := ufmt.Sprintf("%s__%d__%d", positionPackagePath, tickLower, tickUpper)
	encodedPositionKey := base64.StdEncoding.EncodeToString([]byte(positionKey))
	return encodedPositionKey, nil
}

// positionUpdate updates a position's liquidity and calculates fees owed.
// Returns the updated position information and any error.
func positionUpdate(
	position PositionInfo,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) (PositionInfo, error) {
	position.valueOrZero()

	if position.liquidity.IsZero() && liquidityDelta.IsZero() {
		return PositionInfo{}, makeErrorWithDetails(
			errZeroLiquidity,
			"both liquidityDelta and current position's liquidity are zero",
		)
	}

	// check negative liquidity
	if liquidityDelta.IsNeg() {
		// absolute value of negative liquidity delta must be less than current liquidity
		absDelta := i256.Zero().Set(liquidityDelta).Abs()
		currentLiquidity := position.liquidity
		if absDelta.Gt(currentLiquidity) {
			return PositionInfo{}, makeErrorWithDetails(
				errZeroLiquidity,
				ufmt.Sprintf("liquidity delta(%s) is greater than current liquidity(%s)",
					liquidityDelta.ToString(), position.liquidity.ToString()),
			)
		}
	}

	var liquidityNext *u256.Uint
	if liquidityDelta.IsZero() {
		liquidityNext = position.liquidity
	} else {
		liquidityNext = liquidityMathAddDelta(position.liquidity, liquidityDelta)
	}

	// validate negative feeGrowth before calculation
	diff0 := u256.Zero().Sub(feeGrowthInside0X128, position.feeGrowthInside0LastX128)
	diff1 := u256.Zero().Sub(feeGrowthInside1X128, position.feeGrowthInside1LastX128)

	// calculate tokensOwed
	tokensOwed0 := u256.Zero()
	if !diff0.IsZero() {
		tokensOwed0 = u256.MulDiv(diff0, position.liquidity, convertedQ128)
	}

	tokensOwed1 := u256.Zero()
	if !diff1.IsZero() {
		tokensOwed1 = u256.MulDiv(diff1, position.liquidity, convertedQ128)
	}

	if !liquidityDelta.IsZero() {
		position.liquidity = liquidityNext
	}

	position.feeGrowthInside0LastX128 = feeGrowthInside0X128
	position.feeGrowthInside1LastX128 = feeGrowthInside1X128

	// add tokensOwed only when it's greater than 0
	if tokensOwed0.Gt(zero) || tokensOwed1.Gt(zero) {
		owed0, overflow := u256.Zero().AddOverflow(position.tokensOwed0, tokensOwed0)
		if overflow {
			return PositionInfo{}, errOverFlow
		}
		owed1, overflow := u256.Zero().AddOverflow(position.tokensOwed1, tokensOwed1)
		if overflow {
			return PositionInfo{}, errOverFlow
		}

		position.tokensOwed0 = owed0
		position.tokensOwed1 = owed1
	}

	return position, nil
}

// calculateToken0Amount calculates the amount of token0 based on price range and liquidity delta.
func calculateToken0Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	return plp.GetAmount0Delta(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
}

// calculateToken1Amount calculates the amount of token1 based on price range and liquidity delta.
func calculateToken1Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	return plp.GetAmount1Delta(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
}

// PositionLiquidity returns the liquidity of a position.
func (p *Pool) PositionLiquidity(key string) *u256.Uint {
	return p.mustGetPosition(key).liquidity
}

// PositionFeeGrowthInside0LastX128 returns the fee growth of token0 inside a position.
func (p *Pool) PositionFeeGrowthInside0LastX128(key string) *u256.Uint {
	return p.mustGetPosition(key).feeGrowthInside0LastX128
}

// PositionFeeGrowthInside1LastX128 returns the fee growth of token1 inside a position.
func (p *Pool) PositionFeeGrowthInside1LastX128(key string) *u256.Uint {
	return p.mustGetPosition(key).feeGrowthInside1LastX128
}

// PositionTokensOwed0 returns the amount of token0 owed by a position.
func (p *Pool) PositionTokensOwed0(key string) *u256.Uint {
	return p.mustGetPosition(key).tokensOwed0
}

// PositionTokensOwed1 returns the amount of token1 owed by a position.
func (p *Pool) PositionTokensOwed1(key string) *u256.Uint {
	return p.mustGetPosition(key).tokensOwed1
}

// GetPosition returns the position info for a given key.
func (p *Pool) GetPosition(key string) (PositionInfo, bool) {
	iPositionInfo, exist := p.positions.Get(key)
	if !exist {
		newPosition := PositionInfo{}
		newPosition.valueOrZero()
		return newPosition, false
	}

	positionInfo, ok := iPositionInfo.(PositionInfo)
	if !ok {
		panic(ufmt.Sprintf("failed to cast iPositionInfo to PositionInfo: %T", iPositionInfo))
	}
	return positionInfo, true
}

// positionUpdateWithKey updates a position in the pool and returns the updated position.
func (p *Pool) positionUpdateWithKey(
	positionKey string,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128, feeGrowthInside1X128 *u256.Uint,
) (PositionInfo, error) {
	// if pointer is nil, set to zero for calculation
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthInside0X128 = feeGrowthInside0X128.NilToZero()
	feeGrowthInside1X128 = feeGrowthInside1X128.NilToZero()

	// if position does not exist, create a new position
	positionToUpdate, _ := p.GetPosition(positionKey)
	positionAfterUpdate, err := positionUpdate(positionToUpdate, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	if err != nil {
		return PositionInfo{}, err
	}

	p.setPosition(positionKey, positionAfterUpdate)

	return positionAfterUpdate, nil
}

// setPosition sets the position info for a given key.
func (p *Pool) setPosition(posKey string, positionInfo PositionInfo) {
	p.positions.Set(posKey, positionInfo)
}

// mustGetPosition returns the position info for a given key.
func (p *Pool) mustGetPosition(positionKey string) PositionInfo {
	positionInfo, exist := p.GetPosition(positionKey)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("positionKey(%s) does not exist", positionKey),
		))
	}
	return positionInfo
}

// modifyPosition updates a position in the pool and calculates the amount of tokens
// needed (for minting) or returned (for burning). The calculation depends on the current
// price (tick) relative to the position's price range.
//
// The function handles three cases:
//  1. Current price below range (tick < tickLower): only token0 is used/returned
//  2. Current price in range (tickLower <= tick < tickUpper): both tokens are used/returned
//  3. Current price above range (tick >= tickUpper): only token1 is used/returned
//
// Parameters:
//   - params: ModifyPositionParams containing owner, tickLower, tickUpper, and liquidityDelta
//
// Returns:
//   - PositionInfo: updated position information
//   - *u256.Uint: amount of token0 needed/returned
//   - *u256.Uint: amount of token1 needed/returned
func (p *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, *u256.Uint, *u256.Uint, error) {
	if err := validateTicks(params.tickLower, params.tickUpper); err != nil {
		return PositionInfo{}, zero, zero, err
	}

	// get current state and price bounds
	tick := p.Slot0Tick()
	// update position state
	position, err := p.updatePosition(params, tick)
	if err != nil {
		return PositionInfo{}, zero, zero, err
	}

	liqDelta := params.liquidityDelta

	amount0, amount1 := i256.Zero(), i256.Zero()

	// covert ticks to sqrt price to use in amount calculations
	// price = 1.0001^tick, but we use sqrtPriceX96
	sqrtRatioLower := common.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioUpper := common.TickMathGetSqrtRatioAtTick(params.tickUpper)
	sqrtPriceX96 := p.Slot0SqrtPriceX96()

	// calculate token amounts based on current price position relative to range
	switch {
	case tick < params.tickLower:
		// case 1
		// full range between lower and upper tick is used for token0
		// current tick is below the passed range; liquidity can only become in range by crossing from left to
		// right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
		amount0 = calculateToken0Amount(sqrtRatioLower, sqrtRatioUpper, liqDelta)

	case tick < params.tickUpper:
		// case 2
		liquidityBefore := p.liquidity
		// token0 used from current price to upper tick
		amount0 = calculateToken0Amount(sqrtPriceX96, sqrtRatioUpper, liqDelta)
		// token1 used from lower tick to current price
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtPriceX96, liqDelta)
		// update pool's active liquidity since price is in range
		p.liquidity = liquidityMathAddDelta(liquidityBefore, liqDelta)

	default:
		// case 3
		// full range between lower and upper tick is used for token1
		// current tick is above the passed range; liquidity can only become in range by crossing from right to
		// left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtRatioUpper, liqDelta)
	}

	return position, amount0.Abs(), amount1.Abs(), nil
}

// updatePosition modifies the position's liquidity and updates the corresponding tick states.
//
// This function updates the position data based on the specified liquidity delta and tick range.
// It also manages the fee growth, tick state flipping, and cleanup of unused tick data.
//
// Parameters:
//   - positionParams: ModifyPositionParams, the parameters for the position modification, which include:
//   - owner: The address of the position owner.
//   - tickLower: The lower tick boundary of the position.
//   - tickUpper: The upper tick boundary of the position.
//   - liquidityDelta: The change in liquidity (positive or negative).
//   - tick: int32, the current tick position.
//
// Returns:
//   - PositionInfo: The updated position information.
//
// Workflow:
//  1. Clone the global fee growth values (token 0 and token 1).
//  2. If the liquidity delta is non-zero:
//     - Update the lower and upper ticks using `tickUpdate`, flipping their states if necessary.
//     - If a tick's state was flipped, update the tick bitmap to reflect the new state.
//  3. Calculate the fee growth inside the tick range using `getFeeGrowthInside`.
//  4. Generate a unique position key and update the position data using `positionUpdateWithKey`.
//  5. If liquidity is being removed (negative delta), clean up unused tick data by deleting the tick entries.
//  6. Return the updated position.
//
// Notes:
//   - The function flips the tick states and cleans up unused tick data when liquidity is removed.
//   - It ensures fee growth and position data remain accurate after the update.
//
// Example Usage:
//
// ```gno
//
//	updatedPosition := pool.updatePosition(positionParams, currentTick)
//	println("Updated Position Info:", updatedPosition)
//
// ```
func (p *Pool) updatePosition(positionParams ModifyPositionParams, tick int32) (PositionInfo, error) {
	feeGrowthGlobal0X128 := p.FeeGrowthGlobal0X128().Clone()
	feeGrowthGlobal1X128 := p.FeeGrowthGlobal1X128().Clone()

	var flippedLower, flippedUpper bool

	if !positionParams.liquidityDelta.IsZero() {
		flippedLower = p.tickUpdate(
			positionParams.tickLower,
			tick,
			positionParams.liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			false,
			p.maxLiquidityPerTick,
		)

		flippedUpper = p.tickUpdate(
			positionParams.tickUpper,
			tick,
			positionParams.liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			true,
			p.maxLiquidityPerTick,
		)

		if flippedLower {
			p.tickBitmapFlipTick(positionParams.tickLower, p.tickSpacing)
		}

		if flippedUpper {
			p.tickBitmapFlipTick(positionParams.tickUpper, p.tickSpacing)
		}
	}

	feeGrowthInside0X128, feeGrowthInside1X128 := p.getFeeGrowthInside(
		positionParams.tickLower,
		positionParams.tickUpper,
		tick,
		feeGrowthGlobal0X128,
		feeGrowthGlobal1X128,
	)

	positionKey, err := getPositionKey(positionParams.tickLower, positionParams.tickUpper)
	if err != nil {
		return PositionInfo{}, err
	}

	position, err := p.positionUpdateWithKey(
		positionKey,
		positionParams.liquidityDelta,
		feeGrowthInside0X128.Clone(),
		feeGrowthInside1X128.Clone(),
	)
	if err != nil {
		return PositionInfo{}, err
	}

	// clear any tick data that is no longer needed
	if positionParams.liquidityDelta.IsNeg() {
		if flippedLower {
			p.deleteTick(positionParams.tickLower)
		}
		if flippedUpper {
			p.deleteTick(positionParams.tickUpper)
		}
	}

	return position, nil
}
