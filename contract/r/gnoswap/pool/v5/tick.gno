package v5

import (
	"strconv"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

const (
	MIN_TICK int32 = -887272
	MAX_TICK int32 = 887272
)

// GetTickLiquidityGross returns the gross liquidity for the specified tick.
func GetTickLiquidityGross(p *pl.Pool, tick int32) *u256.Uint {
	return mustGetTick(p, tick).LiquidityGross()
}

// GetTickLiquidityNet returns the net liquidity for the specified tick.
func GetTickLiquidityNet(p *pl.Pool, tick int32) *i256.Int {
	return mustGetTick(p, tick).LiquidityNet()
}

// GetTickFeeGrowthOutside0X128 returns the fee growth outside the tick for token 0.
func GetTickFeeGrowthOutside0X128(p *pl.Pool, tick int32) *u256.Uint {
	return mustGetTick(p, tick).FeeGrowthOutside0X128()
}

// GetTickFeeGrowthOutside1X128 returns the fee growth outside the tick for token 1.
func GetTickFeeGrowthOutside1X128(p *pl.Pool, tick int32) *u256.Uint {
	return mustGetTick(p, tick).FeeGrowthOutside1X128()
}

// GetTickCumulativeOutside returns the cumulative liquidity outside the tick.
func GetTickCumulativeOutside(p *pl.Pool, tick int32) int64 {
	return mustGetTick(p, tick).TickCumulativeOutside()
}

// GetTickSecondsPerLiquidityOutsideX128 returns the seconds per liquidity outside the tick.
func GetTickSecondsPerLiquidityOutsideX128(p *pl.Pool, tick int32) *u256.Uint {
	return mustGetTick(p, tick).SecondsPerLiquidityOutsideX128()
}

// GetTickSecondsOutside returns the seconds outside the tick.
func GetTickSecondsOutside(p *pl.Pool, tick int32) uint32 {
	return mustGetTick(p, tick).SecondsOutside()
}

// GetTickInitialized returns whether the tick is initialized.
func GetTickInitialized(p *pl.Pool, tick int32) bool {
	return mustGetTick(p, tick).Initialized()
}

// getFeeGrowthInside calculates the fee growth within a specified tick range.
//
// This function computes the accumulated fee growth for token 0 and token 1 inside a given tick range
// (`tickLower` to `tickUpper`) relative to the current tick position (`tickCurrent`). It isolates the fee
// growth within the range by subtracting the fee growth below the lower tick and above the upper tick
// from the global fee growth.
//
// Parameters:
//   - tickLower: int32, the lower tick boundary of the range.
//   - tickUpper: int32, the upper tick boundary of the range.
//   - tickCurrent: int32, the current tick index.
//   - feeGrowthGlobal0X128: *u256.Uint, the global fee growth for token 0 in X128 precision.
//   - feeGrowthGlobal1X128: *u256.Uint, the global fee growth for token 1 in X128 precision.
//
// Returns:
//   - *u256.Uint: Fee growth inside the tick range for token 0.
//   - *u256.Uint: Fee growth inside the tick range for token 1.
//
// Workflow:
//  1. Retrieve the tick information (`lower` and `upper`) for the lower and upper tick boundaries
//     using `p.getTick`.
//  2. Calculate the fee growth below the lower tick using `getFeeGrowthBelowX128`.
//  3. Calculate the fee growth above the upper tick using `getFeeGrowthAboveX128`.
//  4. Subtract the fee growth below and above the range from the global fee growth values:
//     feeGrowthInside = feeGrowthGlobal - feeGrowthBelow - feeGrowthAbove
//  5. Return the computed fee growth values for token 0 and token 1 within the range.
//
// Behavior:
//   - The fee growth is isolated within the range `[tickLower, tickUpper]`.
//   - The function ensures the calculations accurately consider the tick boundaries and the current tick position.
//
// Example:
//
// ```gno
//
//	feeGrowth0, feeGrowth1 := pool.getFeeGrowthInside(
//	    100, 200, 150, globalFeeGrowth0, globalFeeGrowth1,
//	)
//	println("Fee Growth Inside (Token 0):", feeGrowth0)
//	println("Fee Growth Inside (Token 1):", feeGrowth1)
//
// ```
func getFeeGrowthInside(
	p *pl.Pool,
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	lower := getTick(p, tickLower)
	upper := getTick(p, tickUpper)

	feeGrowthBelow0X128, feeGrowthBelow1X128 := getFeeGrowthBelowX128(tickLower, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, lower)
	feeGrowthAbove0X128, feeGrowthAbove1X128 := getFeeGrowthAboveX128(tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, upper)

	feeGrowthInside0X128 := u256.Zero().Sub(u256.Zero().Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128), feeGrowthAbove0X128)
	feeGrowthInside1X128 := u256.Zero().Sub(u256.Zero().Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128), feeGrowthAbove1X128)

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
// ```gno
//
//	flipped := pool.tickUpdate(10, 5, liquidityDelta, feeGrowth0, feeGrowth1, true, maxLiquidity)
//	println("Tick flipped:", flipped)
//
// ```
func tickUpdate(
	p *pl.Pool,
	tick int32,
	tickCurrent int32,
	liquidityDelta *i256.Int,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
	upper bool,
	maxLiquidity *u256.Uint,
) (flipped bool) {
	tickInfo := getTick(p, tick)

	liquidityGrossBefore := tickInfo.LiquidityGross().Clone()
	liquidityGrossAfter := common.LiquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)

	if !liquidityGrossAfter.Lte(maxLiquidity) {
		panic(newErrorWithDetail(
			errLiquidityCalculation,
			ufmt.Sprintf("liquidityGrossAfter(%s) overflows maxLiquidity(%s)", liquidityGrossAfter.ToString(), maxLiquidity.ToString()),
		))
	}

	flipped = liquidityGrossAfter.IsZero() != liquidityGrossBefore.IsZero()

	if liquidityGrossBefore.IsZero() {
		if tick <= tickCurrent {
			tickInfo.SetFeeGrowthOutside0X128(feeGrowthGlobal0X128.Clone())
			tickInfo.SetFeeGrowthOutside1X128(feeGrowthGlobal1X128.Clone())
		}
		tickInfo.SetInitialized(true)
	}

	tickInfo.SetLiquidityGross(liquidityGrossAfter.Clone())

	if upper {
		tickInfo.SetLiquidityNet(i256.Zero().Sub(tickInfo.LiquidityNet(), liquidityDelta))
		checkOverFlowInt128(tickInfo.LiquidityNet())
	} else {
		tickInfo.SetLiquidityNet(i256.Zero().Add(tickInfo.LiquidityNet(), liquidityDelta))
		checkOverFlowInt128(tickInfo.LiquidityNet())
	}

	setTick(p, tick, tickInfo)

	return flipped
}

