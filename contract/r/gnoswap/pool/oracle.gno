package pool

// ObservationState manages the oracle's historical data
type ObservationState struct {
	observations    map[uint16]*Observation // circular buffer of observations
	index           uint16                  // the most-recently updated index of the observations array
	cardinality     uint16                  // the current maximum number of observations that are being stored
	cardinalityNext uint16                  // the next maximum number of observations to store, triggered in observations.write
}

// ObservationState Getters methods
func (os *ObservationState) Index() uint16                         { return os.index }
func (os *ObservationState) Cardinality() uint16                   { return os.cardinality }
func (os *ObservationState) CardinalityNext() uint16               { return os.cardinalityNext }
func (os *ObservationState) Observations() map[uint16]*Observation { return os.observations }

// ObservationState Setters methods
func (os *ObservationState) SetIndex(index uint16) {
	os.index = index
}

func (os *ObservationState) SetCardinality(cardinality uint16) {
	os.cardinality = cardinality
}

func (os *ObservationState) SetCardinalityNext(cardinalityNext uint16) {
	os.cardinalityNext = cardinalityNext
}

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
		index:           os.index,
		cardinality:     os.cardinality,
		cardinalityNext: os.cardinalityNext,
		observations:    observations,
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
		index:           0,
		cardinality:     1,
		cardinalityNext: 1,
		observations:    make(map[uint16]*Observation),
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
