package pool

import (
	"std"

	"gno.land/p/demo/u256"
)

type Slot0 struct {
	sqrtPriceX96 *u256.Uint
	tick         int32
	feeProtocol  uint8
	unlocked     bool
}

type Balances struct {
	token0 *u256.Uint
	token1 *u256.Uint
}

type ProtocolFees struct {
	token0 *u256.Uint
	token1 *u256.Uint
}

type ModifyPositionParams struct {
	owner          std.Address
	tickLower      int32
	tickUpper      int32
	liquidityDelta *u256.Int
}

type SwapCache struct {
	feeProtocol    uint8
	liquidityStart *u256.Uint
}

type SwapState struct {
	amountSpecifiedRemaining *u256.Int
	amountCalculated         *u256.Int 
	sqrtPriceX96             *u256.Uint
	tick                     int32
	feeGrowthGlobalX128      *u256.Uint 
	protocolFee              *u256.Uint
	liquidity                *u256.Uint 
}

type StepComputations struct {
	sqrtPriceStartX96 *u256.Uint
	tickNext          int32
	initialized       bool
	sqrtPriceNextX96  *u256.Uint
	amountIn          *u256.Uint
	amountOut         *u256.Uint
	feeAmount         *u256.Uint
}

type PositionInfo struct {
	liquidity *u256.Uint

	feeGrowthInside0LastX128 *u256.Uint 
	feeGrowthInside1LastX128 *u256.Uint

	tokensOwed0 *u256.Uint
	tokensOwed1 *u256.Uint
}

type TickInfo struct {
	liquidityGross *u256.Uint
	liquidityNet   *u256.Int

	feeGrowthOutside0X128 *u256.Uint
	feeGrowthOutside1X128 *u256.Uint

	//tickCumulativeOutside bigint

	//secondsPerLiquidityOutsideX128 bigint
	// secondsOutside                 bigint

	initialized bool
}

type Ticks map[int32]TickInfo          // tick => TickInfo
type TickBitmaps map[int16]bigint      // tick(wordPos) => bitmap(tickWord ^ mask)
type Positions map[string]PositionInfo // positionKey => PositionInfo

// type Pool describes a single Pool/s state
// A pool is identificed with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	token0Path string
	token1Path string

	balances Balances

	// fee is the fee tier of the pool
	fee uint16

	// tickSpacing is the spacing between ticks
	tickSpacing int32

	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	maxLiquidityPerTick *u256.Uint

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0X128 *u256.Uint
	feeGrowthGlobal1X128 *u256.Uint

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees ProtocolFees

	// liquidity is the total amount of liquidity in the pool
	liquidity *u256.Uint

	// ticks is a mapping from tick index to tick
	ticks Ticks

	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps TickBitmaps

	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions Positions
}
