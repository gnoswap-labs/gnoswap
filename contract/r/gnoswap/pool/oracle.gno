package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

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

func (os *ObservationState) SetObservations(observations map[uint16]*Observation) {
	os.observations = observations
}

func (os *ObservationState) Clone() *ObservationState {
	return &ObservationState{
		observations:    make(map[uint16]*Observation),
		index:           os.index,
		cardinality:     os.cardinality,
		cardinalityNext: os.cardinalityNext,
	}
}

type Observation struct {
	blockTimestamp                    int64      // timestamp of the observation
	tickCumulative                    int64      // cumulative tick up to this timestamp
	liquidityCumulative               *u256.Uint // cumulative liquidity up to this timestamp
	secondsPerLiquidityCumulativeX128 *u256.Uint // cumulative seconds per liquidity
	initialized                       bool       // whether this observation has been initialized
}

// Observation Getters methods
func (o *Observation) BlockTimestamp() int64           { return o.blockTimestamp }
func (o *Observation) TickCumulative() int64           { return o.tickCumulative }
func (o *Observation) LiquidityCumulative() *u256.Uint { return o.liquidityCumulative }
func (o *Observation) SecondsPerLiquidityCumulativeX128() *u256.Uint {
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

func (o *Observation) SetLiquidityCumulative(liquidityCumulative *u256.Uint) {
	o.liquidityCumulative = liquidityCumulative
}

func (o *Observation) SetSecondsPerLiquidityCumulativeX128(secondsPerLiquidityCumulativeX128 *u256.Uint) {
	o.secondsPerLiquidityCumulativeX128 = secondsPerLiquidityCumulativeX128
}

func (o *Observation) SetInitialized(initialized bool) {
	o.initialized = initialized
}

func (o *Observation) Clone() *Observation {
	return &Observation{
		blockTimestamp:                    o.blockTimestamp,
		tickCumulative:                    o.tickCumulative,
		liquidityCumulative:               o.liquidityCumulative.Clone(),
		secondsPerLiquidityCumulativeX128: o.secondsPerLiquidityCumulativeX128.Clone(),
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

	// Initialize the first observation slot
	state.observations[0] = NewObservation(
		currentTime,
		0,
		u256.Zero(),
		u256.Zero(),
		true,
	)

	return state
}

func NewObservation(
	blockTimestamp int64,
	tickCumulative int64,
	liquidityCumulative *u256.Uint,
	secondsPerLiquidityCumulativeX128 *u256.Uint,
	initialized bool,
) *Observation {
	return &Observation{
		blockTimestamp:                    blockTimestamp,
		tickCumulative:                    tickCumulative,
		liquidityCumulative:               liquidityCumulative,
		secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128,
		initialized:                       initialized,
	}
}

func NewDefaultObservation() *Observation {
	return NewObservation(
		0,
		0,
		u256.Zero(),
		u256.Zero(),
		false,
	)
}
