package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
)

// TestObservationState_Write tests basic write operations on ObservationState
func TestObservationState_Write(t *testing.T) {
	currentTime := time.Now().Unix()

	tests := []struct {
		name                   string
		initialTime            int64
		writes                 []writeOperation
		expectedIndex          uint16
		expectedCardinality    uint16
		expectedTickCumulative int64
		expectError            bool
	}{
		{
			name:                   "initial state",
			initialTime:            currentTime,
			writes:                 []writeOperation{},
			expectedIndex:          0,
			expectedCardinality:    1,
			expectedTickCumulative: 0,
			expectError:            false,
		},
		{
			name:        "single write",
			initialTime: currentTime,
			writes: []writeOperation{
				{time: currentTime + 100, tick: 1000, liquidity: "1000000"},
			},
			expectedIndex:          0,
			expectedCardinality:    1,
			expectedTickCumulative: 100000, // 1000 * 100
			expectError:            false,
		},
		{
			name:        "multiple writes",
			initialTime: currentTime,
			writes: []writeOperation{
				{time: currentTime + 60, tick: 100, liquidity: "1000000"},
				{time: currentTime + 120, tick: 200, liquidity: "1000000"},
			},
			expectedIndex:          0,
			expectedCardinality:    1,
			expectedTickCumulative: 18000, // 100*60 + 200*60
			expectError:            false,
		},
		{
			name:        "same timestamp write",
			initialTime: currentTime,
			writes: []writeOperation{
				{time: currentTime, tick: 1000, liquidity: "1000000"},
			},
			expectedIndex:          0,
			expectedCardinality:    1,
			expectedTickCumulative: 0, // No change for same timestamp
			expectError:            false,
		},
		{
			name:        "past timestamp write",
			initialTime: currentTime,
			writes: []writeOperation{
				{time: currentTime - 100, tick: 1000, liquidity: "1000000"},
			},
			expectedIndex:          0,
			expectedCardinality:    1,
			expectedTickCumulative: 0,
			expectError:            true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os := pl.NewObservationState(tt.initialTime)

			var err error
			for _, write := range tt.writes {
				liquidity := u256.MustFromDecimal(write.liquidity)
				err = writeObservation(os, write.time, write.tick, liquidity)
				if tt.expectError && err != nil {
					return // Expected error occurred
				}
			}

			if tt.expectError {
				uassert.Error(t, err, "Expected error but got none")
				return
			}

			lastObs, err := lastObservation(os)
			uassert.NoError(t, err, "Last observation should succeed")

			uassert.NoError(t, err, "Unexpected error")
			uassert.Equal(t, tt.expectedIndex, os.Index(), "Index mismatch")
			uassert.Equal(t, tt.expectedCardinality, os.Cardinality(), "Cardinality mismatch")
			uassert.Equal(t, tt.expectedTickCumulative, lastObs.TickCumulative(), "Tick cumulative mismatch")
		})
	}
}

// TestObservationState_CircularBuffer tests circular buffer behavior with multiple cardinality
func TestObservationState_CircularBuffer(t *testing.T) {
	currentTime := time.Now().Unix()

	tests := []struct {
		name                string
		cardinality         uint16
		cardinalityLimit    uint16
		numWrites           int
		expectedFinalIndex  uint16
		expectedCardinality uint16
	}{
		{
			name:                "single cardinality",
			cardinality:         1,
			cardinalityLimit:    1,
			numWrites:           5,
			expectedFinalIndex:  0,
			expectedCardinality: 1,
		},
		{
			name:                "multiple cardinality no wrap",
			cardinality:         3,
			cardinalityLimit:    3,
			numWrites:           2,
			expectedFinalIndex:  2,
			expectedCardinality: 3,
		},
		{
			name:                "multiple cardinality with wrap",
			cardinality:         3,
			cardinalityLimit:    3,
			numWrites:           4,
			expectedFinalIndex:  1,
			expectedCardinality: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os := pl.NewObservationState(currentTime)
			os.SetCardinality(tt.cardinality)
			os.SetCardinalityLimit(tt.cardinalityLimit)

			liquidity := u256.MustFromDecimal("1000000")
			for i := 0; i < tt.numWrites; i++ {
				writeTime := currentTime + int64((i+1)*60)
				err := writeObservation(os, writeTime, int32(100*(i+1)), liquidity)
				uassert.NoError(t, err, "Write should succeed")
			}

			uassert.Equal(t, tt.expectedFinalIndex, os.Index(), "Final index mismatch")
			uassert.Equal(t, tt.expectedCardinality, os.Cardinality(), "Final cardinality mismatch")
		})
	}
}

