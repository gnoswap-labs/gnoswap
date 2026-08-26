package pool

// ObservationState manages only the oracle's circular observation buffer.
// The active index and buffer capacities are part of Pool.Slot0 so there is
// one authoritative copy of the oracle cursor state.
type ObservationState struct {
	observations map[uint16]*Observation // circular buffer of observations
}

// ObservationState Getters methods
func (os *ObservationState) Observations() map[uint16]*Observation { return os.observations }

// ObservationState Setters methods
func (os *ObservationState) SetObservation(index uint16, observation *Observation) {
	os.observations[index] = observation
}

func (os *ObservationState) SetObservations(observations map[uint16]*Observation) {
	os.observations = observations
}

// ObservationAt returns the observation stored at index, mirroring Uniswap
// V3's observations(uint256 index) mapping getter.
func (os *ObservationState) ObservationAt(index uint16) (*Observation, bool) {
	observation, ok := os.observations[index]
	return observation, ok
}

func (os *ObservationState) Clone() *ObservationState {
	observations := make(map[uint16]*Observation)

	for index, observation := range os.observations {
		observations[index] = observation.Clone()
	}

	return &ObservationState{
		observations: observations,
	}
}

type Observation struct {
	blockTimestamp                    int64  // timestamp of the observation
	tickCumulative                    int64  // cumulative tick up to this timestamp
	secondsPerLiquidityCumulativeX128 string // cumulative seconds per liquidity
	initialized                       bool   // whether this observation has been initialized
}

// Observation Getters methods
func (o *Observation) BlockTimestamp() int64 { return o.blockTimestamp }
func (o *Observation) TickCumulative() int64 { return o.tickCumulative }
func (o *Observation) SecondsPerLiquidityCumulativeX128() string {
	return o.secondsPerLiquidityCumulativeX128
}
func (o *Observation) Initialized() bool { return o.initialized }

// Observation Setters methods
func (o *Observation) SetBlockTimestamp(blockTimestamp int64) {
	o.blockTimestamp = blockTimestamp
}

func (o *Observation) SetTickCumulative(tickCumulative int64) {
	o.tickCumulative = tickCumulative
}

func (o *Observation) SetSecondsPerLiquidityCumulativeX128(secondsPerLiquidityCumulativeX128 string) {
	o.secondsPerLiquidityCumulativeX128 = secondsPerLiquidityCumulativeX128
}

func (o *Observation) SetInitialized(initialized bool) {
	o.initialized = initialized
}

func (o *Observation) Clone() *Observation {
	return &Observation{
		blockTimestamp:                    o.blockTimestamp,
		tickCumulative:                    o.tickCumulative,
		secondsPerLiquidityCumulativeX128: o.secondsPerLiquidityCumulativeX128,
		initialized:                       o.initialized,
	}
}

func NewObservationState(currentTime int64) *ObservationState {
	state := &ObservationState{
		observations: make(map[uint16]*Observation),
	}

	state.observations[0] = NewObservation(
		currentTime,
		0,
		"0",
		true,
	)

	return state
}

func NewObservation(
	blockTimestamp int64,
	tickCumulative int64,
	secondsPerLiquidityCumulativeX128 string,
	initialized bool,
) *Observation {
	return &Observation{
		blockTimestamp:                    blockTimestamp,
		tickCumulative:                    tickCumulative,
		secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128,
		initialized:                       initialized,
	}
}

func NewDefaultObservation() *Observation {
	return NewObservation(
		0,
		0,
		"0",
		false,
	)
}