// tickCross updates a tick's state when it is crossed and returns the liquidity net.
// Updates fee growth and oracle accumulator values for the tick.
func tickCross(
	p *pl.Pool,
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
	secondsPerLiquidityCumulativeX128 *u256.Uint,
	tickCumulative int64,
	blockTimestamp int64,
) *i256.Int {
	thisTick := getTick(p, tick)

	thisTick.SetFeeGrowthOutside0X128(u256.Zero().Sub(feeGrowthGlobal0X128, thisTick.FeeGrowthOutside0X128()))
	thisTick.SetFeeGrowthOutside1X128(u256.Zero().Sub(feeGrowthGlobal1X128, thisTick.FeeGrowthOutside1X128()))

	// Handle oracle fields - use zero values if nil
	tickSecondsPerLiquidity := thisTick.SecondsPerLiquidityOutsideX128()
	if tickSecondsPerLiquidity == nil {
		tickSecondsPerLiquidity = u256.Zero()
	}
	thisTick.SetSecondsPerLiquidityOutsideX128(u256.Zero().Sub(secondsPerLiquidityCumulativeX128, tickSecondsPerLiquidity))
	thisTick.SetTickCumulativeOutside(tickCumulative - thisTick.TickCumulativeOutside())
	thisTick.SetSecondsOutside(uint32(blockTimestamp) - thisTick.SecondsOutside())

	setTick(p, tick, thisTick)

	return thisTick.LiquidityNet().Clone()
}

