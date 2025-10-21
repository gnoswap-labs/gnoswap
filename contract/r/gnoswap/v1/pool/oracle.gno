package pool

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
)

// maxObservationCardinality defines the maximum number of observations to store
const maxObservationCardinality uint16 = 65535

// ObservationState manages the oracle's historical data
type ObservationState struct {
	observations     map[uint16]*Observation // circular buffer of observations
	index            uint16                  // the most-recently updated index of the observations array
	cardinality      uint16                  // the current maximum number of observations that are being stored
	cardinalityLimit uint16                  // the next maximum number of observations to store, triggered in observations.write
}

func (os *ObservationState) transform(currentTime int64, tick int32, liquidity *u256.Uint) (*Observation, error) {
	lastObservation, err := os.lastObservation()
	if err != nil {
		return nil, err
	}

	timeDelta := currentTime - lastObservation.blockTimestamp
	if timeDelta < 0 {
		return nil, errors.New("time delta must be greater than 0")
	}

	if timeDelta == 0 {
		return lastObservation, nil
	}

	// calculate cumulative values
	tickCumulative := lastObservation.tickCumulative + int64(tick)*timeDelta

	// calculate liquidity cumulative
	liquidityDelta, overflow := u256.Zero().MulOverflow(liquidity, u256.NewUintFromInt64(timeDelta))
	if overflow {
		panic(errOverFlow)
	}
	liquidityCumulative := u256.Zero().Add(lastObservation.liquidityCumulative, liquidityDelta)

	// calculate seconds per liquidity
	secondsPerLiquidityCumulativeX128 := lastObservation.secondsPerLiquidityCumulativeX128.Clone()
	if !liquidity.IsZero() {
		// secondsPerLiquidity += timeDelta * 2^128 / liquidity
		secondsPerLiquidityDelta := u256.MulDiv(
			u256.NewUintFromInt64(timeDelta),
			u256.MustFromDecimal("340282366920938463463374607431768211456"), // 2^128
			liquidity,
		)
		secondsPerLiquidityCumulativeX128 = u256.Zero().Add(
			secondsPerLiquidityCumulativeX128,
			secondsPerLiquidityDelta,
		)
	}

	return &Observation{
		blockTimestamp:                    currentTime,
		tickCumulative:                    tickCumulative,
		liquidityCumulative:               liquidityCumulative,
		secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128,
		initialized:                       true,
	}, nil
}

func (os *ObservationState) grow(currentCardinality, nextCardinality uint16) (uint16, error) {
	if currentCardinality == 0 {
		return currentCardinality, errors.New("current cardinality must not be 0")
	}

	if nextCardinality <= currentCardinality {
		return currentCardinality, nil
	}

	if nextCardinality > maxObservationCardinality {
		return currentCardinality, errors.New("nextCardinality exceeds maximum")
	}

	// Ensure all slots from 0 to nextCardinality are initialized
	// This prevents gaps in the circular buffer
	for i := uint16(0); i < nextCardinality; i++ {
		if _, ok := os.observations[i]; !ok {
			// Create new observation slot
			os.observations[i] = &Observation{
				blockTimestamp:                    1,
				tickCumulative:                    0,
				liquidityCumulative:               u256.Zero(),
				secondsPerLiquidityCumulativeX128: u256.Zero(),
				initialized:                       true, // Mark as not yet used
			}
		}
	}

	return nextCardinality, nil
}

func (os *ObservationState) write(
	currentTime int64,
	tick int32,
	liquidity *u256.Uint,
) error {
	lastObservation, err := os.lastObservation()
	if err != nil {
		return err
	}

	if lastObservation.blockTimestamp == currentTime {
		return nil
	}

	// Check if we need to grow the cardinality
	if os.cardinalityLimit > os.cardinality && os.index == os.cardinality-1 {
		// Grow the observation array to the new cardinality limit
		newCardinality, err := os.grow(os.cardinality, os.cardinalityLimit)
		if err != nil {
			return err
		}

		os.cardinality = newCardinality
	}

	nextIndex := (os.index + 1) % os.cardinality

	// Ensure the slot exists before writing
	if _, ok := os.observations[nextIndex]; !ok {
		os.observations[nextIndex] = &Observation{}
	}

	observation, err := os.transform(currentTime, tick, liquidity)
	if err != nil {
		return err
	}

	os.observations[nextIndex] = observation
	os.index = nextIndex

	return nil
}

