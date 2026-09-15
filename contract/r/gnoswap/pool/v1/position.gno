package pool

import (
	"errors"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	pl "gno.land/r/gnoswap/pool"
)

// getPositionKey generates a compact deterministic key for a pool liquidity
// accounting entry.
//
// The key encodes only the lower and upper ticks. It is scoped by the pool,
// so positions with the same range share the pool's aggregate liquidity and
// fee-growth accounting.
//
// Used internally for pool position state management.
//
// Parameters:
//   - tickLower: Lower boundary tick of position range
//   - tickUpper: Upper boundary tick of position range
//
// Key Format: EncodePositionKey(tickLower, tickUpper)
//
// Returns:
//   - string: deterministic key encoding the lower and upper tick boundaries.
func getPositionKey(
	tickLower int32,
	tickUpper int32,
) string {
	return pl.EncodePositionKey(tickLower, tickUpper)
}

// positionUpdate applies a signed liquidity delta and refreshes fee-growth checkpoints
// and tokens owed for one position.
//
// Parameters:
//   - position: current position state to update.
//   - liquidityDelta: signed liquidity change; negative values remove liquidity.
//   - feeGrowthInside0X128: current token0 fee growth inside the position range, scaled by 2^128.
//   - feeGrowthInside1X128: current token1 fee growth inside the position range, scaled by 2^128.
//
// Returns:
//   - pl.PositionInfo: updated position state with liquidity, fee checkpoints, and owed tokens.
//   - error: non-nil when both current and delta liquidity are zero or removal exceeds current liquidity.
func positionUpdate(
	position pl.PositionInfo,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) (pl.PositionInfo, error) {
	isZeroLiquidityDelta := liquidityDelta.IsZero()

	posLiquidity := u256.MustFromDecimal(position.Liquidity())
	if posLiquidity.IsZero() && isZeroLiquidityDelta {
		return pl.NewDefaultPositionInfo(), makeErrorWithDetails(
			errZeroLiquidity,
			"both liquidityDelta and current position's liquidity are zero",
		)
	}

	if liquidityDelta.IsNeg() {
		absDelta := i256.Zero().Set(liquidityDelta).Abs()
		if absDelta.Gt(posLiquidity) {
			return pl.NewDefaultPositionInfo(), makeErrorWithDetails(
				errZeroLiquidity,
				ufmt.Sprintf("liquidity delta(%s) is greater than current liquidity(%s)",
					liquidityDelta.ToString(), posLiquidity.ToString()),
			)
		}
	}

	var liquidityNext *u256.Uint
	if isZeroLiquidityDelta {
		liquidityNext = posLiquidity
	} else {
		liquidityNext = gnsmath.LiquidityMathAddDelta(posLiquidity, liquidityDelta)
	}

	feeGrowthLast0 := u256.MustFromDecimal(position.FeeGrowthInside0LastX128())
	feeGrowthLast1 := u256.MustFromDecimal(position.FeeGrowthInside1LastX128())

	diff0 := u256.Zero().Sub(feeGrowthInside0X128, feeGrowthLast0)
	diff1 := u256.Zero().Sub(feeGrowthInside1X128, feeGrowthLast1)

	tokensOwed0 := u256.Zero()
	if !diff0.IsZero() {
		tokensOwed0 = u256.MulDiv(diff0, posLiquidity, q128FromDecimal)
	}

	tokensOwed1 := u256.Zero()
	if !diff1.IsZero() {
		tokensOwed1 = u256.MulDiv(diff1, posLiquidity, q128FromDecimal)
	}

	if !isZeroLiquidityDelta {
		position.SetLiquidity(liquidityNext.ToString())
	}

	position.SetFeeGrowthInside0LastX128(feeGrowthInside0X128.ToString())
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1X128.ToString())

	if tokensOwed0.Gt(zero) || tokensOwed1.Gt(zero) {
		owed0 := gnsmath.SafeAddInt64(position.TokensOwed0(), gnsmath.SafeConvertToInt64(tokensOwed0))
		owed1 := gnsmath.SafeAddInt64(position.TokensOwed1(), gnsmath.SafeConvertToInt64(tokensOwed1))

		position.SetTokensOwed0(owed0)
		position.SetTokensOwed1(owed1)
	}

	return position, nil
}

// calculateToken0Amount calculates the signed token0 amount implied by a price range and liquidity delta.
//
// Parameters:
//   - sqrtPriceLower: lower range price as a Q96 square-root ratio.
//   - sqrtPriceUpper: upper range price as a Q96 square-root ratio.
//   - liquidityDelta: signed liquidity to add or remove.
//
// Returns:
//   - *i256.Int: signed token0 amount required for the liquidity change.
func calculateToken0Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	return gnsmath.GetAmount0Delta(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
}