// setTick updates the tick data for the specified tick index in the pool.
func setTick(p *pl.Pool, tick int32, newTickInfo pl.TickInfo) {
	tickStr := strconv.Itoa(int(tick))
	p.Ticks().Set(tickStr, newTickInfo)
}

// deleteTick deletes the tick data for the specified tick index in the pool.
func deleteTick(p *pl.Pool, tick int32) {
	p.DeleteTick(tick)
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
func getTick(p *pl.Pool, tick int32) pl.TickInfo {
	tickStr := formatInt(tick)
	iTickInfo, exist := p.Ticks().Get(tickStr)
	if !exist {
		return pl.NewTickInfo()
	}

	tickInfo, ok := iTickInfo.(pl.TickInfo)
	if !ok {
		panic(ufmt.Sprintf("failed to cast tickInfo to TickInfo: %T", iTickInfo))
	}

	return tickInfo
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
// ```gno
//
//	tickInfo := pool.mustGetTick(10)
//	ufmt.Println("Tick Info:", tickInfo)
//
// ```
func mustGetTick(p *pl.Pool, tick int32) *pl.TickInfo {
	tickStr := formatInt(tick)
	iTickInfo, exist := p.Ticks().Get(tickStr)
	if !exist {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("tick(%d) does not exist", tick),
		))
	}

	info, ok := iTickInfo.(pl.TickInfo)
	if !ok {
		panic("failed to cast tick info to TickInfo")
	}

	return &info
}

// calculateMaxLiquidityPerTick calculates the maximum liquidity
// per tick for a given tick spacing.
func calculateMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	// Floor MIN_TICK and MAX_TICK to the nearest multiple of tickSpacing
	// This ensures that the tick range is properly aligned with the tickSpacing
	// For example, if tickSpacing is 60 and MIN_TICK is -887272:
	// -887272 / 60 = -14787.866... -> -14787 * 60 = -887220
	minTick := (MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	return u256.Zero().Div(maxUint128FromDecimal, u256.NewUint(numTicks))
}

// getFeeGrowthBelowX128 calculates the fee growth below a specified tick.
//
// This function computes the fee growth for token 0 and token 1 below a given tick (`tickLower`)
// relative to the current tick (`tickCurrent`). The fee growth values are adjusted based on whether
// the `tickCurrent` is above or below the `tickLower`.
//
// Parameters:
//   - tickLower: int32, the lower tick boundary for fee calculation.
//   - tickCurrent: int32, the current tick index.
//   - feeGrowthGlobal0X128: *u256.Uint, the global fee growth for token 0 in X128 precision.
//   - feeGrowthGlobal1X128: *u256.Uint, the global fee growth for token 1 in X128 precision.
//   - lowerTick: TickInfo, the fee growth and liquidity details for the lower tick.
//
// Returns:
//   - *u256.Uint: Fee growth below `tickLower` for token 0.
//   - *u256.Uint: Fee growth below `tickLower` for token 1.
//
// Workflow:
//  1. If `tickCurrent` is greater than or equal to `tickLower`:
//     - Return the `feeGrowthOutside0X128` and `feeGrowthOutside1X128` values of the `lowerTick`.
//  2. If `tickCurrent` is below `tickLower`:
//     - Compute the fee growth below the lower tick by subtracting `feeGrowthOutside` values
//     from the global fee growth values (`feeGrowthGlobal0X128` and `feeGrowthGlobal1X128`).
//  3. Return the calculated fee growth values for both tokens.
//
// Behavior:
//   - If `tickCurrent >= tickLower`, the fee growth outside the lower tick is returned as-is.
//   - If `tickCurrent < tickLower`, the fee growth is calculated as:
//     feeGrowthBelow = feeGrowthGlobal - feeGrowthOutside
//
// Example:
//
// ```gno
//
//	feeGrowth0, feeGrowth1 := getFeeGrowthBelowX128(
//	    100, 150, globalFeeGrowth0, globalFeeGrowth1, lowerTickInfo,
//	)
//	println("Fee Growth Below:", feeGrowth0, feeGrowth1)
func getFeeGrowthBelowX128(
	tickLower, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	lowerTick pl.TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent >= tickLower {
		return lowerTick.FeeGrowthOutside0X128(), lowerTick.FeeGrowthOutside1X128()
	}

	feeGrowthBelow0X128 := u256.Zero().Sub(feeGrowthGlobal0X128, lowerTick.FeeGrowthOutside0X128())
	feeGrowthBelow1X128 := u256.Zero().Sub(feeGrowthGlobal1X128, lowerTick.FeeGrowthOutside1X128())

	return feeGrowthBelow0X128, feeGrowthBelow1X128
}

