package pool

import (
	"std"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type Slot0 struct {
	sqrtPriceX96 *u256.Uint // current price of the pool as a sqrt(token1/token0) Q96 value
	tick         int32      // current tick of the pool, i.e according to the last tick transition that was run
	feeProtocol  uint8      // protocol fee for both tokens of the pool
	unlocked     bool       // whether the pool is currently locked to reentrancy
}

type Balances struct {
	// current balance of the pool in token0/token1
	token0 *u256.Uint
	token1 *u256.Uint
}

type ProtocolFees struct {
	// current protocol fees of the pool in token0/token1
	token0 *u256.Uint
	token1 *u256.Uint
}

type ModifyPositionParams struct {
	owner std.Address // address that owns the position

	// the tick range of the position, bounds are included
	tickLower int32
	tickUpper int32

	liquidityDelta *i256.Int // any change in liquidity
}

type SwapCache struct {
	feeProtocol    uint8      // protocol fee for the input token
	liquidityStart *u256.Uint // liquidity at the beginning of the swap
}

func newSwapCache(
	feeProtocol uint8,
	liquidityStart *u256.Uint,
) SwapCache {
	return SwapCache{
		feeProtocol:    feeProtocol,
		liquidityStart: liquidityStart,
	}
}

type SwapState struct {
	amountSpecifiedRemaining *i256.Int  // amount remaining to be swapped in/out of the input/output token
	amountCalculated         *i256.Int  // amount already swapped out/in of the output/input token
	sqrtPriceX96             *u256.Uint // current sqrt(price)
	tick                     int32      // tick associated with the current sqrt(price)
	feeGrowthGlobalX128      *u256.Uint // global fee growth of the input token
	protocolFee              *u256.Uint // amount of input token paid as protocol fee
	liquidity                *u256.Uint // current liquidity in range
}

func (pool *Pool) newSwapState(
	amountSpecifiedRemaining *i256.Int,
	feeGrowthGlobalX128 *u256.Uint,
	liquidity *u256.Uint,
) SwapState {
	slot0 := pool.slot0

	return SwapState{
		amountSpecifiedRemaining: amountSpecifiedRemaining,
		amountCalculated:         i256.Zero(),
		sqrtPriceX96:             slot0.sqrtPriceX96,
		tick:                     slot0.tick,
		feeGrowthGlobalX128:      feeGrowthGlobalX128,
		protocolFee:              u256.Zero(),
		liquidity:                liquidity,
	}
}

type StepComputations struct {
	sqrtPriceStartX96 *u256.Uint // price at the beginning of the step
	tickNext          int32      // next tick to swap to from the current tick in the swap direction
	initialized       bool       // whether tickNext is initialized
	sqrtPriceNextX96  *u256.Uint // sqrt(price) for the next tick (token1/token0) Q96
	amountIn          *u256.Uint // how much being swapped in this step
	amountOut         *u256.Uint // how much is being swapped out in this step
	feeAmount         *u256.Uint // how much fee is being paid in this step
}

type PositionInfo struct {
	liquidity *u256.Uint // amount of liquidity owned by this position

	// fee growth per unit of liquidity as of the last update to liquidity or fees owed
	feeGrowthInside0LastX128 *u256.Uint
	feeGrowthInside1LastX128 *u256.Uint

	// fees owed to the position owner in token0/token1
	tokensOwed0 *u256.Uint
	tokensOwed1 *u256.Uint
}

func (p *PositionInfo) init() {
	p.liquidity = p.liquidity.NilToZero()
	p.feeGrowthInside0LastX128 = p.feeGrowthInside0LastX128.NilToZero()
	p.feeGrowthInside1LastX128 = p.feeGrowthInside1LastX128.NilToZero()
	p.tokensOwed0 = p.tokensOwed0.NilToZero()
	p.tokensOwed1 = p.tokensOwed1.NilToZero()
}

type TickInfo struct {
	liquidityGross *u256.Uint // total position liquidity that references this tick
	liquidityNet   *i256.Int  // amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left)

	// fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	feeGrowthOutside0X128 *u256.Uint
	feeGrowthOutside1X128 *u256.Uint

	tickCumulativeOutside int64 // cumulative tick value on the other side of the tick

	// the seconds per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsPerLiquidityOutsideX128 *u256.Uint

	// the seconds spent on the other side of the tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	secondsOutside uint32

	initialized bool // whether the tick is initialized
}

func (t *TickInfo) init() {
	t.liquidityGross = t.liquidityGross.NilToZero()
	t.liquidityNet = t.liquidityNet.NilToZero()
	t.feeGrowthOutside0X128 = t.feeGrowthOutside0X128.NilToZero()
	t.feeGrowthOutside1X128 = t.feeGrowthOutside1X128.NilToZero()
	t.secondsPerLiquidityOutsideX128 = t.secondsPerLiquidityOutsideX128.NilToZero()
}

type Ticks map[int32]TickInfo          // tick => TickInfo
type TickBitmaps map[int16]*u256.Uint  // tick(wordPos) => bitmap(tickWord ^ mask)
type Positions map[string]PositionInfo // positionKey => PositionInfo

// type Pool describes a single Pool's state
// A pool is identificed with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	// token0/token1 path of the pool
	token0Path string
	token1Path string

	balances Balances // balances of the pool

	fee uint32 // fee tier of the pool

	tickSpacing int32 // spacing between ticks

	maxLiquidityPerTick *u256.Uint // the maximum amount of liquidity that can be added per tick

	slot0 Slot0

	feeGrowthGlobal0X128 *u256.Uint // uint256
	feeGrowthGlobal1X128 *u256.Uint // uint256

	protocolFees ProtocolFees

	liquidity *u256.Uint // total amount of liquidity in the pool

	ticks Ticks // maps tick index to tick

	tickBitmaps TickBitmaps // maps tick index to tick bitmap

	positions Positions // maps the key (caller, lower tick, upper tick) to a unique position
}