// TestPool_IncreaseObservationCardinalityLimit tests cardinality limit management
func TestPool_IncreaseObservationCardinalityLimit(t *testing.T) {
	tests := []struct {
		name                    string
		initialCardinality      uint16
		initialCardinalityLimit uint16
		newCardinalityLimit     uint16
		expectError             bool
		errorContains           string
	}{
		{
			name:                    "valid increase",
			initialCardinality:      1,
			initialCardinalityLimit: 1,
			newCardinalityLimit:     10,
			expectError:             false,
		},
		{
			name:                    "decrease attempt",
			initialCardinality:      1,
			initialCardinalityLimit: 10,
			newCardinalityLimit:     5,
			expectError:             true,
			errorContains:           "must be greater than current",
		},
		{
			name:                    "same value",
			initialCardinality:      1,
			initialCardinalityLimit: 10,
			newCardinalityLimit:     10,
			expectError:             true,
			errorContains:           "must be greater than current",
		},
		{
			name:                    "maximum cardinality",
			initialCardinality:      1,
			initialCardinalityLimit: 100,
			newCardinalityLimit:     maxObservationCardinality,
			expectError:             false,
		},
		{
			name:                    "uninitialized state",
			initialCardinality:      0,
			initialCardinalityLimit: 0,
			newCardinalityLimit:     10,
			expectError:             true,
			errorContains:           "not initialized",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPoolTest(t)
			pool := createTestPool()
			currentTime := time.Now().Unix()
			observationState := pool.ObservationState()

			if tt.initialCardinality > 0 {
				writeObservation(observationState, currentTime, pool.Slot0Tick(), pool.Liquidity())
				observationState.SetCardinality(tt.initialCardinality)
				observationState.SetCardinalityLimit(tt.initialCardinalityLimit)
				pool.SetObservationState(observationState)
			} else {
				pool.SetObservationState(nil)
			}

			if tt.expectError {
				err := increaseObservationCardinalityLimitByPool(pool, tt.newCardinalityLimit)
				uassert.ErrorContains(t, err, tt.errorContains)
			} else {
				increaseObservationCardinalityLimitByPool(pool, tt.newCardinalityLimit)
				observationState := pool.ObservationState()
				uassert.Equal(t, tt.newCardinalityLimit, observationState.CardinalityLimit(), "Cardinality limit mismatch")
			}
		})
	}
}

// TestObservationState_LiquidityAccumulation tests liquidity cumulative calculations
func TestObservationState_LiquidityAccumulation(t *testing.T) {
	currentTime := time.Now().Unix()

	tests := []struct {
		name                        string
		writes                      []writeOperation
		expectedLiquidityCumulative string
	}{
		{
			name: "constant liquidity",
			writes: []writeOperation{
				{time: currentTime + 100, tick: 1000, liquidity: "1000000"},
				{time: currentTime + 200, tick: 1000, liquidity: "1000000"},
			},
			expectedLiquidityCumulative: "200000000", // 1000000 * 200
		},
		{
			name: "changing liquidity",
			writes: []writeOperation{
				{time: currentTime + 100, tick: 1000, liquidity: "1000000"},
				{time: currentTime + 200, tick: 1000, liquidity: "2000000"},
			},
			expectedLiquidityCumulative: "300000000", // 1000000*100 + 2000000*100
		},
		{
			name: "zero liquidity",
			writes: []writeOperation{
				{time: currentTime + 100, tick: 1000, liquidity: "0"},
			},
			expectedLiquidityCumulative: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			os := pl.NewObservationState(currentTime)

			for _, write := range tt.writes {
				liquidity := u256.MustFromDecimal(write.liquidity)
				err := writeObservation(os, write.time, write.tick, liquidity)
				uassert.NoError(t, err, "Write should succeed")
			}

			lastObs, err := lastObservation(os)
			uassert.NoError(t, err, "Last observation should succeed")
			uassert.Equal(t, tt.expectedLiquidityCumulative, lastObs.LiquidityCumulative().ToString(), "Liquidity cumulative mismatch")
		})
	}
}

