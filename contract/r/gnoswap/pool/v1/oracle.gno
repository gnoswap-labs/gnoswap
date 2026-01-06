package v1

import (
	"errors"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	pl "gno.land/r/gnoswap/pool"
)

// maxObservationCardinality defines the maximum number of observations to store
const maxObservationCardinality uint16 = 65535

// GetTWAP calculates the time-weighted average price between two points in time
// Returns the average tick over the time period
func getTWAP(p *pl.Pool, secondsAgo uint32) (int32, error) {
	if secondsAgo == 0 {
		return p.Slot0Tick(), nil
	}

	// Check if observation state is initialized
	if p.ObservationState() == nil {
		return 0, errors.New("observation state not initialized")
	}

	// Check if we have enough observations
	if p.ObservationState().Cardinality() == 0 {
		return 0, errors.New("no observations available")
	}

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	currentTime := time.Now().Unix()

	tickCumulatives, _, err := observe(
		p.ObservationState(),
		currentTime,
		secondsAgos,
		p.Slot0Tick(),
		p.ObservationState().Index(),
		p.Liquidity(),
		p.ObservationState().Cardinality(),
	)
	if err != nil {
		return 0, err
	}

	// Ensure we have valid data
	if len(tickCumulatives) != 2 {
		return 0, errors.New("insufficient observation data")
	}

	// Calculate TWAP: (tickCumulative_now - tickCumulative_before) / timeDelta
	tickDelta := tickCumulatives[1] - tickCumulatives[0]
	twapTick := int32(tickDelta / int64(secondsAgo))
	if tickDelta < 0 && (tickDelta%int64(secondsAgo) != 0) {
		twapTick--
	}

	return twapTick, nil
}

func writeObservationByPool(
	p *pl.Pool,
	currentTime int64,
	tick int32,
	liquidity *u256.Uint,
) error {
	if p.ObservationState() == nil {
		p.SetObservationState(pl.NewObservationState(currentTime))
	}

	err := writeObservation(p.ObservationState(), currentTime, tick, liquidity)
	if err != nil {
		return err
	}

	return nil
}

func increaseObservationCardinalityLimitByPool(p *pl.Pool, observationCardinalityNext uint16) error {
	observationState := p.ObservationState()

	if observationState == nil {
		return errors.New("observation state not initialized")
	}

	if observationCardinalityNext > maxObservationCardinality {
		return errors.New("observation cardinality next exceeds maximum")
	}

	if observationCardinalityNext <= observationState.CardinalityLimit() {
		return errors.New("observation cardinality next must be greater than current")
	}

	observationState.SetCardinalityLimit(observationCardinalityNext)

	return nil
}

func transform(os *pl.ObservationState, currentTime int64, tick int32, liquidity *u256.Uint) (*pl.Observation, error) {
	lastObservation, err := lastObservation(os)
	if err != nil {
		return nil, err
	}

	timeDelta := currentTime - lastObservation.BlockTimestamp()
	if timeDelta < 0 {
		return nil, errors.New("time delta must be greater than 0")
	}

	if timeDelta == 0 {
		return lastObservation, nil
	}

	// calculate cumulative values
	tickCumulative := lastObservation.TickCumulative() + int64(tick)*timeDelta

	// calculate liquidity cumulative
	liquidityDelta, overflow := u256.Zero().MulOverflow(liquidity, u256.NewUintFromInt64(timeDelta))
	if overflow {
		panic(errOverflow)
	}

	liquidityCumulative := u256.Zero().Add(lastObservation.LiquidityCumulative(), liquidityDelta)

	// calculate seconds per liquidity
	secondsPerLiquidityCumulativeX128 := lastObservation.SecondsPerLiquidityCumulativeX128().Clone()
	liquidityForCalc := liquidity
	if liquidity.IsZero() {
		liquidityForCalc = u256.One()
	}
	// secondsPerLiquidity += timeDelta * 2^128 / max(1, liquidity)
	secondsPerLiquidityDelta := u256.MulDiv(
		u256.NewUintFromInt64(timeDelta),
		q128FromDecimal,
		liquidityForCalc,
	)
	secondsPerLiquidityCumulativeX128 = u256.Zero().Add(
		secondsPerLiquidityCumulativeX128,
		secondsPerLiquidityDelta,
	)

	return pl.NewObservation(
		currentTime,
		tickCumulative,
		liquidityCumulative,
		secondsPerLiquidityCumulativeX128,
		true,
	), nil
}

