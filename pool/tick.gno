package pool

import (
	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
)

// calculateMaxLiquidityPerTick calculates the maximum liquidity
// per tick for a given tick spacing.
func calculateMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	return new(u256.Uint).Div(u256.MustFromDecimal(consts.MAX_UINT128), u256.NewUint(numTicks))
}

func getFeeGrowthBelowX128(
	tickLower, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	lowerTick TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent >= tickLower {
		return lowerTick.feeGrowthOutside0X128, lowerTick.feeGrowthOutside1X128
	}

	below0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, lowerTick.feeGrowthOutside0X128)
	below1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, lowerTick.feeGrowthOutside1X128)

	return below0X128, below1X128
}

func getFeeGrowthAboveX128(
	tickUpper, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	upperTick TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent < tickUpper {
		return upperTick.feeGrowthOutside0X128, upperTick.feeGrowthOutside1X128
	}

	above0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, upperTick.feeGrowthOutside0X128)
	above1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, upperTick.feeGrowthOutside1X128)

	return above0X128, above1X128
}

// calculateFeeGrowthInside calculates the fee growth inside a tick range,
// and returns the fee growth inside for both tokens.
func (p *Pool) calculateFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	lower := p.getTick(tickLower)
	upper := p.getTick(tickUpper)

	feeGrowthBelow0X128, feeGrowthBelow1X128 := getFeeGrowthBelowX128(tickLower, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, lower)
	feeGrowthAbove0X128, feeGrowthAbove1X128 := getFeeGrowthAboveX128(tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, upper)

	feeGrowthInside0X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128), feeGrowthAbove0X128)
	feeGrowthInside1X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128), feeGrowthAbove1X128)

	return feeGrowthInside0X128, feeGrowthInside1X128
}

// tickUpdate updates the state of a specific tick.
//
// This function applies a given liquidity change (liquidityDelta) to the specified tick, updates
// the fee growth values if necessary, and adjusts the net liquidity based on whether the tick
// is an upper or lower boundary. It also verifies that the total liquidity does not exceed the
// maximum allowed value and ensures the net liquidity stays within the valid int128 range.
//
// Parameters:
//   - tick:          int32, the index of the tick to update.
//   - tickCurrent:   int32, the current active tick index.
//   - liquidityDelta: *i256.Int, the amount of liquidity to add or remove.
//   - feeGrowthGlobal0X128: *u256.Uint, the global fee growth value for token 0.
//   - feeGrowthGlobal1X128: *u256.Uint, the global fee growth value for token 1.
//   - upper:         bool, indicates if this is the upper boundary (true for upper, false for lower).
//   - maxLiquidity:  *u256.Uint, the maximum allowed liquidity.
//
// Returns:
//   - flipped: bool, indicates if the tick's initialization state has changed.
//     (e.g., liquidity transitioning from zero to non-zero, or vice versa)
//
// Workflow:
// 1. Nil input values are replaced with zero.
// 2. The function retrieves the tick information for the specified tick index.
// 3. Applies the liquidityDelta to compute the new total liquidity (liquidityGross).
//   - If the total liquidity exceeds the maximum allowed value, the function panics.
//     4. Checks whether the tick's initialized state has changed and sets the `flipped` flag.
//     5. If the tick was previously uninitialized and its index is less than or equal to the current tick,
//     the fee growth values are initialized to the current global values.
//     6. Updates the tick's net liquidity:
//   - For an upper boundary, it subtracts liquidityDelta.
//   - For a lower boundary, it adds liquidityDelta.
//   - Ensures the net liquidity remains within the int128 range using `checkOverFlowInt128`.
//     7. Updates the tick's state with the new values.
//     8. Returns whether the tick's initialized state has flipped.
//
// Panic Conditions:
// - The total liquidity (liquidityGross) exceeds the maximum allowed liquidity (maxLiquidity).
// - The net liquidity (liquidityNet) exceeds the int128 range.
//
// Example:
//
//	flipped := pool.tickUpdate(10, 5, liquidityDelta, feeGrowth0, feeGrowth1, true, maxLiquidity)
//	fmt.Println("Tick flipped:", flipped)
func (p *Pool) tickUpdate(
	tick int32,
	tickCurrent int32,
	liquidityDelta *i256.Int,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
	upper bool,
	maxLiquidity *u256.Uint,
) (flipped bool) {
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthGlobal0X128 = feeGrowthGlobal0X128.NilToZero()
	feeGrowthGlobal1X128 = feeGrowthGlobal1X128.NilToZero()

	tickInfo := p.getTick(tick)

	liquidityGrossBefore := tickInfo.liquidityGross.Clone()
	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)

	if !(liquidityGrossAfter.Lte(maxLiquidity)) {
		panic(addDetailToError(
			errLiquidityCalculation,
			ufmt.Sprintf("liquidityGrossAfter(%s) overflows maxLiquidity(%s)", liquidityGrossAfter.ToString(), maxLiquidity.ToString()),
		))
	}

	flipped = (liquidityGrossAfter.IsZero()) != (liquidityGrossBefore.IsZero())

	if liquidityGrossBefore.IsZero() {
		if tick <= tickCurrent {
			tickInfo.feeGrowthOutside0X128 = feeGrowthGlobal0X128.Clone()
			tickInfo.feeGrowthOutside1X128 = feeGrowthGlobal1X128.Clone()
		}
		tickInfo.initialized = true
	}

	tickInfo.liquidityGross = liquidityGrossAfter.Clone()

	if upper {
		tickInfo.liquidityNet = i256.Zero().Sub(tickInfo.liquidityNet, liquidityDelta)
		checkOverFlowInt128(tickInfo.liquidityNet)
	} else {
		tickInfo.liquidityNet = i256.Zero().Add(tickInfo.liquidityNet, liquidityDelta)
		checkOverFlowInt128(tickInfo.liquidityNet)
	}

	p.setTick(tick, tickInfo)

	return flipped
}