func (os *ObservationState) lastObservation() (*Observation, error) {
	observation, ok := os.observations[os.index]
	if !ok || observation == nil || !observation.initialized {
		return nil, errNotInitializedObservation
	}

	return observation, nil
}

func (os *ObservationState) Index() uint16 {
	return os.index
}

func (os *ObservationState) Cardinality() uint16 {
	return os.cardinality
}

// ObservationAt returns the observation at a specific index
// Returns error if the observation doesn't exist or is not initialized
func (os *ObservationState) ObservationAt(index uint16) (*Observation, error) {
	obs, ok := os.observations[index]
	if !ok || obs == nil {
		return nil, errNotInitializedObservation
	}

	// Check if the observation is properly initialized
	if !obs.initialized {
		return nil, errNotInitializedObservation
	}

	return obs, nil
}

// ObservationsCount returns the current cardinality
func (os *ObservationState) ObservationsCount() uint16 {
	return os.cardinality
}

type Observation struct {
	blockTimestamp                    int64      // timestamp of the observation
	tickCumulative                    int64      // cumulative tick up to this timestamp
	liquidityCumulative               *u256.Uint // cumulative liquidity up to this timestamp
	secondsPerLiquidityCumulativeX128 *u256.Uint // cumulative seconds per liquidity
	initialized                       bool       // whether this observation has been initialized
}

func (o *Observation) BlockTimestamp() int64 {
	return o.blockTimestamp
}

func (o *Observation) TickCumulative() int64 {
	return o.tickCumulative
}

func (o *Observation) LiquidityCumulative() string {
	if o.liquidityCumulative == nil {
		return "0"
	}
	return o.liquidityCumulative.ToString()
}

func (o *Observation) SecondsPerLiquidityCumulativeX128() string {
	if o.secondsPerLiquidityCumulativeX128 == nil {
		return "0"
	}

	return o.secondsPerLiquidityCumulativeX128.ToString()
}

func newObservationState(currentTime int64) *ObservationState {
	state := &ObservationState{
		index:            0,
		cardinality:      1,
		cardinalityLimit: 1,
		observations:     make(map[uint16]*Observation),
	}

	// Initialize the first observation slot
	state.observations[0] = &Observation{
		blockTimestamp:                    currentTime,
		tickCumulative:                    0,
		liquidityCumulative:               u256.Zero(),
		secondsPerLiquidityCumulativeX128: u256.Zero(),
		initialized:                       true,
	}

	return state
}

