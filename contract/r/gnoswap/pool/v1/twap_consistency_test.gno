package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"
)

type twapConsistencyObservation struct {
	timestamp      int64
	tickCumulative int64
}

type twapConsistencyCase struct {
	name         string
	currentTime  int64
	secondsAgo   uint32
	currentTick  int32
	observations []twapConsistencyObservation
	wantErr      string
	wantTick     int32
}

// TestOracle_TWAPConsistencyCases covers canonical TWAP consistency cases.
func TestOracle_TWAPConsistencyCases(t *testing.T) {
	tests := []twapConsistencyCase{
		{
			name:        "constant tick exact window",
			currentTime: 200,
			secondsAgo:  100,
			currentTick: 25,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
				{timestamp: 200, tickCumulative: 3500},
			},
			wantTick: 25,
		},
		{
			name:        "interpolated start and extended end",
			currentTime: 150,
			secondsAgo:  40,
			currentTick: 20,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
				{timestamp: 130, tickCumulative: 1600},
			},
			wantTick: 20,
		},
		{
			name:        "negative mean tick floors toward negative infinity",
			currentTime: 102,
			secondsAgo:  2,
			currentTick: -2,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 0},
				{timestamp: 102, tickCumulative: -3},
			},
			wantTick: -2,
		},
		{
			name:        "exact boundary uses stored row with interior observation",
			currentTime: 200,
			secondsAgo:  100,
			currentTick: 25,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
				{timestamp: 150, tickCumulative: 2250},
				{timestamp: 200, tickCumulative: 3500},
			},
			wantTick: 25,
		},
		{
			name:        "latest boundary extends from a single observation",
			currentTime: 150,
			secondsAgo:  50,
			currentTick: 12,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
			},
			wantTick: 12,
		},
		{
			name:        "current boundary uses stored latest observation",
			currentTime: 150,
			secondsAgo:  50,
			currentTick: 99,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
				{timestamp: 150, tickCumulative: 1600},
			},
			wantTick: 12,
		},
		{
			name:        "historical interpolation preserves negative slope",
			currentTime: 150,
			secondsAgo:  30,
			currentTick: -20,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 2000},
				{timestamp: 130, tickCumulative: 1400},
			},
			wantTick: -20,
		},
		{
			name:        "fractional historical interpolation keeps negative floor semantics",
			currentTime: 106,
			secondsAgo:  5,
			currentTick: 1,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 0},
				{timestamp: 103, tickCumulative: -5},
			},
			wantTick: -1,
		},
		{
			name:        "too old window returns oracle error",
			currentTime: 150,
			secondsAgo:  51,
			currentTick: 12,
			observations: []twapConsistencyObservation{
				{timestamp: 100, tickCumulative: 1000},
				{timestamp: 150, tickCumulative: 1600},
			},
			wantErr: "[GNOSWAP-POOL-026]",
		},
		{
			name:        "multi interval weighted average",
			currentTime: 400,
			secondsAgo:  200,
			currentTick: -100,
			observations: []twapConsistencyObservation{
				{timestamp: 200, tickCumulative: 0},
				{timestamp: 300, tickCumulative: -5000},
				{timestamp: 400, tickCumulative: -15000},
			},
			wantTick: -75,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			restoreContext := setOracleTestContext(tt.currentTime)
			defer restoreContext()

			got, _, err := getTWAP(newTwapConsistencyPool(tt), tt.secondsAgo)
			if tt.wantErr != "" {
				uassert.ErrorContains(t, err, tt.wantErr)
				return
			}

			uassert.NoError(t, err, "oracle twap case should resolve successfully")
			uassert.Equal(t, tt.wantTick, got, "twap tick should match the expected oracle result")
		})
	}
}

func setOracleTestContext(currentTime int64) func() {
	previousCtx := testing.GetContext()
	ctx := previousCtx
	ctx.Time = time.Unix(currentTime, 0)
	testing.SetContext(ctx)

	return func() {
		testing.SetContext(previousCtx)
	}
}

func newTwapConsistencyPool(tt twapConsistencyCase) *pl.Pool {
	pool := createTestPool()
	slot0 := pool.Slot0()
	slot0.SetTick(tt.currentTick)
	pool.SetSlot0(slot0)
	pool.SetLiquidity(u256.MustFromDecimal("1000"))
	pool.SetObservationState(newTwapConsistencyObservationState(tt.observations))

	return pool
}

func newTwapConsistencyObservationState(observations []twapConsistencyObservation) *pl.ObservationState {
	cardinality := uint16(len(observations))
	os := pl.NewObservationState(observations[0].timestamp)
	os.SetCardinality(cardinality)
	os.SetCardinalityNext(cardinality)
	os.SetIndex(cardinality - 1)

	seeded := make(map[uint16]*pl.Observation)
	for i, observation := range observations {
		seeded[uint16(i)] = pl.NewObservation(
			observation.timestamp,
			observation.tickCumulative,
			"0",
			"0",
			true,
		)
	}
	os.SetObservations(seeded)

	return os
}
