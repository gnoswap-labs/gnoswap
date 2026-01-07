package v1

import (
	"encoding/base64"
	"strconv"
	"time"

	plp "gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

const positionPackagePath = "gno.land/r/gnoswap/position"

// getPositionKey generates a unique base64-encoded key for a liquidity position.
//
// Creates deterministic identifier for position tracking.
// Ensures unique positions per (position package path, price range) combination.
//
// Used internally for position state management.
//
// Parameters:
//   - tickLower: Lower boundary tick of position range
//   - tickUpper: Upper boundary tick of position range
//
// Key Format:
//
//	base64(position_package_path + "__" + tickLower + "__" + tickUpper)
//
// Returns base64-encoded position key or error.
// Combines position package path, tickLower, and tickUpper.
func getPositionKey(
	tickLower int32,
	tickUpper int32,
) string {
	positionKey := positionPackagePath + "__" + strconv.Itoa(int(tickLower)) + "__" + strconv.Itoa(int(tickUpper))
	encodedPositionKey := base64.StdEncoding.EncodeToString([]byte(positionKey))
	return encodedPositionKey
}

// positionUpdate updates a position's liquidity and calculates fees owed.
// Returns the updated position information and any error.
func positionUpdate(
	position pl.PositionInfo,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128 *u256.Uint,
	feeGrowthInside1X128 *u256.Uint,
) (pl.PositionInfo, error) {
	isZeroLiquidityDelta := liquidityDelta.IsZero()

	if position.Liquidity().IsZero() && isZeroLiquidityDelta {
		return pl.NewDefaultPositionInfo(), makeErrorWithDetails(
			errZeroLiquidity,
			"both liquidityDelta and current position's liquidity are zero",
		)
	}

	if liquidityDelta.IsNeg() {
		// absolute value of negative liquidity delta must be less than current liquidity
		absDelta := i256.Zero().Set(liquidityDelta).Abs()
		currentLiquidity := position.Liquidity()
		if absDelta.Gt(currentLiquidity) {
			return pl.NewDefaultPositionInfo(), makeErrorWithDetails(
				errZeroLiquidity,
				ufmt.Sprintf("liquidity delta(%s) is greater than current liquidity(%s)",
					liquidityDelta.ToString(), position.Liquidity().ToString()),
			)
		}
	}

	var liquidityNext *u256.Uint
	if isZeroLiquidityDelta {
		liquidityNext = position.Liquidity()
	} else {
		liquidityNext = common.LiquidityMathAddDelta(position.Liquidity(), liquidityDelta)
	}

	// validate negative feeGrowth before calculation
	diff0 := u256.Zero().Sub(feeGrowthInside0X128, position.FeeGrowthInside0LastX128())
	diff1 := u256.Zero().Sub(feeGrowthInside1X128, position.FeeGrowthInside1LastX128())

	// calculate tokensOwed
	tokensOwed0 := u256.Zero()
	if !diff0.IsZero() {
		tokensOwed0 = u256.MulDiv(diff0, position.Liquidity(), q128FromDecimal)
	}

	tokensOwed1 := u256.Zero()
	if !diff1.IsZero() {
		tokensOwed1 = u256.MulDiv(diff1, position.Liquidity(), q128FromDecimal)
	}

	if !isZeroLiquidityDelta {
		position.SetLiquidity(liquidityNext)
	}

	position.SetFeeGrowthInside0LastX128(feeGrowthInside0X128)
	position.SetFeeGrowthInside1LastX128(feeGrowthInside1X128)

	// add tokensOwed only when it's greater than 0
	if tokensOwed0.Gt(zero) || tokensOwed1.Gt(zero) {
		owed0, overflow := u256.Zero().AddOverflow(position.TokensOwed0(), tokensOwed0)
		if overflow {
			return pl.NewDefaultPositionInfo(), errOverflow
		}
		owed1, overflow := u256.Zero().AddOverflow(position.TokensOwed1(), tokensOwed1)
		if overflow {
			return pl.NewDefaultPositionInfo(), errOverflow
		}

		position.SetTokensOwed0(owed0)
		position.SetTokensOwed1(owed1)
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
func PositionLiquidity(p *pl.Pool, key string) *u256.Uint {
	return mustGetPositionByPool(p, key).Liquidity()
}

// PositionFeeGrowthInside0LastX128 returns the fee growth of token0 inside a position.
func PositionFeeGrowthInside0LastX128(p *pl.Pool, key string) *u256.Uint {
	return mustGetPositionByPool(p, key).FeeGrowthInside0LastX128()
}

// PositionFeeGrowthInside1LastX128 returns the fee growth of token1 inside a position.
func PositionFeeGrowthInside1LastX128(p *pl.Pool, key string) *u256.Uint {
	return mustGetPositionByPool(p, key).FeeGrowthInside1LastX128()
}

// PositionTokensOwed0 returns the amount of token0 owed by a position.
func PositionTokensOwed0(p *pl.Pool, key string) *u256.Uint {
	return mustGetPositionByPool(p, key).TokensOwed0()
}

// PositionTokensOwed1 returns the amount of token1 owed by a position.
func PositionTokensOwed1(p *pl.Pool, key string) *u256.Uint {
	return mustGetPositionByPool(p, key).TokensOwed1()
}

// GetPosition returns the position info for a given key.
func GetPositionByPool(p *pl.Pool, key string) (pl.PositionInfo, bool) {
	iPositionInfo, exist := p.Positions().Get(key)
	if !exist {
		newPosition := pl.NewDefaultPositionInfo()
		return newPosition, false
	}

	positionInfo, ok := iPositionInfo.(pl.PositionInfo)
	if !ok {
		panic(ufmt.Sprintf("failed to cast iPositionInfo to PositionInfo: %T", iPositionInfo))
	}

	return positionInfo, true
}

// positionUpdateWithKey updates a position in the pool and returns the updated position.
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
	positionToUpdate, _ := GetPositionByPool(p, positionKey)
	positionAfterUpdate, err := positionUpdate(positionToUpdate, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	if err != nil {
		return pl.NewDefaultPositionInfo(), err
	}

	setPosition(p, positionKey, positionAfterUpdate)

	return positionAfterUpdate, nil
}

// setPosition sets the position info for a given key.
func setPosition(p *pl.Pool, posKey string, positionInfo pl.PositionInfo) {
	p.Positions().Set(posKey, positionInfo)
}

// mustGetPosition returns the position info for a given key.
func mustGetPositionByPool(p *pl.Pool, positionKey string) *pl.PositionInfo {
	positionInfo, exist := GetPositionByPool(p, positionKey)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("positionKey(%s) does not exist", positionKey),
		))
	}

	return &positionInfo
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
func modifyPosition(p *pl.Pool, params ModifyPositionParams) (pl.PositionInfo, *u256.Uint, *u256.Uint, error) {
	if err := validateTicks(params.tickLower, params.tickUpper); err != nil {
		return pl.NewDefaultPositionInfo(), zero, zero, err
	}

	// get current state and price bounds
	tick := p.Slot0Tick()
	// update position state
	position, err := updatePosition(p, params, tick)
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
		// case 2: Current price is within the position range
		liquidityBefore := p.Liquidity()
		currentTime := time.Now().Unix()

		// Update oracle BEFORE liquidity changes
		err := writeObservationByPool(p, currentTime, tick, liquidityBefore)
		if err != nil {
			return pl.NewDefaultPositionInfo(), zero, zero, err
		}

		// token0 used from current price to upper tick
		amount0 = calculateToken0Amount(sqrtPriceX96, sqrtRatioUpper, liqDelta)
		// token1 used from lower tick to current price
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtPriceX96, liqDelta)
		// update pool's active liquidity since price is in range
		p.SetLiquidity(common.LiquidityMathAddDelta(liquidityBefore, liqDelta))

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
func updatePosition(p *pl.Pool, positionParams ModifyPositionParams, tick int32) (pl.PositionInfo, error) {
	feeGrowthGlobal0X128 := p.FeeGrowthGlobal0X128().Clone()
	feeGrowthGlobal1X128 := p.FeeGrowthGlobal1X128().Clone()
	liquidityDelta := positionParams.liquidityDelta

	var flippedLower, flippedUpper bool
	if !liquidityDelta.IsZero() {
		flippedLower = tickUpdate(
			p,
			positionParams.tickLower,
			tick,
			liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			false,
			p.MaxLiquidityPerTick(),
		)

		flippedUpper = tickUpdate(
			p,
			positionParams.tickUpper,
			tick,
			liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			true,
			p.MaxLiquidityPerTick(),
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
