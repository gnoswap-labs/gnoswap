// only for unit test
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

func shouldGTE(t *testing.T, l, r interface{}) {
	if !(l >= r) {
		t.Errorf("expected %v >= %v", l, r)
	}
}

func shouldLTE(t *testing.T, l, r interface{}) {
	if !(l <= r) {
		t.Errorf("expected %v <= %v", l, r)
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

// SWAP Testing
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

func GetFeeGrowthGlobal0() bigint {
	return feeGrowthGlobal0
}

func GetFeeGrowthGlobal1() bigint {
	return feeGrowthGlobal1
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

func GetTicks(key bigint) TickInfo {
	return ticks[key]
}

func GetTickBitmap(key bigint) bigint {
	return tickBitmaps[key]
}

func GetSqrtPrice() bigint {
	return slot0.sqrtPrice
}

