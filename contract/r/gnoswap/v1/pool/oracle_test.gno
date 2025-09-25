package pool

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
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
			name:        "initial state",
			initialTime: currentTime,
			writes:      []writeOperation{},
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
			os := newObservationState(tt.initialTime)

			var err error
			for _, write := range tt.writes {
				liquidity := u256.MustFromDecimal(write.liquidity)
				err = os.write(write.time, write.tick, liquidity)
				if tt.expectError && err != nil {
					return // Expected error occurred
				}
			}

			if tt.expectError {
				uassert.Error(t, err, "Expected error but got none")
				return
			}

			uassert.NoError(t, err, "Unexpected error")
			uassert.Equal(t, tt.expectedIndex, os.index, "Index mismatch")
			uassert.Equal(t, tt.expectedCardinality, os.cardinality, "Cardinality mismatch")
			uassert.Equal(t, tt.expectedTickCumulative, os.lastObservation().tickCumulative, "Tick cumulative mismatch")
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
			os := newObservationState(currentTime)
			os.cardinality = tt.cardinality
			os.cardinalityLimit = tt.cardinalityLimit

			liquidity := u256.MustFromDecimal("1000000")
			for i := 0; i < tt.numWrites; i++ {
				writeTime := currentTime + int64((i+1)*60)
				err := os.write(writeTime, int32(100*(i+1)), liquidity)
				uassert.NoError(t, err, "Write should succeed")
			}

			uassert.Equal(t, tt.expectedFinalIndex, os.index, "Final index mismatch")
			uassert.Equal(t, tt.expectedCardinality, os.cardinality, "Final cardinality mismatch")
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
			newCardinalityLimit:     ObservationCardinality,
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
			pool := createTestPool()

			if tt.initialCardinality > 0 {
				currentTime := time.Now().Unix()
				pool.writeObservation(currentTime, 1000, u256.MustFromDecimal("1000000"))
				pool.observationState.cardinality = tt.initialCardinality
				pool.observationState.cardinalityLimit = tt.initialCardinalityLimit
			} else {
				pool.observationState = nil
			}

			err := pool.IncreaseObservationCardinalityLimit(tt.newCardinalityLimit)

			if tt.expectError {
				uassert.Error(t, err, "Expected error but got none")
				return
			}

			uassert.NoError(t, err, "Unexpected error")
			uassert.Equal(t, tt.newCardinalityLimit, pool.observationState.cardinalityLimit, "Cardinality limit mismatch")
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
			os := newObservationState(currentTime)

			for _, write := range tt.writes {
				liquidity := u256.MustFromDecimal(write.liquidity)
				err := os.write(write.time, write.tick, liquidity)
				uassert.NoError(t, err, "Write should succeed")
			}

			lastObs := os.lastObservation()
			uassert.Equal(t, tt.expectedLiquidityCumulative, lastObs.liquidityCumulative.ToString(), "Liquidity cumulative mismatch")
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
func createTestPool() *Pool {
	return &Pool{
		token0Path: "gno.land/r/onbloc/foo",
		token1Path: "gno.land/r/onbloc/bar",
		fee:        500,
		slot0: Slot0{
			sqrtPriceX96: u256.MustFromDecimal("79228162514264337593543950336"),
			tick:         0,
			unlocked:     true,
		},
		liquidity:        u256.MustFromDecimal("1000000"),
		observationState: nil,
	}
}