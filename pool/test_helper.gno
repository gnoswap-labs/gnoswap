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
func (pool *Pool) GetMaxLiquidityPerTick() bigint {
	return pool.maxLiquidityPerTick
}

func (pool *Pool) GetLiquidity() bigint {
	return pool.liquidity
}

func (pool *Pool) GetFee() bigint {
	return pool.fee
}

func (pool *Pool) GetTickSpacing() bigint {
	return pool.tickSpacing
}

func (pool *Pool) GetFeeGrowthGlobal0X128() bigint {
	return pool.feeGrowthGlobal0X128
}

func (pool *Pool) GetFeeGrowthGlobal1X128() bigint {
	return pool.feeGrowthGlobal1X128
}

func (pool *Pool) GetSlot0() Slot0 {
	return pool.slot0
}

func (pool *Pool) GetProtocolFees() ProtocolFees {
	return pool.protocolFees
}

func (pool *Pool) GetPosition(key string) PositionInfo {
	return pool.positions[key]
}

func (pool *Pool) GetTick(key bigint) TickInfo {
	return pool.ticks[key]
}

func (pool *Pool) GetTicks() map[bigint]TickInfo {
	return pool.ticks
}

func (pool *Pool) GetTickBitmap(key bigint) bigint {
	return pool.tickBitmaps[key]
}

func (pool *Pool) GetSqrtPriceX96() bigint {
	return pool.slot0.sqrtPriceX96
}

func Abs(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}