// observeSingle returns the data for a single observation at a specific time ago
func (os *ObservationState) observeSingle(
	currentTime int64,
	secondsAgo uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (int64, *u256.Uint, error) {
	if secondsAgo == 0 {
		// if secondsAgo is 0, return current values
		last, err := os.ObservationAt(index)
		if err != nil {
			return 0, nil, err
		}

		if last.blockTimestamp != currentTime {
			// need to create virtual observation for current time
			transformed, err := os.transform(currentTime, tick, liquidity)
			if err != nil {
				return 0, nil, err
			}

			return transformed.tickCumulative, transformed.secondsPerLiquidityCumulativeX128, nil
		}

		return last.tickCumulative, last.secondsPerLiquidityCumulativeX128, nil
	}

	target := currentTime - int64(secondsAgo)

	// find the observations before and after the target
	beforeOrAt, afterOrAt, err := os.getSurroundingObservations(
		target,
		currentTime,
		tick,
		index,
		liquidity,
		cardinality,
	)
	if err != nil {
		return 0, nil, err
	}

	if target <= beforeOrAt.blockTimestamp {
		return beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128, nil
	}

	if target == afterOrAt.blockTimestamp {
		return afterOrAt.tickCumulative, afterOrAt.secondsPerLiquidityCumulativeX128, nil
	}

	// interpolate between the two observations
	observationTimeDelta := afterOrAt.blockTimestamp - beforeOrAt.blockTimestamp
	targetDelta := target - beforeOrAt.blockTimestamp

	// If the observations are at the same time, return the before observation
	if observationTimeDelta == 0 {
		return beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128, nil
	}

	// tickCumulative += (tickCumulativeAfter - tickCumulativeBefore) * targetDelta / observationTimeDelta
	tickCumulative := beforeOrAt.tickCumulative +
		(afterOrAt.tickCumulative-beforeOrAt.tickCumulative)*targetDelta/observationTimeDelta

	// for secondsPerLiquidity, need to interpolate carefully
	secondsPerLiquidityDelta := u256.Zero().Sub(
		afterOrAt.secondsPerLiquidityCumulativeX128,
		beforeOrAt.secondsPerLiquidityCumulativeX128,
	)

	secondsPerLiquidity := u256.Zero().Add(
		beforeOrAt.secondsPerLiquidityCumulativeX128,
		u256.Zero().Div(
			u256.Zero().Mul(
				secondsPerLiquidityDelta,
				u256.NewUintFromInt64(targetDelta),
			),
			u256.NewUintFromInt64(observationTimeDelta),
		),
	)

	return tickCumulative, secondsPerLiquidity, nil
}

// getSurroundingObservations finds the observations immediately before and after the target timestamp.
// It uses binary search over the logical time-ordered view of the circular buffer.
// Logical order starts at (index+1) % cardinality (oldest) and ends at index (latest).
func (os *ObservationState) getSurroundingObservations(
	target int64,
	currentTime int64,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (*Observation, *Observation, error) {
	// Get the latest observation
	latest, err := os.ObservationAt(index)
	if err != nil {
		return nil, nil, err
	}

	// If target is at or after the latest observation, extrapolate to current time
	if target >= latest.blockTimestamp {
		// If latest is already at current time, return it as both before and after
		if latest.blockTimestamp == currentTime {
			return latest, latest, nil
		}

		// Create a virtual observation for current time
		afterOrAt, err := os.transform(currentTime, tick, liquidity)
		if err != nil {
			return nil, nil, err
		}

		return latest, afterOrAt, nil
	}

	// Handle single cardinality case
	if cardinality == 1 {
		return latest, latest, nil
	}

	// Binary search over the logical time-ordered circular buffer
	// start points to the oldest observation: (index + 1) % cardinality
	start := (index + 1) % cardinality

	// Helper function to access observations in logical order
	at := func(k uint16) (*Observation, error) {
		physicalIdx := (start + k) % cardinality
		return os.ObservationAt(physicalIdx)
	}

	// Binary search range: [0, cardinality-1] in logical ordering
	lo, hi := uint16(0), cardinality-1

	for lo < hi {
		mid := lo + (hi-lo)/2
		obs, err := at(mid)
		if err != nil {
			// Uninitialized observation: assume initialized observations are at the beginning
			if mid == 0 {
				break
			}
			hi = mid - 1
			continue
		}

		if obs.blockTimestamp <= target {
			// Target is at or after mid, search in upper half
			lo = mid + 1
		} else {
			// Target is before mid, search in lower half
			hi = mid
		}
	}

	var beforeIdx uint16

	// Calculate before index
	if lo == 0 {
		beforeIdx = 0
	} else {
		beforeIdx = lo - 1
	}

	// Get the observation before or at target
	beforeOrAt, err := at(beforeIdx)
	if err != nil {
		return nil, nil, err
	}

	// Get the observation after target
	afterIndex := lo % cardinality

	afterOrAt, err := at(afterIndex)
	if err != nil {
		// If after observation is not initialized, use the latest observation
		afterOrAt = latest
	}

	// Boundary correction: ensure beforeOrAt is actually before or at target
	if beforeOrAt.blockTimestamp > target {
		// This shouldn't happen in normal cases, but handle it defensively
		// If the first observation is after target, use it for both
		afterOrAt = beforeOrAt
	}

	return beforeOrAt, afterOrAt, nil
}

// observe returns the cumulative tick and liquidity as of each timestamp secondsAgo from the current time.
func (os *ObservationState) observe(
	currentTime int64,
	secondsAgos []uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) ([]int64, []*u256.Uint, error) {
	historyCount := len(secondsAgos)
	if historyCount == 0 {
		return nil, nil, errors.New("secondsAgos must not be empty")
	}

	tickCumulatives := make([]int64, historyCount)
	secondsPerLiquidityCumulativeX128s := make([]*u256.Uint, historyCount)

	for i, secondsAgo := range secondsAgos {
		tickCumulative, secondsPerLiquidity, err := os.observeSingle(
			currentTime,
			secondsAgo,
			tick,
			index,
			liquidity,
			cardinality,
		)
		if err != nil {
			return nil, nil, err
		}

		tickCumulatives[i] = tickCumulative
		secondsPerLiquidityCumulativeX128s[i] = secondsPerLiquidity
	}

	return tickCumulatives, secondsPerLiquidityCumulativeX128s, nil
}
