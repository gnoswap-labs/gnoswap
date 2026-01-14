package v4

import (
	"errors"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	pl "gno.land/r/gnoswap/pool"
)

var max160 = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One()) // 2^160 - 1

// maxObservationCardinality defines the maximum number of observations to store
const maxObservationCardinality uint16 = 65535

// GetTWAP calculates the time-weighted average price between two points in time
// Returns the arithmetic mean tick and harmonic mean liquidity over the time period
func getTWAP(p *pl.Pool, secondsAgo uint32) (int32, *u256.Uint, error) {
	if secondsAgo == 0 {
		return 0, nil, errors.New("secondsAgo must be greater than 0")
	}

	if p.ObservationState() == nil {
		return 0, nil, errors.New("observation state not initialized")
	}

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	currentTime := time.Now().Unix()

	tickCumulatives, secondsPerLiquidityCumulativeX128s, err := observe(
		p.ObservationState(),
		currentTime,
		secondsAgos,
		p.Slot0Tick(),
		p.ObservationState().Index(),
		p.Liquidity(),
		p.ObservationState().Cardinality(),
	)
	if err != nil {
		return 0, nil, err
	}

	tickCumulativesDelta := tickCumulatives[1] - tickCumulatives[0]
	secondsPerLiquidityDelta := u256.Zero().Sub(
		secondsPerLiquidityCumulativeX128s[1],
		secondsPerLiquidityCumulativeX128s[0],
	)

	arithmeticMeanTick := int32(tickCumulativesDelta / int64(secondsAgo))
	if tickCumulativesDelta < 0 && (tickCumulativesDelta%int64(secondsAgo) != 0) {
		arithmeticMeanTick--
	}

	if secondsPerLiquidityDelta.IsZero() {
		return arithmeticMeanTick, u256.Zero(), nil
	}

	// Calculate harmonic mean liquidity
	secondsAgoX160 := u256.Zero().Mul(u256.NewUint(uint64(secondsAgo)), max160)
	denominator := u256.Zero().Lsh(secondsPerLiquidityDelta, 32)
	harmonicMeanLiquidity := u256.Zero().Div(secondsAgoX160, denominator)

	return arithmeticMeanTick, harmonicMeanLiquidity, nil
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

func increaseObservationCardinalityNextByPool(p *pl.Pool, observationCardinalityNext uint16) error {
	observationState := p.ObservationState()

	if observationState == nil {
		return errors.New("observation state not initialized")
	}

	if observationCardinalityNext > maxObservationCardinality {
		return errors.New("observation cardinality next exceeds maximum")
	}

	if observationCardinalityNext <= observationState.CardinalityNext() {
		return errors.New("observation cardinality next must be greater than current")
	}

	observationCardinalityNextNew, err := grow(observationState, observationState.Cardinality(), observationCardinalityNext)
	if err != nil {
		return err
	}

	observationState.SetCardinalityNext(observationCardinalityNextNew)

	return nil
}

func transform(lastObservation *pl.Observation, currentTime int64, tick int32, liquidity *u256.Uint) (*pl.Observation, error) {
	timeDelta := currentTime - lastObservation.BlockTimestamp()
	if timeDelta < 0 {
		return nil, errors.New("time delta must be greater than 0")
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

	secondsPerLiquidityCumulativeX128 := lastObservation.SecondsPerLiquidityCumulativeX128().Clone()
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
	if currentCardinality <= 0 {
		return currentCardinality, errors.New("currentCardinality must be greater than 0")
	}

	if nextCardinality <= currentCardinality {
		return currentCardinality, nil
	}

	if nextCardinality > maxObservationCardinality {
		return currentCardinality, errors.New("nextCardinality exceeds maximum")
	}

	// This is more efficient than checking all slots from 0
	for i := currentCardinality; i < nextCardinality; i++ {
		observation := pl.NewDefaultObservation()
		observation.SetBlockTimestamp(1)
		os.Observations()[i] = observation
	}

	return nextCardinality, nil
}

func lte(time, a, b int64) bool {
	if (a <= time) && (time <= b) {
		return a <= b
	}

	aAdjusted := u256.NewUintFromInt64(a)
	bAdjusted := u256.NewUintFromInt64(b)
	timeUint256 := u256.NewUintFromInt64(time)

	if aAdjusted.Gt(timeUint256) {
		aAdjusted = aAdjusted.Add(aAdjusted, u256.NewUintFromInt64(1<<32))
	}

	if bAdjusted.Gt(timeUint256) {
		bAdjusted = bAdjusted.Add(bAdjusted, u256.NewUintFromInt64(1<<32))
	}

	return aAdjusted.Lte(bAdjusted)
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
	if os.CardinalityNext() > os.Cardinality() && os.Index() == os.Cardinality()-1 {
		os.SetCardinality(os.CardinalityNext())
	}

	nextIndex := (os.Index() + 1) % os.Cardinality()

	// Ensure the slot exists before writing
	if _, ok := os.Observations()[nextIndex]; !ok {
		os.Observations()[nextIndex] = pl.NewDefaultObservation()
	}

	observation, err := transform(lastObservation, currentTime, tick, liquidity)
	if err != nil {
		return err
	}

	os.Observations()[nextIndex] = observation
	os.SetIndex(nextIndex)

	return nil
}

func lastObservation(os *pl.ObservationState) (*pl.Observation, error) {
	observation, ok := os.Observations()[os.Index()]
	if !ok || observation == nil {
		return nil, errNotInitializedObservation
	}

	return observation, nil
}

// observationAt returns the observation at a specific index
// Returns error if the observation doesn't exist
func observationAt(os *pl.ObservationState, index uint16) (*pl.Observation, error) {
	obs, ok := os.Observations()[index]
	if !ok || obs == nil {
		return nil, errNotInitializedObservation
	}

	return obs, nil
}

// observeSingle returns the data for a single observation at a specific time ago
func observeSingle(
	os *pl.ObservationState,
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
			transformed, err := transform(last, currentTime, tick, liquidity)
			if err != nil {
				return 0, nil, err
			}

			return transformed.TickCumulative(), transformed.SecondsPerLiquidityCumulativeX128(), nil
		}

		return last.TickCumulative(), last.SecondsPerLiquidityCumulativeX128(), nil
	}

	target := currentTime - int64(secondsAgo)

	// find the observations before and after the target
	beforeOrAt, atOrAfter, err := getSurroundingObservations(
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

	if target == beforeOrAt.BlockTimestamp() {
		return beforeOrAt.TickCumulative(), beforeOrAt.SecondsPerLiquidityCumulativeX128(), nil
	}

	if target == atOrAfter.BlockTimestamp() {
		return atOrAfter.TickCumulative(), atOrAfter.SecondsPerLiquidityCumulativeX128(), nil
	}

	// interpolate between the two observations
	observationTimeDelta := atOrAfter.BlockTimestamp() - beforeOrAt.BlockTimestamp()
	targetDelta := target - beforeOrAt.BlockTimestamp()

	// tickCumulative += (tickCumulativeAfter - tickCumulativeBefore) / observationTimeDelta * targetDelta
	tickCumulative := beforeOrAt.TickCumulative() +
		((atOrAfter.TickCumulative()-beforeOrAt.TickCumulative())/observationTimeDelta)*targetDelta

	// for secondsPerLiquidity, need to interpolate carefully
	secondsPerLiquidityDelta := u256.Zero().Sub(
		atOrAfter.SecondsPerLiquidityCumulativeX128(),
		beforeOrAt.SecondsPerLiquidityCumulativeX128(),
	)

	secondsPerLiquidity := u256.Zero().Add(
		beforeOrAt.SecondsPerLiquidityCumulativeX128(),
		u256.MulDiv(
			secondsPerLiquidityDelta,
			u256.NewUintFromInt64(targetDelta),
			u256.NewUintFromInt64(observationTimeDelta),
		),
	)

	return tickCumulative, secondsPerLiquidity, nil
}

// getSurroundingObservations finds the observations immediately before and after the target timestamp.
// It uses binary search over the logical time-ordered view of the circular buffer.
// Logical order starts at (index+1) % cardinality (oldest) and ends at index (latest).
func getSurroundingObservations(
	os *pl.ObservationState,
	target int64,
	currentTime int64,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (*pl.Observation, *pl.Observation, error) {
	// Optimistically set before to the newest observation
	beforeOrAt, err := observationAt(os, index)
	if err != nil {
		return nil, nil, err
	}

	// If the target is chronologically at or after the newest observation, we can early return
	if lte(currentTime, beforeOrAt.BlockTimestamp(), target) {
		if beforeOrAt.BlockTimestamp() == target {
			// If newest observation equals target, we're in the same block, so we can ignore atOrAfter
			return beforeOrAt, nil, nil
		}
		// Otherwise, we need to transform
		atOrAfter, err := transform(beforeOrAt, target, tick, liquidity)
		if err != nil {
			return nil, nil, err
		}
		return beforeOrAt, atOrAfter, nil
	}

	// Now, set before to the oldest observation
	start := (index + 1) % cardinality
	beforeOrAt, err = observationAt(os, start)
	if err != nil || !beforeOrAt.Initialized() {
		beforeOrAt, err = observationAt(os, 0)
		if err != nil {
			return nil, nil, err
		}
	}

	// Ensure that the target is chronologically at or after the oldest observation
	if !lte(currentTime, beforeOrAt.BlockTimestamp(), target) {
		return nil, nil, errObservationTooOld
	}

	// If we've reached this point, we have to binary search
	return binarySearch(os, currentTime, target, index, cardinality)
}

func binarySearch(
	os *pl.ObservationState,
	currentTime int64,
	target int64,
	index uint16,
	cardinality uint16,
) (*pl.Observation, *pl.Observation, error) {
	l := uint64((index + 1) % cardinality) // oldest observation
	r := l + uint64(cardinality) - 1       // newest observation
	var i uint64
	var beforeOrAt, atOrAfter *pl.Observation
	var err error

	for {
		i = (l + r) / 2

		beforeIndex := uint16(i % uint64(cardinality))
		beforeOrAt, err = observationAt(os, beforeIndex)
		if err != nil || !beforeOrAt.Initialized() {
			// we've landed on an uninitialized tick, keep searching higher (more recently)
			l = i + 1
			continue
		}

		afterIndex := uint16((i + 1) % uint64(cardinality))
		atOrAfter, err = observationAt(os, afterIndex)
		if err != nil {
			return nil, nil, err
		}

		targetAtOrAfter := lte(currentTime, beforeOrAt.BlockTimestamp(), target)

		// check if we've found the answer!
		if targetAtOrAfter && lte(currentTime, target, atOrAfter.BlockTimestamp()) {
			break
		}

		if !targetAtOrAfter {
			r = i - 1
		} else {
			l = i + 1
		}
	}

	return beforeOrAt, atOrAfter, nil
}

// observe returns the cumulative tick and liquidity as of each timestamp secondsAgo from the current time.
func observe(
	os *pl.ObservationState,
	currentTime int64,
	secondsAgos []uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) ([]int64, []*u256.Uint, error) {
	if cardinality <= 0 {
		return nil, nil, errors.New("observation cardinality must be greater than 0")
	}

	historyCount := len(secondsAgos)
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
