package gnoswap

import (
	"gno.land/p/demo/avl"
	"testing"
)


func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}


func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}


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
	if (!exists) {
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
	if (!exists) {
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
	if (!exists) {
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