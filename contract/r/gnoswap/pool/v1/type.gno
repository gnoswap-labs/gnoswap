package v1

import (
	"time"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	pl "gno.land/r/gnoswap/pool"
)

// ModifyPositionParams repersents the parameters for modifying a liquidity position.
// This structure is used internally both `Mint` and `Burn` operation to manage
// the liquidity positions.
type ModifyPositionParams struct {
	// owner is the address that owns the position
	owner address

	// tickLower and atickUpper define the price range
	// The actual price range is calculated as 1.0001^tick
	// This allows for precision in price range while using integer math.

	tickLower int32 // lower tick of the position
	tickUpper int32 // upper tick of the position

	// liquidityDelta represents the change in liquidity
	// Positive for minting, negative for burning
	liquidityDelta *i256.Int
}

// newModifyPositionParams creates a new `ModifyPositionParams` instance.
// This is used to preare parameters for the `modifyPosition` function,
// which handles both minting and burning of liquidity positions.
//
// Parameters:
//   - owner: address that will own (or owns) the position
//   - tickLower: lower tick bound of the position
//   - tickUpper: upper tick bound of the position
//   - liquidityDelta: amount of liquidity to add (positive) or remove (negative)
//
// The tick parameters represent prices as powers of 1.0001:
// - actual_price = 1.0001^tick
// - For example, tick = 100 means price = 1.0001^100
//
// Returns:
//   - ModifyPositionParams: a new instance of ModifyPositionParams
func newModifyPositionParams(
	owner address,
	tickLower int32,
	tickUpper int32,
	liquidityDelta *i256.Int,
) ModifyPositionParams {
	return ModifyPositionParams{
		owner:          owner,
		tickLower:      tickLower,
		tickUpper:      tickUpper,
		liquidityDelta: liquidityDelta,
	}
}

// SwapCache holds data that remains constant throughout a swap.
type SwapCache struct {
	feeProtocol                       uint8      // protocol fee for the input token
	liquidityStart                    *u256.Uint // liquidity at the beginning of the swap
	blockTimestamp                    int64      // current block timestamp
	tickCumulative                    int64      // current tick accumulator value
	secondsPerLiquidityCumulativeX128 *u256.Uint // current seconds per liquidity accumulator
	computedLatestObservation         bool       // whether we've computed the above accumulators
}

func newSwapCache(
	feeProtocol uint8,
	liquidityStart *u256.Uint,
) *SwapCache {
	return &SwapCache{
		feeProtocol:                       feeProtocol,
		liquidityStart:                    liquidityStart,
		blockTimestamp:                    time.Now().Unix(),
		tickCumulative:                    0,
		secondsPerLiquidityCumulativeX128: u256.Zero(),
		computedLatestObservation:         false,
	}
}

// SwapState tracks the changing values during a swap.
// This type helps manage the state transitions that occur as the swap progresses
// across different price ranges.
type SwapState struct {
	amountSpecifiedRemaining *i256.Int  // amount remaining to be swapped in/out of the input/output token
	amountCalculated         *i256.Int  // amount already swapped out/in of the output/input token
	sqrtPriceX96             *u256.Uint // current sqrt(price)
	tick                     int32      // tick associated with the current sqrt(price)
	feeGrowthGlobalX128      *u256.Uint // global fee growth of the input token
	protocolFee              *u256.Uint // amount of input token paid as protocol fee
	liquidity                *u256.Uint // current liquidity in range
}

func newSwapState(
	amountSpecifiedRemaining *i256.Int,
	feeGrowthGlobalX128 *u256.Uint,
	liquidity *u256.Uint,
	slot0 pl.Slot0,
) SwapState {
	return SwapState{
		amountSpecifiedRemaining: amountSpecifiedRemaining,
		amountCalculated:         i256.Zero(),
		sqrtPriceX96:             slot0.SqrtPriceX96(),
		tick:                     slot0.Tick(),
		feeGrowthGlobalX128:      feeGrowthGlobalX128,
		protocolFee:              u256.Zero(),
		liquidity:                liquidity,
	}
}

func (s *SwapState) setSqrtPriceX96(sqrtPriceX96 *u256.Uint) {
	s.sqrtPriceX96 = sqrtPriceX96.Clone()
}

func (s *SwapState) setTick(tick int32) {
	s.tick = tick
}

func (s *SwapState) setFeeGrowthGlobalX128(feeGrowthGlobalX128 *u256.Uint) {
	s.feeGrowthGlobalX128 = feeGrowthGlobalX128
}

func (s *SwapState) setProtocolFee(fee *u256.Uint) {
	s.protocolFee = fee
}

// StepComputations holds intermediate values used during a single step of a swap.
// Each step represents movement from the current tick to the next initialized tick
// or the target price, whichever comes first.
type StepComputations struct {
	sqrtPriceStartX96 *u256.Uint // price at the beginning of the step
	tickNext          int32      // next tick to swap to from the current tick in the swap direction
	initialized       bool       // whether tickNext is initialized
	sqrtPriceNextX96  *u256.Uint // sqrt(price) for the next tick (token1/token0) Q96
	amountIn          *u256.Uint // how much being swapped in this step
	amountOut         *u256.Uint // how much is being swapped out in this step
	feeAmount         *u256.Uint // how much fee is being paid in this step
}

// init initializes the computation for a single swap step
func (step *StepComputations) initSwapStep(state SwapState, p *pl.Pool, zeroForOne bool) {
	step.sqrtPriceStartX96 = state.sqrtPriceX96
	step.tickNext, step.initialized = tickBitmapNextInitializedTickWithInOneWord(
		p,
		state.tick,
		p.TickSpacing(),
		zeroForOne,
	)

	// prevent overshoot the min/max tick
	step.clampTickNext()

	// get the price for the next tick
	step.sqrtPriceNextX96 = common.TickMathGetSqrtRatioAtTick(step.tickNext)
}

// clampTickNext ensures that `tickNext` stays within the min, max tick boundaries
// as the tick bitmap is not aware of these bounds
func (step *StepComputations) clampTickNext() {
	if step.tickNext < MIN_TICK {
		step.tickNext = MIN_TICK
	} else if step.tickNext > MAX_TICK {
		step.tickNext = MAX_TICK
	}
}

func newPool(poolInfo *poolCreateConfig) *pl.Pool {
	maxLiquidityPerTick := calculateMaxLiquidityPerTick(poolInfo.tickSpacing)
	tick := common.TickMathGetTickAtSqrtRatio(poolInfo.SqrtPriceX96())

	return pl.NewPool(
		poolInfo.Token0Path(),
		poolInfo.Token1Path(),
		poolInfo.Fee(),
		poolInfo.SqrtPriceX96(),
		poolInfo.TickSpacing(),
		tick,
		poolInfo.slot0FeeProtocol,
		maxLiquidityPerTick,
	)
}
