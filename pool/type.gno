package pool

import (
	"std"

	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
)

type Slot0 struct {
	sqrtPriceX96 *u256.Uint // uint160
	tick         int32
	feeProtocol  uint8
	unlocked     bool
}

type Balances struct {
	token0 *u256.Uint
	token1 *u256.Uint
}

type ProtocolFees struct {
	token0 *u256.Uint // uint128
	token1 *u256.Uint // uint128
}

type ModifyPositionParams struct {
	owner          std.Address
	tickLower      int32
	tickUpper      int32
	liquidityDelta *i256.Int // int128
}

type SwapCache struct {
	feeProtocol    uint8
	liquidityStart *u256.Uint // uint128
}

type SwapState struct {
	amountSpecifiedRemaining *i256.Int  // int256
	amountCalculated         *i256.Int  // int256
	sqrtPriceX96             *u256.Uint // uint160
	tick                     int32
	feeGrowthGlobalX128      *u256.Uint // uint256
	protocolFee              *u256.Uint // uint128
	liquidity                *u256.Uint // uint128
}

type StepComputations struct {
	sqrtPriceStartX96 *u256.Uint // uint160
	tickNext          int32
	initialized       bool
	sqrtPriceNextX96  *u256.Uint // uint160
	amountIn          *u256.Uint // uint256
	amountOut         *u256.Uint // uint256
	feeAmount         *u256.Uint // uint256
}

type PositionInfo struct {
	liquidity *u256.Uint // uint128

	feeGrowthInside0LastX128 *u256.Uint // uint256
	feeGrowthInside1LastX128 *u256.Uint // uint256

	tokensOwed0 *u256.Uint // uint128
	tokensOwed1 *u256.Uint // uint128
}

type TickInfo struct {
	liquidityGross *u256.Uint // uint128
	liquidityNet   *i256.Int  // int128

	feeGrowthOutside0X128 *u256.Uint // uint256
	feeGrowthOutside1X128 *u256.Uint // uint256

	tickCumulativeOutside int64 // int56

	secondsPerLiquidityOutsideX128 *u256.Uint // uint160
	secondsOutside                 uint32     // uint32

	initialized bool
}

type Ticks map[int32]TickInfo          // tick => TickInfo
type TickBitmaps map[int16]*u256.Uint  // tick(wordPos) => bitmap(tickWord ^ mask)
type Positions map[string]PositionInfo // positionKey => PositionInfo

// type Pool describes a single Pool/s state
// A pool is identificed with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	token0Path string
	token1Path string

	balances Balances

	// fee is the fee tier of the pool
	fee uint32

	// tickSpacing is the spacing between ticks
	tickSpacing int32

	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	maxLiquidityPerTick *u256.Uint // uint128

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0X128 *u256.Uint // uint256
	feeGrowthGlobal1X128 *u256.Uint // uint256

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees ProtocolFees

	// liquidity is the total amount of liquidity in the pool
	liquidity *u256.Uint // uint128

	// ticks is a mapping from tick index to tick
	ticks Ticks

	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps TickBitmaps

	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions Positions
}
