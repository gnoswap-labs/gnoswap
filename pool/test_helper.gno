package gnoswap

import (
	"gno.land/p/demo/avl"
)

// Testing
func GetMaxLiquidityPerTick() bigint {
	return maxLiquidityPerTick
}

func GetLiquidity() bigint {
	return liquidity
}

func GetFee() bigint {
	return fee
}

func GetTickSpacing() bigint {
	return tickSpacing
}

func GetFeeGrowthGlobal0X128() bigint {
	return feeGrowthGlobal0X128
}

func GetFeeGrowthGlobal1X128() bigint {
	return feeGrowthGlobal1X128
}

func GetSlot0() Slot0 {
	return slot0
}

func GetProtocolFees() ProtocolFees {
	return protocolFees
}

func GetPosition(key string) PositionInfo {
	// return positions[key]
	position, exists := positions.Get(key).(PositionInfo)
	if !exists {
		panic("position does not exist #3")
	}
	return position
}

// func GetPositions() map[string]PositionInfo {
func GetPositions() avl.Tree {
	return positions
}

func GetTick(key string) TickInfo {
	// return ticks[key]
	tick, exists := ticks.Get(key).(TickInfo)
	if !exists {
		panic("tick does not exist")
	}
	return tick
}

// func GetTicks() map[bigint]TickInfo {
func GetTicks() avl.Tree {
	return ticks
}

func GetTickBitmap(key string) bigint {
	// return tickBitmaps[key]
	tickBitmap, exists := tickBitmaps.Get(key).(bigint)
	if !exists {
		panic("tickBitmap does not exist")
	}
	return tickBitmap
}

// func GetTickBitmaps() map[bigint]bigint {
func GetTickBitmaps() avl.Tree {
	return tickBitmaps
}

func GetSqrtPriceX96() bigint {
	return slot0.sqrtPriceX96
}

func Abs(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}