// getFeeGrowthAboveX128 calculates the fee growth above a specified tick.
//
// This function computes the fee growth for token 0 and token 1 above a given tick (`tickUpper`)
// relative to the current tick (`tickCurrent`). The fee growth values are adjusted based on whether
// the `tickCurrent` is above or below the `tickUpper`.
//
// Parameters:
//   - tickUpper: int32, the upper tick boundary for fee calculation.
//   - tickCurrent: int32, the current tick index.
//   - feeGrowthGlobal0X128: *u256.Uint, the global fee growth for token 0 in X128 precision.
//   - feeGrowthGlobal1X128: *u256.Uint, the global fee growth for token 1 in X128 precision.
//   - upperTick: TickInfo, the fee growth and liquidity details for the upper tick.
//
// Returns:
//   - *u256.Uint: Fee growth above `tickUpper` for token 0.
//   - *u256.Uint: Fee growth above `tickUpper` for token 1.
//
// Workflow:
//  1. If `tickCurrent` is less than `tickUpper`:
//     - Return the `feeGrowthOutside0X128` and `feeGrowthOutside1X128` values of the `upperTick`.
//  2. If `tickCurrent` is greater than or equal to `tickUpper`:
//     - Compute the fee growth above the upper tick by subtracting `feeGrowthOutside` values
//     from the global fee growth values (`feeGrowthGlobal0X128` and `feeGrowthGlobal1X128`).
//  3. Return the calculated fee growth values for both tokens.
//
// Behavior:
//   - If `tickCurrent < tickUpper`, the fee growth outside the upper tick is returned as-is.
//   - If `tickCurrent >= tickUpper`, the fee growth is calculated as:
//     feeGrowthAbove = feeGrowthGlobal - feeGrowthOutside
//
// Example:
//
//	feeGrowth0, feeGrowth1 := getFeeGrowthAboveX128(
//	    200, 150, globalFeeGrowth0, globalFeeGrowth1, upperTickInfo,
//	)
//	println("Fee Growth Above:", feeGrowth0, feeGrowth1)
//
// ```
func getFeeGrowthAboveX128(
	tickUpper, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	upperTick pl.TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent < tickUpper {
		return upperTick.FeeGrowthOutside0X128(), upperTick.FeeGrowthOutside1X128()
	}

	feeGrowthAbove0X128 := u256.Zero().Sub(feeGrowthGlobal0X128, upperTick.FeeGrowthOutside0X128())
	feeGrowthAbove1X128 := u256.Zero().Sub(feeGrowthGlobal1X128, upperTick.FeeGrowthOutside1X128())

	return feeGrowthAbove0X128, feeGrowthAbove1X128
}

// validateTicks validates the tick range for a liquidity position.
//
// This function performs three essential checks to ensure the provided
// tick values are valid before creating or modifying a liquidity position.
func validateTicks(tickLower, tickUpper int32) error {
	if tickLower >= tickUpper {
		return makeErrorWithDetails(
			errInvalidTickRange,
			ufmt.Sprintf("tickLower(%d), tickUpper(%d)", tickLower, tickUpper),
		)
	}

	if tickLower < MIN_TICK {
		return makeErrorWithDetails(
			errTickLowerInvalid,
			ufmt.Sprintf("tickLower(%d) < MIN_TICK(%d)", tickLower, MIN_TICK),
		)
	}

	if tickUpper > MAX_TICK {
		return makeErrorWithDetails(
			errTickUpperInvalid,
			ufmt.Sprintf("tickUpper(%d) > MAX_TICK(%d)", tickUpper, MAX_TICK),
		)
	}

	return nil
}