func grow(os *pl.ObservationState, currentCardinality, nextCardinality uint16) (uint16, error) {
	if currentCardinality == 0 {
		return currentCardinality, errors.New("current cardinality must not be 0")
	}

	if nextCardinality <= currentCardinality {
		return currentCardinality, nil
	}

	if nextCardinality > maxObservationCardinality {
		return currentCardinality, errors.New("nextCardinality exceeds maximum")
	}

	// This is more efficient than checking all slots from 0
	for i := currentCardinality; i < nextCardinality; i++ {
		if _, ok := os.Observations()[i]; !ok {
			// Create new observation slot
			os.Observations()[i] = pl.NewDefaultObservation()
		}
	}

	return nextCardinality, nil
}

func writeObservation(
	os *pl.ObservationState,
	currentTime int64,
	tick int32,
	liquidity *u256.Uint,
) error {
	lastObservation, err := lastObservation(os)
	if err != nil {
		return err
	}

	if lastObservation.BlockTimestamp() == currentTime {
		return nil
	}

	// Check if we need to grow the cardinality
	if os.CardinalityLimit() > os.Cardinality() && os.Index() == os.Cardinality()-1 {
		// Grow the observation array to the new cardinality limit
		newCardinality, err := grow(os, os.Cardinality(), os.CardinalityLimit())
		if err != nil {
			return err
		}

		os.SetCardinality(newCardinality)
	}

	nextIndex := (os.Index() + 1) % os.Cardinality()

	// Ensure the slot exists before writing
	if _, ok := os.Observations()[nextIndex]; !ok {
		os.Observations()[nextIndex] = pl.NewDefaultObservation()
	}

	observation, err := transform(os, currentTime, tick, liquidity)
	if err != nil {
		return err
	}

	os.Observations()[nextIndex] = observation
	os.SetIndex(nextIndex)

	return nil
}

func lastObservation(os *pl.ObservationState) (*pl.Observation, error) {
	observation, ok := os.Observations()[os.Index()]
	if !ok || observation == nil || !observation.Initialized() {
		return nil, errNotInitializedObservation
	}

	return observation, nil
}

// observationAt returns the observation at a specific index
// Returns error if the observation doesn't exist or is not initialized
func observationAt(os *pl.ObservationState, index uint16) (*pl.Observation, error) {
	obs, ok := os.Observations()[index]
	if !ok || obs == nil {
		return nil, errNotInitializedObservation
	}

	// Check if the observation is properly initialized
	if !obs.Initialized() {
		return nil, errNotInitializedObservation
	}

	return obs, nil
}

