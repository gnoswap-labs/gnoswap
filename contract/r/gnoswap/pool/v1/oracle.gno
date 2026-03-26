package v1

import (
	"errors"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	pl "gno.land/r/gnoswap/pool"
)

var max160 = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One()) // 2^160 - 1

// maxObservationCardinality defines the maximum number of observations to store
const maxObservationCardinality uint16 = 65535

// decodeU256 converts a decimal string to *u256.Uint
func decodeU256(s string) *u256.Uint {
	if s == "" || s == "0" {
		return u256.Zero()
	}
	return u256.MustFromDecimal(s)
}

// getTWAP calculates the time-weighted average price between two points in time
// Returns the arithmetic mean tick and harmonic mean liquidity over the time period
func getTWAP(p *pl.Pool, secondsAgo uint32) (int32, *u256.Uint, error) {
	if secondsAgo == 0 {
		return 0, nil, errors.New("secondsAgo must be greater than 0")
	}

	os := p.ObservationState()
	if os.Cardinality() == 0 {
		return 0, nil, errors.New("observation state not initialized")
	}

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	currentTime := time.Now().Unix()

	tickCumulatives, secondsPerLiquidityCumulativeX128s, err := observe(
		os,
		currentTime,
		secondsAgos,
		p.Slot0Tick(),
		os.Index(),
		p.Liquidity(),
		os.Cardinality(),
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
	if p.ObservationState().Cardinality() == 0 {
		p.SetObservationState(pl.NewObservationState(currentTime))
	}

	os, err := writeObservation(p.ObservationState(), currentTime, tick, liquidity)
	if err != nil {
		return err
	}
	p.SetObservationState(os)

	return nil
}

func increaseObservationCardinalityNextByPool(p *pl.Pool, observationCardinalityNext uint16) error {
	os := p.ObservationState()

	if os.Cardinality() == 0 {
		return errors.New("observation state not initialized")
	}

	if observationCardinalityNext > maxObservationCardinality {
		return errors.New("observation cardinality next exceeds maximum")
	}

	if observationCardinalityNext <= os.CardinalityNext() {
		return errors.New("observation cardinality next must be greater than current")
	}

	os, observationCardinalityNextNew, err := grow(os, os.Cardinality(), observationCardinalityNext)
	if err != nil {
		return err
	}

	os.SetCardinalityNext(observationCardinalityNextNew)
	p.SetObservationState(os)

	return nil
}

func transform(last pl.Observation, currentTime int64, tick int32, liquidity *u256.Uint) (pl.Observation, error) {
	timeDelta := currentTime - last.BlockTimestamp()
	if timeDelta < 0 {
		return pl.Observation{}, errors.New("time delta must be greater than 0")
	}

	// calculate cumulative values
	tickCumulative := last.TickCumulative() + int64(tick)*timeDelta

	// decode string → u256 for computation
	lastLiqCum := decodeU256(last.LiquidityCumulative())
	lastSecPerLiq := decodeU256(last.SecondsPerLiquidityCumulativeX128())

	// calculate liquidity cumulative
	liquidityDelta, overflow := u256.Zero().MulOverflow(liquidity, u256.NewUintFromInt64(timeDelta))
	if overflow {
		panic(errOverflow)
	}

	liquidityCumulative := u256.Zero().Add(lastLiqCum, liquidityDelta)

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

	secondsPerLiquidityCumulativeX128 := u256.Zero().Add(
		lastSecPerLiq,
		secondsPerLiquidityDelta,
	)

	// encode u256 → string for storage
	return pl.NewObservation(
		currentTime,
		tickCumulative,
		liquidityCumulative.ToString(),
		secondsPerLiquidityCumulativeX128.ToString(),
		true,
	), nil
}

func grow(os pl.ObservationState, currentCardinality, nextCardinality uint16) (pl.ObservationState, uint16, error) {
	if currentCardinality <= 0 {
		return os, currentCardinality, errors.New("currentCardinality must be greater than 0")
	}

	if nextCardinality <= currentCardinality {
		return os, currentCardinality, nil
	}

	if nextCardinality > maxObservationCardinality {
		return os, currentCardinality, errors.New("nextCardinality exceeds maximum")
	}

	for i := currentCardinality; i < nextCardinality; i++ {
		obs := pl.NewDefaultObservation()
		obs.SetBlockTimestamp(1)
		os.Observations()[i] = obs
	}

	return os, nextCardinality, nil
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
	os pl.ObservationState,
	currentTime int64,
	tick int32,
	liquidity *u256.Uint,
) (pl.ObservationState, error) {
	last, err := lastObservation(os)
	if err != nil {
		return os, err
	}

	if last.BlockTimestamp() == currentTime {
		return os, nil
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

	observation, err := transform(last, currentTime, tick, liquidity)
	if err != nil {
		return os, err
	}

	os.Observations()[nextIndex] = observation
	os.SetIndex(nextIndex)

	return os, nil
}

func lastObservation(os pl.ObservationState) (pl.Observation, error) {
	observation, ok := os.Observations()[os.Index()]
	if !ok {
		return pl.Observation{}, errNotInitializedObservation
	}

	return observation, nil
}

// observationAt returns the observation at a specific index
// Returns error if the observation doesn't exist
func observationAt(os pl.ObservationState, index uint16) (pl.Observation, error) {
	obs, ok := os.Observations()[index]
	if !ok {
		return pl.Observation{}, errNotInitializedObservation
	}

	return obs, nil
}

// observeSingle returns the data for a single observation at a specific time ago
func observeSingle(
	os pl.ObservationState,
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

			return transformed.TickCumulative(), decodeU256(transformed.SecondsPerLiquidityCumulativeX128()), nil
		}

		return last.TickCumulative(), decodeU256(last.SecondsPerLiquidityCumulativeX128()), nil
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
		return beforeOrAt.TickCumulative(), decodeU256(beforeOrAt.SecondsPerLiquidityCumulativeX128()), nil
	}

	if target == atOrAfter.BlockTimestamp() {
		return atOrAfter.TickCumulative(), decodeU256(atOrAfter.SecondsPerLiquidityCumulativeX128()), nil
	}

	// interpolate between the two observations
	observationTimeDelta := atOrAfter.BlockTimestamp() - beforeOrAt.BlockTimestamp()
	targetDelta := target - beforeOrAt.BlockTimestamp()

	// tickCumulative += (tickCumulativeAfter - tickCumulativeBefore) / observationTimeDelta * targetDelta
	tickCumulative := beforeOrAt.TickCumulative() +
		((atOrAfter.TickCumulative()-beforeOrAt.TickCumulative())/observationTimeDelta)*targetDelta

	// for secondsPerLiquidity, need to interpolate carefully
	beforeSecPerLiq := decodeU256(beforeOrAt.SecondsPerLiquidityCumulativeX128())
	afterSecPerLiq := decodeU256(atOrAfter.SecondsPerLiquidityCumulativeX128())

	secondsPerLiquidityDelta := u256.Zero().Sub(afterSecPerLiq, beforeSecPerLiq)

	secondsPerLiquidity := u256.Zero().Add(
		beforeSecPerLiq,
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
	os pl.ObservationState,
	target int64,
	currentTime int64,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (pl.Observation, pl.Observation, error) {
	// Optimistically set before to the newest observation
	beforeOrAt, err := observationAt(os, index)
	if err != nil {
		return pl.Observation{}, pl.Observation{}, err
	}

	// If the target is chronologically at or after the newest observation, we can early return
	if lte(currentTime, beforeOrAt.BlockTimestamp(), target) {
		if beforeOrAt.BlockTimestamp() == target {
			// If newest observation equals target, we're in the same block, so we can ignore atOrAfter
			return beforeOrAt, pl.Observation{}, nil
		}
		// Otherwise, we need to transform
		atOrAfter, err := transform(beforeOrAt, target, tick, liquidity)
		if err != nil {
			return pl.Observation{}, pl.Observation{}, err
		}
		return beforeOrAt, atOrAfter, nil
	}

	// Now, set before to the oldest observation
	start := (index + 1) % cardinality
	beforeOrAt, err = observationAt(os, start)
	if err != nil || !beforeOrAt.Initialized() {
		beforeOrAt, err = observationAt(os, 0)
		if err != nil {
			return pl.Observation{}, pl.Observation{}, err
		}
	}

	// Ensure that the target is chronologically at or after the oldest observation
	if !lte(currentTime, beforeOrAt.BlockTimestamp(), target) {
		return pl.Observation{}, pl.Observation{}, errObservationTooOld
	}

	// If we've reached this point, we have to binary search
	return binarySearch(os, currentTime, target, index, cardinality)
}

func binarySearch(
	os pl.ObservationState,
	currentTime int64,
	target int64,
	index uint16,
	cardinality uint16,
) (pl.Observation, pl.Observation, error) {
	l := uint64((index + 1) % cardinality) // oldest observation
	r := l + uint64(cardinality) - 1       // newest observation
	var i uint64
	var beforeOrAt, atOrAfter pl.Observation
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
			return pl.Observation{}, pl.Observation{}, err
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
	os pl.ObservationState,
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
