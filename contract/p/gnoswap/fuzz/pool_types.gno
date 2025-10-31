package fuzz

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type PoolState struct {
	// Basic configuration
	Token0Path  string
	Token1Path  string
	Fee         uint32
	TickSpacing int32

	// Current state
	CurrentPrice     *u256.Uint // sqrtPriceX96
	CurrentTick      int32
	CurrentLiquidity *u256.Uint
	Unlocked         bool

	// Balances and fees
	Balance0     *u256.Uint
	Balance1     *u256.Uint
	ProtocolFee0 *u256.Uint
	ProtocolFee1 *u256.Uint
	FeeProtocol  uint8

	// Accumulated fees
	FeeGrowthGlobal0X128 *u256.Uint
	FeeGrowthGlobal1X128 *u256.Uint

	// Position and tick data (simplified)
	Positions   map[string]*PositionState // key: "owner:tickLower:tickUpper"
	ActiveTicks map[int32]bool            // only tracking active ticks for efficiency

	// Oracle state (optional)
	LastObservationTimestamp int64
	LastTickCumulative       int64
}

type PositionState struct {
	Owner     string
	TickLower int32
	TickUpper int32
	Liquidity *u256.Uint

	// fee tracking
	FeeGrowthInside0X128 *u256.Uint
	FeeGrowthInside1X128 *u256.Uint
	TokensOwed0          *u256.Uint
	TokensOwed1          *u256.Uint
}

type TickState struct {
	LiquidityGross *u256.Uint
	LiquidityNet   *i256.Int
	Initialized    bool

	// fee tracking (optional)
	FeeGrowthOutside0X128 *u256.Uint
	FeeGrowthOutside1X128 *u256.Uint
}

type SwapState struct {
	AmountSpecifiedRemaining *i256.Int
	AmountCalculated         *i256.Int
	SprtPriceX96             *u256.Uint
	Tick                     int32
	Liquidity                *u256.Uint
	FeeGrowthGlobal0X128     *u256.Uint
	FeeGrowthGlobalX128      *u256.Uint
}

type MockPoolConfig struct {
	// initial pool state
	initialPrice     string
	initialLiquidity string

	// liquidity ranges
	liquidityRanges []LiquidityRange

	// acting modes
	EnableProtocolFee bool
	ProtocolFeeRatio  uint8

	// scenarios
	FailOnSwapAmount *u256.Uint // failed on specific swap amount
	FailOnTick       *int32     // failed on specific tick
}

type LiquidityRange struct {
	TickLower int32
	TickUpper int32
	Liquidity string
	Owner     string
}
