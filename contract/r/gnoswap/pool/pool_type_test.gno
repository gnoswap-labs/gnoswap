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
			tickCumulative      int64
			liquidityCumulative *u256.Uint
			lastUpdateTime      int64
		}
	}{
		{
			name: "Time elapsed - 50 seconds",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000), // Price
					tick:         100,
				},
				observation: &Observation{
					lastCumulativeUpdateTime: 100,
					tickCumulative:           5000000000,
					liquidityCumulative:      u256.NewUint(3000000),
				},
				liquidity: u256.NewUint(1000000), // Liquidity
			},
			currentTime: 150, // 50 seconds elapsed
			want: struct {
				tickCumulative      int64
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				// Previous cumulative + (price * timeDelta)
				tickCumulative: 5000005000,
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
					tick:         100,
				},
				observation: &Observation{
					lastCumulativeUpdateTime: 0,
					tickCumulative:           0,
					liquidityCumulative:      u256.Zero(),
				},
				liquidity: u256.NewUint(1000000),
			},
			currentTime: 100,
			want: struct {
				tickCumulative      int64
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				tickCumulative:      10000,
				liquidityCumulative: u256.NewUint(100000000),
				lastUpdateTime:      100,
			},
		},
		{
			name: "Zero liquidity pool",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
					tick:         100,
				},
				observation: &Observation{
					lastCumulativeUpdateTime: 100,
					tickCumulative:           5000000000,
					liquidityCumulative:      u256.NewUint(3000000),
				},
				liquidity: u256.Zero(),
			},
			currentTime: 150,
			want: struct {
				tickCumulative      int64
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				tickCumulative:      5000005000,
				liquidityCumulative: u256.NewUint(3000000),
				lastUpdateTime:      150,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tickCumulative, liquidityCumulative, lastUpdateTime := tt.pool.calculateTickCumulative(tt.currentTime)

			uassert.Equal(t, tickCumulative, tt.want.tickCumulative, "tickCumulative")
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
			tickCumulative      int64
			liquidityCumulative *u256.Uint
			lastUpdateTime      int64
		}
	}{
		{
			name: "Initial update with zero time",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000), // Example price
					tick:         100,
				},
				liquidity: u256.NewUint(1000000), // Example liquidity
				observation: &Observation{
					lastCumulativeUpdateTime: 0,
					tickCumulative:           0,
					liquidityCumulative:      u256.Zero(),
				},
			},
			currentTime: 0,
			want: struct {
				tickCumulative      int64
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				tickCumulative:      0,
				liquidityCumulative: u256.Zero(),
				lastUpdateTime:      0,
			},
		},
		{
			name: "Update after time elapsed",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
					tick:         100,
				},
				observation: &Observation{
					lastCumulativeUpdateTime: 100,
					tickCumulative:           0,
					liquidityCumulative:      u256.Zero(),
				},
				liquidity: u256.NewUint(1000000),
			},
			currentTime: 200,
			want: struct {
				tickCumulative      int64
				liquidityCumulative *u256.Uint
				lastUpdateTime      int64
			}{
				tickCumulative:      10000,                   // price * time elapsed
				liquidityCumulative: u256.NewUint(100000000), // liquidity * time elapsed
				lastUpdateTime:      200,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.pool.updatePriceCumulatives(tt.currentTime)

			observation := tt.pool.Observation()

			uassert.Equal(t, observation.TickCumulative(), tt.want.tickCumulative)
			uassert.Equal(t, observation.LiquidityCumulative(), tt.want.liquidityCumulative.ToString())
			uassert.Equal(t, observation.LastCumulativeUpdateTime(), tt.want.lastUpdateTime)
		})
	}
}
