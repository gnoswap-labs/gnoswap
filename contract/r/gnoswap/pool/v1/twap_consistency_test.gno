package pool

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
func TestOracle_TWAPConsistencyCases(cur realm, t *testing.T) {
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
			wantErr: "[GNOSWAP-POOL-025]",
		},
		{
			name:        "window before unix epoch returns pre-epoch error",
			currentTime: 10,
			secondsAgo:  11,
			currentTick: 12,
			observations: []twapConsistencyObservation{
				{timestamp: 0, tickCumulative: 0},
				{timestamp: 10, tickCumulative: 120},
			},
			wantErr: "[GNOSWAP-POOL-026]",
		},
		{
			// Timestamps are int64. A uint32-based comparison would sort
			// 2^32-100 after 2^32+100 and pick the wrong bracket.
			name:        "observations spanning the uint32 boundary keep natural ordering",
			currentTime: 1<<32 + 100,
			secondsAgo:  200,
			currentTick: 25,
			observations: []twapConsistencyObservation{
				{timestamp: 1<<32 - 300, tickCumulative: 0},
				{timestamp: 1<<32 - 100, tickCumulative: 1000},
				{timestamp: 1<<32 + 100, tickCumulative: 6000},
			},
			wantTick: 25,
		},
		{
			name:        "interpolation across the uint32 boundary keeps natural ordering",
			currentTime: 1<<32 + 200,
			secondsAgo:  250,
			currentTick: 20,
			observations: []twapConsistencyObservation{
				{timestamp: 1<<32 - 300, tickCumulative: 0},
				{timestamp: 1<<32 - 100, tickCumulative: 1000},
				{timestamp: 1<<32 + 200, tickCumulative: 7000},
			},
			wantTick: 20,
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			restoreContext := setOracleTestContext(tt.currentTime)
			defer restoreContext()

			pool := newTwapConsistencyPool(tt)
			got, _, err := oracleConsult(pool, observationsForTest(pool), tt.secondsAgo)
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
	setObservationsForTest(pool, newTwapConsistencyObservationTree(tt.observations))
	slot0.SetObservationIndex(uint16(len(tt.observations) - 1))
	slot0.SetObservationCardinality(uint16(len(tt.observations)))
	slot0.SetObservationCardinalityNext(uint16(len(tt.observations)))
	pool.SetSlot0(slot0)

	return pool
}

func newTwapConsistencyObservationTree(observations []twapConsistencyObservation) *pl.ObservationTree {
	os := pl.NewPoolObservationsTree(observations[0].timestamp)

	seeded := make(map[uint16]*pl.Observation)
	for i, observation := range observations {
		seeded[uint16(i)] = pl.NewObservation(
			observation.timestamp,
			observation.tickCumulative,
			"0",
			true,
		)
	}
	for index, observation := range seeded {
		os.Set(index, observation)
	}

	return os
}