// calculateToken1Amount calculates the signed token1 amount implied by a price range and liquidity delta.
//
// Parameters:
//   - sqrtPriceLower: lower range price as a Q96 square-root ratio.
//   - sqrtPriceUpper: upper range price as a Q96 square-root ratio.
//   - liquidityDelta: signed liquidity to add or remove.
//
// Returns:
//   - *i256.Int: signed token1 amount required for the liquidity change.
func calculateToken1Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	return gnsmath.GetAmount1Delta(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
}

// positionUpdateWithKey loads, updates, and stores one pool position by its encoded range key.
//
// Parameters:
//   - p: pool whose aggregate position tree is updated.
//   - positionKey: encoded lower/upper tick-range key.
//   - liquidityDelta: signed liquidity change; negative values remove liquidity.
//   - feeGrowthInside0X128: current token0 inside fee growth, scaled by 2^128.
//   - feeGrowthInside1X128: current token1 inside fee growth, scaled by 2^128.
//
// Returns:
//   - pl.PositionInfo: resulting position state stored under positionKey.
//   - error: non-nil when the position update rejects the liquidity delta.
func positionUpdateWithKey(
	p *pl.Pool,
	positionKey string,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128, feeGrowthInside1X128 *u256.Uint,
) (pl.PositionInfo, error) {
	// if position does not exist, create a new position
	//
	// Note: The positionUpdate function is designed to handle both new positions and existing positions,
	// so there's no need to check for existence in GetPosition.
	positionToUpdate, err := p.GetPosition(positionKey)
	if err != nil {
		positionToUpdate = pl.NewDefaultPositionInfo()
	}

	positionAfterUpdate, err := positionUpdate(positionToUpdate, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	if err != nil {
		return pl.NewDefaultPositionInfo(), err
	}

	setPosition(p, positionKey, positionAfterUpdate)

	return positionAfterUpdate, nil
}

// setPosition stores position information under an encoded range key.
//
// Parameters:
//   - p: pool whose position tree receives the entry.
//   - posKey: encoded lower/upper tick-range key.
//   - positionInfo: aggregate position state to store.
func setPosition(p *pl.Pool, posKey string, positionInfo pl.PositionInfo) {
	p.SetPosition(posKey, positionInfo)
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
//   - p: pool whose slot0, liquidity, ticks, and position state are updated.
//   - observations: pool observation tree used when the current price is inside the range.
//   - params: owner, tick bounds, and signed liquidity delta for the position update.
//
// Returns:
//   - pl.PositionInfo: updated aggregate position information.
//   - *u256.Uint: absolute token0 amount needed or returned.
//   - *u256.Uint: absolute token1 amount needed or returned.
//   - error: non-nil when tick bounds, observations, or position accounting are invalid.
func modifyPosition(p *pl.Pool, observations *pl.ObservationTree, params ModifyPositionParams) (pl.PositionInfo, *u256.Uint, *u256.Uint, error) {
	if err := validateTicks(params.tickLower, params.tickUpper); err != nil {
		return pl.NewDefaultPositionInfo(), zero, zero, err
	}

	// get current state and price bounds
	tick := p.Slot0Tick()
	// update position state
	position, err := updatePosition(p, observations, params, tick)
	if err != nil {
		return pl.NewDefaultPositionInfo(), zero, zero, err
	}

	liqDelta := params.liquidityDelta
	if liqDelta.IsZero() {
		return position, zero, zero, nil
	}

	amount0, amount1 := i256.Zero(), i256.Zero()

	// covert ticks to sqrt price to use in amount calculations
	// price = 1.0001^tick, but we use sqrtPriceX96
	sqrtRatioLower := gnsmath.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioUpper := gnsmath.TickMathGetSqrtRatioAtTick(params.tickUpper)
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
		// case 2: Current price is within the position range
		liquidityBefore := p.Liquidity()
		currentTime := time.Now().Unix()
		// Update oracle BEFORE liquidity changes
		if observations == nil {
			return pl.NewDefaultPositionInfo(), zero, zero, errors.New("observations not initialized")
		}
		slot0 := p.Slot0()
		observationIndex, observationCardinality, err := writeObservation(
			observations,
			slot0.ObservationIndex(),
			currentTime,
			tick,
			liquidityBefore,
			slot0.ObservationCardinality(),
			slot0.ObservationCardinalityNext(),
		)
		if err != nil {
			return pl.NewDefaultPositionInfo(), zero, zero, err
		}
		slot0.SetObservationIndex(observationIndex)
		slot0.SetObservationCardinality(observationCardinality)
		p.SetSlot0(slot0)

		// token0 used from current price to upper tick
		amount0 = calculateToken0Amount(sqrtPriceX96, sqrtRatioUpper, liqDelta)
		// token1 used from lower tick to current price
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtPriceX96, liqDelta)
		// update pool's active liquidity since price is in range
		p.SetLiquidity(gnsmath.LiquidityMathAddDelta(liquidityBefore, liqDelta))

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
//   - p: Pool whose aggregate position entry is updated.
//   - observations: Pool observation history used when liquidity changes.
//   - positionParams: Tick bounds and signed liquidity delta for the update.
//   - tick: Current pool tick.
//
// Returns:
//   - PositionInfo: The updated position information.
//   - error: Observation or position update failure.
//
// Workflow:
//  1. Clone the global fee growth values (token 0 and token 1).
//  2. If the liquidity delta is non-zero:
//     - Update the lower and upper ticks using `tickUpdate`, flipping their states if necessary.
//     - If a tick's state was flipped, update the tick bitmap to reflect the new state.
//  3. Calculate the fee growth inside the tick range using `getFeeGrowthInside`.
//  4. Encode the lower/upper tick pair and update the aggregate pool accounting
//     entry using `positionUpdateWithKey`.
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
//	updatedPosition, err := updatePosition(pool, observations, positionParams, currentTick)
//	println("Updated Position Info:", updatedPosition, err)
//
// ```
func updatePosition(p *pl.Pool, observations *pl.ObservationTree, positionParams ModifyPositionParams, tick int32) (pl.PositionInfo, error) {
	feeGrowthGlobal0X128 := p.FeeGrowthGlobal0X128().Clone()
	feeGrowthGlobal1X128 := p.FeeGrowthGlobal1X128().Clone()
	liquidityDelta := positionParams.liquidityDelta

	var flippedLower, flippedUpper bool
	if !liquidityDelta.IsZero() {
		blockTimestamp := time.Now().Unix()
		if observations == nil {
			return pl.NewDefaultPositionInfo(), errors.New("observations not initialized")
		}
		slot0 := p.Slot0()
		tickCumulative, secondsPerLiquidityStr, err := observeSingle(
			observations,
			blockTimestamp,
			0,
			slot0.Tick(),
			slot0.ObservationIndex(),
			p.Liquidity(),
			slot0.ObservationCardinality(),
		)
		if err != nil {
			return pl.NewDefaultPositionInfo(), err
		}

		secondsPerLiquidityCumulativeX128 := u256.MustFromDecimal(secondsPerLiquidityStr)

		flippedLower = tickUpdate(
			p,
			positionParams.tickLower,
			tick,
			liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			secondsPerLiquidityCumulativeX128,
			tickCumulative,
			blockTimestamp,
			false,
			calculateMaxLiquidityPerTick(p.TickSpacing()),
		)

		flippedUpper = tickUpdate(
			p,
			positionParams.tickUpper,
			tick,
			liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			secondsPerLiquidityCumulativeX128,
			tickCumulative,
			blockTimestamp,
			true,
			calculateMaxLiquidityPerTick(p.TickSpacing()),
		)

		if flippedLower {
			tickBitmapFlipTick(p, positionParams.tickLower, p.TickSpacing())
		}

		if flippedUpper {
			tickBitmapFlipTick(p, positionParams.tickUpper, p.TickSpacing())
		}
	}

	feeGrowthInside0X128, feeGrowthInside1X128 := getFeeGrowthInside(
		p,
		positionParams.tickLower,
		positionParams.tickUpper,
		tick,
		feeGrowthGlobal0X128,
		feeGrowthGlobal1X128,
	)

	positionKey := getPositionKey(positionParams.tickLower, positionParams.tickUpper)

	position, err := positionUpdateWithKey(
		p,
		positionKey,
		liquidityDelta,
		feeGrowthInside0X128.Clone(),
		feeGrowthInside1X128.Clone(),
	)
	if err != nil {
		return pl.NewDefaultPositionInfo(), err
	}

	// clear any tick data that is no longer needed
	if liquidityDelta.IsNeg() {
		if flippedLower {
			deleteTick(p, positionParams.tickLower)
		}
		if flippedUpper {
			deleteTick(p, positionParams.tickUpper)
		}
	}

	return position, nil
}
