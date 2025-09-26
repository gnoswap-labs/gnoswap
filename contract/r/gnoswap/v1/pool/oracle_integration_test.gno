package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

// TestOracle_SwapScenarios tests oracle behavior during various swap scenarios
func TestOracle_SwapScenarios(t *testing.T) {
	// Use a fixed base time for consistent testing
	baseTime := int64(1700000000) // Fixed timestamp for testing

	tests := []struct {
		name      string
		scenarios []swapScenario
		verifyFn  func(t *testing.T, pool *Pool, scenarios []swapScenario)
	}{
		{
			name: "price movement tracking",
			scenarios: []swapScenario{
				{time: baseTime + 300, tick: 1000, liquidity: "5000000", description: "price up"},
				{time: baseTime + 600, tick: 800, liquidity: "5000000", description: "price down"},
				{time: baseTime + 900, tick: 1200, liquidity: "5000000", description: "price up again"},
			},
			verifyFn: func(t *testing.T, pool *Pool, scenarios []swapScenario) {				
				// Now calculate TWAP from the beginning
				// We can't use GetTWAP directly because it uses time.Now()
				// Instead, we'll test the observation data directly
				obs := pool.observationState.lastObservation()
				firstObs := pool.observationState.observations[0]
				
				// Calculate TWAP manually
				tickDelta := obs.tickCumulative - firstObs.tickCumulative
				timeDelta := obs.blockTimestamp - firstObs.blockTimestamp
				if timeDelta > 0 {
					twap := int32(tickDelta / timeDelta)
					uassert.True(t, twap >= -887220 && twap <= 887220, 
						ufmt.Sprintf("TWAP %d should be within valid tick range", twap))
				}
			},
		},
		{
			name: "liquidity changes tracking",
			scenarios: []swapScenario{
				{time: baseTime + 300, tick: 1000, liquidity: "2000000", description: "liquidity doubled"},
				{time: baseTime + 600, tick: 1500, liquidity: "2000000", description: "price change"},
				{time: baseTime + 900, tick: 1500, liquidity: "500000", description: "liquidity reduced"},
			},
			verifyFn: func(t *testing.T, pool *Pool, scenarios []swapScenario) {
				// Query observations to verify liquidity accumulation
				secondsAgos := []uint32{0, 300, 600, 900}
				_, liquidityCumulatives, err := pool.observationState.observe(
					baseTime + 900, 
					secondsAgos, 
					pool.slot0.tick, 
					pool.observationState.index, 
					pool.liquidity, 
					pool.observationState.cardinality,
				)
				uassert.NoError(t, err, "Observe should succeed")
				
				// Verify liquidity cumulative is monotonically increasing
				for i := 1; i < len(liquidityCumulatives); i++ {
					uassert.True(t, liquidityCumulatives[i-1].Gte(liquidityCumulatives[i]),
						"Liquidity cumulative should be non-decreasing forward in time")
				}
			},
		},
		{
			name: "zero liquidity handling",
			scenarios: []swapScenario{
				{time: baseTime + 300, tick: 1500, liquidity: "0", description: "tick remains same with zero liquidity"},
			},
			verifyFn: func(t *testing.T, pool *Pool, scenarios []swapScenario) {
				obs := pool.observationState.lastObservation()
				
				expectedTickCumulative := int64(1500 * 300)  // 450000
				uassert.Equal(t, expectedTickCumulative, obs.tickCumulative,
					"Tick cumulative should accumulate even with zero liquidity")
				
				// Liquidity cumulative should remain zero
				uassert.Equal(t, "0", obs.LiquidityCumulative(),
					"Liquidity cumulative should remain zero")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := createTestPoolWithLiquidity()
			pool.IncreaseObservationCardinalityLimit(10)
			
			// Process scenarios
			for i, scenario := range tt.scenarios {
				if i == 0 || scenario.liquidity != tt.scenarios[i-1].liquidity {
					pool.liquidity = u256.MustFromDecimal(scenario.liquidity)
				}

				// writeObservation will initialize observation state if needed
				err := pool.writeObservation(scenario.time, scenario.tick, pool.liquidity)
				uassert.NoError(t, err, ufmt.Sprintf("Observation at %s should succeed", scenario.description))
			}
			
			// Run verification function
			tt.verifyFn(t, pool, tt.scenarios)
		})
	}
}

// Helper types for test scenarios
type swapScenario struct {
	time        int64
	tick        int32
	liquidity   string
	description string
}

type observationSetup struct {
	time int64
	tick int32
}

type interpolationQuery struct {
	secondsAgo  uint32
	expectExact bool
	description string
}

// Helper function to create a test pool with initial liquidity
func createTestPoolWithLiquidity() *Pool {
	baseTime := int64(1700000000)
	return &Pool{
		token0Path: "gno.land/r/onbloc/foo",
		token1Path: "gno.land/r/onbloc/bar",
		fee:        500,
		slot0: Slot0{
			sqrtPriceX96: u256.MustFromDecimal("79228162514264337593543950336"),
			tick:         0,
			unlocked:     true,
		},
		liquidity:        u256.MustFromDecimal("5000000"),
		observationState: newObservationState(baseTime),
	}
}