// Verify TWAP rounding for a variety of tickDelta/secondsAgo combinations
func TestGetTWAP_RoundingTable(t *testing.T) {
	tests := []struct {
		name       string
		tickDelta  int64
		secondsAgo uint32
		expected   int32
	}{
		{
			name:       "negative with remainder floors down",
			tickDelta:  -5,
			secondsAgo: 2,
			expected:   -3,
		},
		{
			name:       "negative divisible no adjustment",
			tickDelta:  -4,
			secondsAgo: 2,
			expected:   -2,
		},
		{
			name:       "negative small remainder floors to -1",
			tickDelta:  -1,
			secondsAgo: 3,
			expected:   -1,
		},
		{
			name:       "positive with remainder unchanged",
			tickDelta:  5,
			secondsAgo: 2,
			expected:   2,
		},
		{
			name:       "positive divisible unchanged",
			tickDelta:  6,
			secondsAgo: 3,
			expected:   2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := createTestPool()
			observationState := newObservationStateWithDelta(tt.secondsAgo, tt.tickDelta)
			pool.SetObservationState(observationState)

			twapTick, _, err := getTWAP(pool, tt.secondsAgo)
			uassert.NoError(t, err, "getTWAP should succeed for configured observations")
			uassert.Equal(t, tt.expected, twapTick, "unexpected TWAP tick")
		})
	}
}

// TestGetTWAP_HarmonicMeanLiquidity tests harmonic mean liquidity calculation
// Test cases from Uniswap V3 OracleLibrary.spec.ts
func TestGetTWAP_HarmonicMeanLiquidity(t *testing.T) {
	// Helper function to calculate expected harmonic mean liquidity
	// Matches Uniswap's calculateHarmonicAvgLiq function
	calculateHarmonicAvgLiq := func(period uint32, secondsPerLiq0, secondsPerLiq1 *u256.Uint) *u256.Uint {
		delta := u256.Zero().Sub(secondsPerLiq1, secondsPerLiq0)
		// maxUint160 = 2^160 - 1
		maxUint160 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One())
		// return maxUint160 * period / (delta << 32)
		numerator := u256.Zero().Mul(maxUint160, u256.NewUint(uint64(period)))
		denominator := u256.Zero().Lsh(delta, 32)
		return u256.Zero().Div(numerator, denominator)
	}

	tests := []struct {
		name                        string
		secondsAgo                  uint32
		tickCumulatives             [2]int64
		secondsPerLiqCumulatives    [2]string
		expectedArithmeticMeanTick  int32
	}{
		{
			name:       "correct output when tick is 0",
			secondsAgo: 3,
			tickCumulatives: [2]int64{12, 12},
			secondsPerLiqCumulatives: [2]string{"10", "20"},
			expectedArithmeticMeanTick: 0,
		},
		{
			name:       "correct rounding for .5 negative tick",
			secondsAgo: 4,
			tickCumulatives: [2]int64{-10, -12},
			secondsPerLiqCumulatives: [2]string{"10", "15"},
			expectedArithmeticMeanTick: -1, // Always round to negative infinity
		},
		{
			name:       "correct output for liquidity overflow",
			secondsAgo: 1,
			tickCumulatives: [2]int64{12, 12},
			secondsPerLiqCumulatives: [2]string{"10", "11"},
			expectedArithmeticMeanTick: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := createTestPool()

			secondsPerLiq0 := u256.MustFromDecimal(tt.secondsPerLiqCumulatives[0])
			secondsPerLiq1 := u256.MustFromDecimal(tt.secondsPerLiqCumulatives[1])
			delta := u256.Zero().Sub(secondsPerLiq1, secondsPerLiq0)

			observationState := newObservationStateWithLiquidity(tt.secondsAgo, tt.tickCumulatives[1]-tt.tickCumulatives[0], delta)
			pool.SetObservationState(observationState)

			arithmeticMeanTick, harmonicMeanLiquidity, err := getTWAP(pool, tt.secondsAgo)
			uassert.NoError(t, err, "getTWAP should succeed")

			// Check arithmetic mean tick
			uassert.Equal(t, tt.expectedArithmeticMeanTick, arithmeticMeanTick, "unexpected arithmetic mean tick")

			// Check harmonic mean liquidity
			expectedHarmonicMean := calculateHarmonicAvgLiq(tt.secondsAgo, secondsPerLiq0, secondsPerLiq1)

			// For liquidity overflow test, should return max uint128
			if tt.name == "correct output for liquidity overflow" {
				maxUint128 := u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 128), u256.One())
				uassert.Equal(t, maxUint128.ToString(), harmonicMeanLiquidity.ToString(), "liquidity overflow should return max uint128")
			} else {
				uassert.Equal(t, expectedHarmonicMean.ToString(), harmonicMeanLiquidity.ToString(), "unexpected harmonic mean liquidity")
			}
		})
	}
}