// observeSingle returns the data for a single observation at a specific time ago
func observeSingle(os *pl.ObservationState,
	currentTime int64,
	secondsAgo uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (int64, *u256.Uint, error) {
	if secondsAgo == 0 {
		// if secondsAgo is 0, return current values
		last, err := observationAt(os, index)
		if err != nil {
			return 0, nil, err
		}

		if last.BlockTimestamp() != currentTime {
			// need to create virtual observation for current time
			transformed, err := transform(os, currentTime, tick, liquidity)
			if err != nil {
				return 0, nil, err
			}

			return transformed.TickCumulative(), transformed.SecondsPerLiquidityCumulativeX128(), nil
		}

		return last.TickCumulative(), last.SecondsPerLiquidityCumulativeX128(), nil
	}

	target := currentTime - int64(secondsAgo)

	// find the observations before and after the target
	beforeOrAt, afterOrAt, err := getSurroundingObservations(
		os,
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

	if target <= beforeOrAt.BlockTimestamp() {
		return beforeOrAt.TickCumulative(), beforeOrAt.SecondsPerLiquidityCumulativeX128(), nil
	}

	if target == afterOrAt.BlockTimestamp() {
		return afterOrAt.TickCumulative(), afterOrAt.SecondsPerLiquidityCumulativeX128(), nil
	}

	// interpolate between the two observations
	observationTimeDelta := afterOrAt.BlockTimestamp() - beforeOrAt.BlockTimestamp()
	targetDelta := target - beforeOrAt.BlockTimestamp()

	// If the observations are at the same time, return the before observation
	if observationTimeDelta == 0 {
		return beforeOrAt.TickCumulative(), beforeOrAt.SecondsPerLiquidityCumulativeX128(), nil
	}

	// tickCumulative += (tickCumulativeAfter - tickCumulativeBefore) * targetDelta / observationTimeDelta
	tickCumulative := beforeOrAt.TickCumulative() +
		(afterOrAt.TickCumulative()-beforeOrAt.TickCumulative())*targetDelta/observationTimeDelta

	// for secondsPerLiquidity, need to interpolate carefully
	secondsPerLiquidityDelta := u256.Zero().Sub(
		afterOrAt.SecondsPerLiquidityCumulativeX128(),
		beforeOrAt.SecondsPerLiquidityCumulativeX128(),
	)

	secondsPerLiquidity := u256.Zero().Add(
		beforeOrAt.SecondsPerLiquidityCumulativeX128(),
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
func getSurroundingObservations(os *pl.ObservationState,
	target int64,
	currentTime int64,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (*pl.Observation, *pl.Observation, error) {
	// Get the latest observation
	latest, err := observationAt(os, index)
	if err != nil {
		return nil, nil, err
	}

	// If target is at or after the latest observation, extrapolate to current time
	if target >= latest.BlockTimestamp() {
		// If latest is already at current time, return it as both before and after
		if latest.BlockTimestamp() == currentTime {
			return latest, latest, nil
		}

		// Create a virtual observation for current time
		afterOrAt, err := transform(os, currentTime, tick, liquidity)
		if err != nil {
			return nil, nil, err
		}

		return latest, afterOrAt, nil
	}

	// Handle single cardinality case
	if cardinality == 1 {
		// Check if target is before the oldest (and only) observation
		if target < latest.BlockTimestamp() {
			return nil, nil, errObservationTooOld
		}
		return latest, latest, nil
	}

	// Binary search over the logical time-ordered circular buffer
	// start points to the oldest observation: (index + 1) % cardinality
	start := (index + 1) % cardinality

	// Get oldest observation
	// If the oldest slot is not initialized, use slot 0 (like Uniswap V3)
	oldest, err := observationAt(os, start)
	if err != nil {
		// If uninitialized, fall back to slot 0
		oldest, err = observationAt(os, 0)
		if err != nil {
			return nil, nil, err
		}
		start = 0
	}

	// Check if target is before the oldest observation
	if target < oldest.BlockTimestamp() {
		return nil, nil, errObservationTooOld
	}

	// Helper function to access observations in logical order
	at := func(k uint16) (*pl.Observation, error) {
		physicalIdx := (start + k) % cardinality
		return observationAt(os, physicalIdx)
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

		if obs.BlockTimestamp() <= target {
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
	if beforeOrAt.BlockTimestamp() > target {
		// This shouldn't happen in normal cases, but handle it defensively
		// If the first observation is after target, use it for both
		afterOrAt = beforeOrAt
	}

	return beforeOrAt, afterOrAt, nil
}

// observe returns the cumulative tick and liquidity as of each timestamp secondsAgo from the current time.
func observe(os *pl.ObservationState,
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
		tickCumulative, secondsPerLiquidity, err := observeSingle(
			os,
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
