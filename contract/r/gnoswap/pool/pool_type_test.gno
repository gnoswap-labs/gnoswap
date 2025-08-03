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
				liquidity:                u256.NewUint(1000000), // Liquidity
				lastCumulativeUpdateTime: 100,
				sqrtPriceCumulativeX96:   u256.NewUint(5000000000),
				liquidityCumulative:      u256.NewUint(3000000),
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
				lastUpdateTime: 150,
			},
		},
		{
			name: "Initial update",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				liquidity:                u256.NewUint(1000000),
				lastCumulativeUpdateTime: 0,
				sqrtPriceCumulativeX96:   u256.Zero(),
				liquidityCumulative:      u256.Zero(),
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
				liquidity:                u256.Zero(),
				lastCumulativeUpdateTime: 100,
				sqrtPriceCumulativeX96:   u256.NewUint(5000000000),
				liquidityCumulative:      u256.NewUint(3000000),
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
	// Test cases
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
				liquidity:                u256.NewUint(1000000),
				lastCumulativeUpdateTime: 100,
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

	// Run tests
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.pool.updatePriceCumulatives(tt.currentTime)

			if !tt.pool.sqrtPriceCumulativeX96.Eq(tt.want.sqrtPriceCumulative) {
				t.Errorf("sqrtPriceCumulativeX96 = %v, want %v", tt.pool.sqrtPriceCumulativeX96, tt.want.sqrtPriceCumulative)
			}
			if !tt.pool.liquidityCumulative.Eq(tt.want.liquidityCumulative) {
				t.Errorf("liquidityCumulative = %v, want %v", tt.pool.liquidityCumulative, tt.want.liquidityCumulative)
			}
			if tt.pool.lastCumulativeUpdateTime != tt.want.lastUpdateTime {
				t.Errorf("lastCumulativeUpdateTime = %v, want %v", tt.pool.lastCumulativeUpdateTime, tt.want.lastUpdateTime)
			}
		})
	}
}

func TestPool_Observe(t *testing.T) {
	tests := []struct {
		name        string
		pool        *Pool
		secondsAgo  int64
		currentTime int64
		wantPrice   *u256.Uint
		wantErr     bool
	}{
		{
			name: "Invalid seconds ago",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				liquidity: u256.NewUint(1000000),
				liquidityCumulative:      u256.NewUint(100000000),
				sqrtPriceCumulativeX96:   u256.NewUint(400000000000),
				lastCumulativeUpdateTime: 100,
			},
			secondsAgo:  0,
			currentTime: 100,
			wantPrice:   nil,
			wantErr:     true,
		},
		{
			name: "No past observation",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				liquidity: u256.NewUint(1000000),
				liquidityCumulative:      u256.NewUint(100000000),
				sqrtPriceCumulativeX96:   u256.NewUint(400000000000),
				lastCumulativeUpdateTime: 0,
			},
			secondsAgo:  10,
			currentTime: 100,
			wantPrice:   u256.NewUint(2000000000),
			wantErr:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			price, err := tt.pool.observe(tt.secondsAgo, tt.currentTime)

			if tt.wantErr {
				if err == nil {
					t.Error("Expected error but got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("Unexpected error: %v", err)
				return
			}

			if !price.Eq(tt.wantPrice) {
				t.Errorf("TWAP price = %v, want %v", price, tt.wantPrice)
			}
		})
	}
}

func TestPool_Slot0PriceOracle(t *testing.T) {
	tests := []struct {
		name        string
		pool        *Pool
		currentTime int64
		want        struct {
			lastUpdateTime      int64
			sqrtPriceCumulative *u256.Uint
			liquidityCumulative *u256.Uint
		}
	}{
		{
			name: "Get current oracle state",
			pool: &Pool{
				slot0: Slot0{
					sqrtPriceX96: u256.NewUint(2000000000),
				},
				liquidity:                u256.NewUint(1000000),
				lastCumulativeUpdateTime: 100,
				sqrtPriceCumulativeX96:   u256.NewUint(200000000000),
				liquidityCumulative:      u256.NewUint(100000000),
			},
			currentTime: 200,
			want: struct {
				lastUpdateTime      int64
				sqrtPriceCumulative *u256.Uint
				liquidityCumulative *u256.Uint
			}{
				lastUpdateTime:      200,
				sqrtPriceCumulative: u256.NewUint(400000000000),
				liquidityCumulative: u256.NewUint(200000000),
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lastUpdateTime, sqrtPriceCumulative, liquidityCumulative := tt.pool.slot0PriceOracle(tt.currentTime)

			if lastUpdateTime != tt.want.lastUpdateTime {
				t.Errorf("lastUpdateTime = %v, want %v", lastUpdateTime, tt.want.lastUpdateTime)
			}
			if !sqrtPriceCumulative.Eq(tt.want.sqrtPriceCumulative) {
				t.Errorf("sqrtPriceCumulative = %v, want %v", sqrtPriceCumulative, tt.want.sqrtPriceCumulative)
			}
			if !liquidityCumulative.Eq(tt.want.liquidityCumulative) {
				t.Errorf("liquidityCumulative = %v, want %v", liquidityCumulative, tt.want.liquidityCumulative)
			}
		})
	}
}
