package pool

import (
	"std"
)

type Slot0 struct {
	sqrtPriceX96 bigint
	tick         int32
	feeProtocol  uint8
	unlocked     bool
}

type Balances struct {
	token0 bigint
	token1 bigint
}

type ProtocolFees struct {
	token0 bigint
	token1 bigint
}

type ModifyPositionParams struct {
	owner          std.Address
	tickLower      int32
	tickUpper      int32
	liquidityDelta bigint
}

type SwapCache struct {
	feeProtocol    uint8
	liquidityStart bigint
}

func newSwapCache(feeProtocol uint8, liquidityStart bigint) SwapCache {
	return SwapCache{
		feeProtocol:    feeProtocol,
		liquidityStart: liquidityStart,
	}
}

type SwapDirection struct {
	feeProtocol          uint8
	feeGrowthGlobalX128 bigint
}

func newSwapDirection(feeProtocol uint8, feeGrowthGlobalX128 bigint) SwapDirection {
	return SwapDirection{
		feeProtocol:          feeProtocol,
		feeGrowthGlobalX128: feeGrowthGlobalX128,
	}
}

type SwapState struct {
	amountSpecifiedRemaining bigint
	amountCalculated         bigint
	sqrtPriceX96             bigint
	tick                     int32
	feeGrowthGlobalX128      bigint
	protocolFee              bigint
	liquidity                bigint
}

func newSwapState(
	pool *Pool,
	remaining bigint,
	feeGrowthGlobalX128 bigint,
	liquidity bigint,
) SwapState {
	slot0 := pool.slot0

	return SwapState{
		amountSpecifiedRemaining: remaining,
		amountCalculated:         0,
		sqrtPriceX96:             slot0.sqrtPriceX96,
		tick:                     slot0.tick,
		feeGrowthGlobalX128:      feeGrowthGlobalX128,
		protocolFee:              0,
		liquidity:                liquidity,
	}
}

type StepComputations struct {
	sqrtPriceStartX96 bigint
	tickNext          int32
	initialized       bool
	sqrtPriceNextX96  bigint
	amountIn          bigint
	amountOut         bigint
	feeAmount         bigint
}

type PositionInfo struct {
	liquidity bigint

	feeGrowthInside0LastX128 bigint
	feeGrowthInside1LastX128 bigint

	tokensOwed0 bigint
	tokensOwed1 bigint
}

type TickInfo struct {
	liquidityGross bigint
	liquidityNet   bigint

	feeGrowthOutside0X128 bigint
	feeGrowthOutside1X128 bigint

	tickCumulativeOutside bigint

	secondsPerLiquidityOutsideX128 bigint
	secondsOutside                 bigint

	initialized bool
}

type (
	Ticks       map[int32]TickInfo // tick => TickInfo
	TickBitmaps map[int16]bigint   // tick(wordPos) => bitmap(tickWord ^ mask)
	Positions   map[string]PositionInfo // positionKey => PositionInfo
)

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
	maxLiquidityPerTick bigint

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0X128 bigint
	feeGrowthGlobal1X128 bigint

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees ProtocolFees

	// liquidity is the total amount of liquidity in the pool
	liquidity bigint

	// ticks is a mapping from tick index to tick
	ticks Ticks

	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps TickBitmaps

	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions Positions
}
