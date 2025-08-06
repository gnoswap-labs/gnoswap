package pool

import (
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestPool_CalculatePriceCumulatives(t *testing.T) {
	tests := []struct {
		name        string
		pool        *Pool
		currentTime int64
		want        struct {
			sqrtPriceCumulative *u256.Uint
			liquidityCumulative *u256.Uint
			lastUpdateTime      int64
		}
	}{
		{
			name: "Time elapsed - 50 seconds",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000), // Price
				},
				twap: TWAP{
					lastCumulativeUpdateTime: 100,
					sqrtPriceCumulativeX96:   u256.NewUint(5000000000),
					liquidityCumulative:      u256.NewUint(3000000),
				},
				liquidity: u256.NewUint(1000000), // Liquidity
			},
			currentTime: 150, // 50 seconds elapsed
			want: struct {
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				// Previous cumulative + (price * timeDelta)
				sqrtPriceCumulative: u256.NewUint(105000000000),
				// Previous cumulative + (liquidity * timeDelta)
				liquidityCumulative: u256.NewUint(53000000),
				lastUpdateTime:      150,
			},
		},
		{
			name: "Initial update",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				twap: TWAP{
					lastCumulativeUpdateTime: 0,
					sqrtPriceCumulativeX96:   u256.Zero(),
					liquidityCumulative:      u256.Zero(),
				},
				liquidity: u256.NewUint(1000000),
			},
			currentTime: 100,
			want: struct {
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				sqrtPriceCumulative: u256.NewUint(200000000000),
				liquidityCumulative: u256.NewUint(100000000),
				lastUpdateTime:      100,
			},
		},
		{
			name: "Zero liquidity pool",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				twap: TWAP{
					lastCumulativeUpdateTime: 100,
					sqrtPriceCumulativeX96:   u256.NewUint(5000000000),
					liquidityCumulative:      u256.NewUint(3000000),
				},
				liquidity: u256.Zero(),
			},
			currentTime: 150,
			want: struct {
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				sqrtPriceCumulative: u256.NewUint(105000000000),
				liquidityCumulative: u256.NewUint(3000000),
				lastUpdateTime:      150,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqrtPriceCumulative, liquidityCumulative, lastUpdateTime := tt.pool.calculatePriceCumulatives(tt.currentTime)

			uassert.Equal(t, sqrtPriceCumulative.ToString(), tt.want.sqrtPriceCumulative.ToString(), "sqrtPriceCumulative")
			uassert.Equal(t, liquidityCumulative.ToString(), tt.want.liquidityCumulative.ToString(), "liquidityCumulative")
			uassert.Equal(t, lastUpdateTime, tt.want.lastUpdateTime, "lastUpdateTime")
		})
	}
}

func TestPool_UpdatePriceCumulatives(t *testing.T) {
	tests := []struct {
		name        string
		pool        *Pool
		currentTime int64
		want        struct {
			sqrtPriceCumulative *u256.Uint
			liquidityCumulative *u256.Uint
			lastUpdateTime      int64
		}
	}{
		{
			name: "Initial update with zero time",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000), // Example price
				},
				liquidity: u256.NewUint(1000000), // Example liquidity
				twap: TWAP{
					sqrtPriceCumulativeX96: u256.Zero(),
					liquidityCumulative:    u256.Zero(),
				},
			},
			currentTime: 0,
			want: struct {
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				sqrtPriceCumulative: u256.Zero(),
				liquidityCumulative: u256.Zero(),
				lastUpdateTime:      0,
			},
		},
		{
			name: "Update after time elapsed",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				twap: TWAP{
					lastCumulativeUpdateTime: 100,
					sqrtPriceCumulativeX96:   u256.Zero(),
					liquidityCumulative:      u256.Zero(),
				},
				liquidity: u256.NewUint(1000000),
			},
			currentTime: 200,
			want: struct {
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				sqrtPriceCumulative: u256.NewUint(200000000000), // price * time elapsed
				liquidityCumulative: u256.NewUint(100000000),    // liquidity * time elapsed
				lastUpdateTime:      200,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.pool.updatePriceCumulatives(tt.currentTime)

			twap := tt.pool.TWAP()

			uassert.Equal(t, twap.SqrtPriceCumulativeX96(), tt.want.sqrtPriceCumulative.ToString())
			uassert.Equal(t, twap.LiquidityCumulative(), tt.want.liquidityCumulative.ToString())
			uassert.Equal(t, twap.lastCumulativeUpdateTime, tt.want.lastUpdateTime)
		})
	}
}