// TestGetTWAP_ErrorCases tests error scenarios for TWAP calculation
func TestGetTWAP_ErrorCases(t *testing.T) {
	tests := []struct {
		name           string
		setupPool      func() *pl.Pool
		secondsAgo     uint32
		expectedError  string
	}{
		{
			name: "secondsAgo is zero",
			setupPool: func() *pl.Pool {
				pool := createTestPool()
				pool.SetObservationState(pl.NewObservationState(time.Now().Unix()))
				return pool
			},
			secondsAgo:    0,
			expectedError: "secondsAgo must be greater than 0",
		},
		{
			name: "observation state not initialized",
			setupPool: func() *pl.Pool {
				pool := createTestPool()
				pool.SetObservationState(nil)
				return pool
			},
			secondsAgo:    3600,
			expectedError: "observation state not initialized",
		},
		{
			name: "no observations available",
			setupPool: func() *pl.Pool {
				pool := createTestPool()
				os := pl.NewObservationState(time.Now().Unix())
				os.SetCardinality(0)
				pool.SetObservationState(os)
				return pool
			},
			secondsAgo:    3600,
			expectedError: "no observations available",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pool := tt.setupPool()
			_, _, err := getTWAP(pool, tt.secondsAgo)
			uassert.ErrorContains(t, err, tt.expectedError)
		})
	}
}

// newObservationStateWithDelta seeds a 2-slot observation state so that the
// tick cumulative delta over secondsAgo is tickDelta.
func newObservationStateWithDelta(secondsAgo uint32, tickDelta int64) *pl.ObservationState {
	now := time.Now().Unix()
	start := now - int64(secondsAgo)

	os := pl.NewObservationState(start)
	os.SetCardinality(2)
	os.SetCardinalityLimit(2)
	os.SetIndex(1)
	os.Observations()[1] = pl.NewObservation(
		now,
		tickDelta,
		u256.Zero(),
		u256.Zero(),
		true,
	)
	return os
}

// newObservationStateWithLiquidity seeds a 2-slot observation state with
// tick cumulative delta and seconds per liquidity delta.
func newObservationStateWithLiquidity(secondsAgo uint32, tickDelta int64, secondsPerLiquidityDelta *u256.Uint) *pl.ObservationState {
	now := time.Now().Unix()
	start := now - int64(secondsAgo)

	os := pl.NewObservationState(start)
	os.SetCardinality(2)
	os.SetCardinalityLimit(2)
	os.SetIndex(1)
	os.Observations()[1] = pl.NewObservation(
		now,
		tickDelta,
		u256.Zero(),
		secondsPerLiquidityDelta,
		true,
	)
	return os
}

// Helper types for test data
type writeOperation struct {
	time      int64
	tick      int32
	liquidity string
}

// Helper function to create a test pool
func createTestPool() *pl.Pool {
	return pl.NewPool(
		"gno.land/r/onbloc/foo",
		"gno.land/r/onbloc/bar",
		500,
		u256.MustFromDecimal("79228162514264337593543950336"),
		10,                              // tickSpacing
		0,                               // tick
		0,                               // feeProtocol
		u256.MustFromDecimal("1000000"), // maxLiquidityPerTick
	)
}
