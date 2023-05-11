package gnoswap

import (
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
	return positions[key]
}

func GetPositions() map[string]PositionInfo {
	return positions
}

func GetTick(key bigint) TickInfo {
	return ticks[key]
}

func GetTicks() map[bigint]TickInfo {
	return ticks
}

func GetTickBitmap(key bigint) bigint {
	return tickBitmaps[key]
}

func GetTickBitmaps() map[bigint]bigint {
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