// tickCross updates a tick's state when it is crossed and returns the liquidity net.
func (p *Pool) tickCross(
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) *i256.Int {
	thisTick := p.getTick(tick)

	thisTick.feeGrowthOutside0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, thisTick.feeGrowthOutside0X128)
	thisTick.feeGrowthOutside1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, thisTick.feeGrowthOutside1X128)

	p.ticks[tick] = thisTick

	return thisTick.liquidityNet.Clone()
}

// setTick updates the tick data for the specified tick index in the pool.
func (p *Pool) setTick(tick int32, newTickInfo TickInfo) {
	p.ticks[tick] = newTickInfo
}

// getTick retrieves the TickInfo associated with the specified tick index from the pool.
// If the TickInfo contains any nil fields, they are replaced with zero values using valueOrZero.
//
// Parameters:
// - tick: The tick index (int32) for which the TickInfo is to be retrieved.
//
// Behavior:
// - Retrieves the TickInfo for the given tick from the pool's tick map.
// - Ensures that all fields of TickInfo are non-nil by calling valueOrZero, which replaces nil values with zero.
// - Returns the updated TickInfo.
//
// Returns:
// - TickInfo: The tick data with all fields guaranteed to have valid values (nil fields are set to zero).
//
// Use Case:
// This function ensures the retrieved tick data is always valid and safe for further operations,
// such as calculations or updates, by sanitizing nil fields in the TickInfo structure.
func (p *Pool) getTick(tick int32) TickInfo {
	tickInfo := p.ticks[tick]
	tickInfo.valueOrZero()
	return tickInfo
}

// GetTickLiquidityGross returns the gross liquidity for the specified tick.
func (p *Pool) GetTickLiquidityGross(tick int32) *u256.Uint {
	return p.mustGetTick(tick).liquidityGross
}

// GetTickLiquidityNet returns the net liquidity for the specified tick.
func (p *Pool) GetTickLiquidityNet(tick int32) *i256.Int {
	return p.mustGetTick(tick).liquidityNet
}

// GetTickFeeGrowthOutside0X128 returns the fee growth outside the tick for token 0.
func (p *Pool) GetTickFeeGrowthOutside0X128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).feeGrowthOutside0X128
}

// GetTickFeeGrowthOutside1X128 returns the fee growth outside the tick for token 1.
func (p *Pool) GetTickFeeGrowthOutside1X128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).feeGrowthOutside1X128
}

// GetTickCumulativeOutside returns the cumulative liquidity outside the tick.
func (p *Pool) GetTickCumulativeOutside(tick int32) int64 {
	return p.mustGetTick(tick).tickCumulativeOutside
}

// GetTickSecondsPerLiquidityOutsideX128 returns the seconds per liquidity outside the tick.
func (p *Pool) GetTickSecondsPerLiquidityOutsideX128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).secondsPerLiquidityOutsideX128
}

// GetTickSecondsOutside returns the seconds outside the tick.
func (p *Pool) GetTickSecondsOutside(tick int32) uint32 {
	return p.mustGetTick(tick).secondsOutside
}

// GetTickInitialized returns whether the tick is initialized.
func (p *Pool) GetTickInitialized(tick int32) bool {
	return p.mustGetTick(tick).initialized
}

// mustGetTick retrieves the TickInfo for a specific tick, panicking if the tick does not exist.
//
// This function ensures that the requested tick data exists in the pool's tick mapping.
// If the tick does not exist, it panics with an appropriate error message.
//
// Parameters:
//   - tick: int32, the index of the tick to retrieve.
//
// Returns:
//   - TickInfo: The information associated with the specified tick.
//
// Behavior:
//   - Checks if the tick exists in the pool's tick mapping (`p.ticks`).
//   - If the tick exists, it returns the corresponding `TickInfo`.
//   - If the tick does not exist, the function panics with a descriptive error.
//
// Panic Conditions:
//   - The specified tick does not exist in the pool's mapping.
//
// Example:
//
//	tickInfo := pool.mustGetTick(10)
//	fmt.Println("Tick Info:", tickInfo)
func (p *Pool) mustGetTick(tick int32) TickInfo {
	tickInfo, exist := p.ticks[tick]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tick(%d) does not exist", tick),
		))
	}

	return tickInfo
}
