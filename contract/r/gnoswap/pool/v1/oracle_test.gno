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
