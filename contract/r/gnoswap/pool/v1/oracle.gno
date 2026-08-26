package pool

import (
	"errors"
	"time"

	"gno.land/p/gnoswap/consts"
	u256 "gno.land/p/gnoswap/uint256"
	pl "gno.land/r/gnoswap/pool"
)

// maxObservationCardinality defines the maximum number of observations to store
const maxObservationCardinality uint16 = 65535

// GetTWAP calculates the time-weighted average price between two points in time
// Returns the arithmetic mean tick and harmonic mean liquidity over the time period
func getTWAP(p *pl.Pool, secondsAgo uint32) (int32, *u256.Uint, error) {
	if secondsAgo == 0 {
		return 0, nil, errors.New("secondsAgo must be greater than 0")
	}

	observationState := p.ObservationState()
	if observationState == nil {
		return 0, nil, errors.New("observation state not initialized")
	}
	slot0 := p.Slot0()

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	blockTimestamp := time.Now().Unix()

	tickCumulatives, secondsPerLiquidityCumulativeX128s, err := observe(
		observationState,
		blockTimestamp,
		secondsAgos,
		slot0.Tick(),
		slot0.ObservationIndex(),
		p.Liquidity(),
		slot0.ObservationCardinality(),
	)
	if err != nil {
		return 0, nil, err
	}

	tickCumulativesDelta := tickCumulatives[1] - tickCumulatives[0]
	secondsPerLiquidityDelta := u256.Zero().Sub(
		u256.MustFromDecimal(secondsPerLiquidityCumulativeX128s[1]),
		u256.MustFromDecimal(secondsPerLiquidityCumulativeX128s[0]),
	)

	arithmeticMeanTick := int32(tickCumulativesDelta / int64(secondsAgo))
	if tickCumulativesDelta < 0 && (tickCumulativesDelta%int64(secondsAgo) != 0) {
		arithmeticMeanTick--
	}

	if secondsPerLiquidityDelta.IsZero() {
		return arithmeticMeanTick, u256.Zero(), nil
	}

	// Calculate harmonic mean liquidity
	secondsAgoX160 := u256.Zero().Mul(u256.NewUint(uint64(secondsAgo)), consts.Max160())
	denominator := u256.Zero().Lsh(secondsPerLiquidityDelta, 32)
	harmonicMeanLiquidity := u256.Zero().Div(secondsAgoX160, denominator)

	return arithmeticMeanTick, harmonicMeanLiquidity, nil
}

func transform(last *pl.Observation, blockTimestamp int64, tick int32, liquidity *u256.Uint) (*pl.Observation, error) {
	timeDelta := blockTimestamp - last.BlockTimestamp()
	if timeDelta < 0 {
		return nil, errors.New("time delta must be greater than 0")
	}

	// calculate cumulative values
	tickCumulative := last.TickCumulative() + int64(tick)*timeDelta

	// calculate seconds per liquidity
	liquidityForCalc := liquidity
	if liquidity.IsZero() {
		liquidityForCalc = u256.One()
	}

	// secondsPerLiquidity += timeDelta * 2^128 / max(1, liquidity)
	secondsPerLiquidityDelta := u256.MulDiv(
		u256.NewUintFromInt64(timeDelta),
		consts.Q128(),
		liquidityForCalc,
	)

	prevSecPerLiq := u256.MustFromDecimal(last.SecondsPerLiquidityCumulativeX128())
	secondsPerLiquidityCumulativeX128 := u256.Zero().Add(
		prevSecPerLiq,
		secondsPerLiquidityDelta,
	)

	return pl.NewObservation(
		blockTimestamp,
		tickCumulative,
		secondsPerLiquidityCumulativeX128.ToString(),
		true,
	), nil
}

func grow(os *pl.ObservationState, current, next uint16) (uint16, error) {
	if os == nil {
		return current, errors.New("observation state not initialized")
	}

	if current <= 0 {
		return current, errors.New("current must be greater than 0")
	}

	if next <= current {
		return current, nil
	}

	if next > maxObservationCardinality {
		return current, errors.New("next exceeds maximum")
	}

	// This is more efficient than checking all slots from 0
	for i := current; i < next; i++ {
		observation := pl.NewDefaultObservation()
		observation.SetBlockTimestamp(1)
		os.SetObservation(i, observation)
	}

	return next, nil
}

func writeObservation(
	os *pl.ObservationState,
	index uint16,
	blockTimestamp int64,
	tick int32,
	liquidity *u256.Uint,
	cardinality uint16,
	cardinalityNext uint16,
) (indexUpdated uint16, cardinalityUpdated uint16, err error) {
	if os == nil {
		return 0, 0, errors.New("observation state not initialized")
	}
	if cardinality == 0 {
		return 0, 0, errors.New("observation cardinality must be greater than 0")
	}

	last, err := observationAt(os, index)
	if err != nil {
		return 0, 0, err
	}

	if last.BlockTimestamp() == blockTimestamp {
		return index, cardinality, nil
	}

	// Check if we need to grow the cardinality
	if cardinalityNext > cardinality && index == cardinality-1 {
		cardinalityUpdated = cardinalityNext
	} else {
		cardinalityUpdated = cardinality
	}

	indexUpdated = (index + 1) % cardinalityUpdated

	// Ensure the slot exists before writing
	if _, ok := os.ObservationAt(indexUpdated); !ok {
		os.SetObservation(indexUpdated, pl.NewDefaultObservation())
	}

	observation, err := transform(last, blockTimestamp, tick, liquidity)
	if err != nil {
		return 0, 0, err
	}

	os.SetObservation(indexUpdated, observation)
	return indexUpdated, cardinalityUpdated, nil
}

// observationAt returns the observation at a specific index
// Returns error if the observation doesn't exist
func observationAt(os *pl.ObservationState, index uint16) (*pl.Observation, error) {
	obs, ok := os.ObservationAt(index)
	if !ok || obs == nil {
		return nil, errors.New(errNotInitializedObservation)
	}

	return obs, nil
}

// observeSingle returns the data for a single observation at a specific time ago
func observeSingle(
	os *pl.ObservationState,
	time int64,
	secondsAgo uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (int64, string, error) {
	if secondsAgo == 0 {
		// if secondsAgo is 0, return current values
		last, err := observationAt(os, index)
		if err != nil {
			return 0, "", err
		}

		if last.BlockTimestamp() != time {
			// need to create virtual observation for current time
			transformed, err := transform(last, time, tick, liquidity)
			if err != nil {
				return 0, "", err
			}

			return transformed.TickCumulative(), transformed.SecondsPerLiquidityCumulativeX128(), nil
		}

		return last.TickCumulative(), last.SecondsPerLiquidityCumulativeX128(), nil
	}

	// A lookback longer than the chain's own age would place the target before unix epoch.
	if int64(secondsAgo) > time {
		return 0, "", errors.New(errObservationBeforeEpoch)
	}

	target := time - int64(secondsAgo)

	// find the observations before and after the target
	beforeOrAt, atOrAfter, err := getSurroundingObservations(
		os,
		target,
		tick,
		index,
		liquidity,
		cardinality,
	)
	if err != nil {
		return 0, "", err
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

	beforeSecPerLiq := u256.MustFromDecimal(beforeOrAt.SecondsPerLiquidityCumulativeX128())
	afterSecPerLiq := u256.MustFromDecimal(atOrAfter.SecondsPerLiquidityCumulativeX128())

	// for secondsPerLiquidity, need to interpolate carefully
	secondsPerLiquidityDelta := u256.Zero().Sub(afterSecPerLiq, beforeSecPerLiq)

	secondsPerLiquidity := u256.Zero().Add(
		beforeSecPerLiq,
		u256.MulDiv(
			secondsPerLiquidityDelta,
			u256.NewUintFromInt64(targetDelta),
			u256.NewUintFromInt64(observationTimeDelta),
		),
	)

	return tickCumulative, secondsPerLiquidity.ToString(), nil
}

// getSurroundingObservations finds the observations immediately before and after the target timestamp.
// It uses binary search over the logical time-ordered view of the circular buffer.
// Logical order starts at (index+1) % cardinality (oldest) and ends at index (latest).
func getSurroundingObservations(
	os *pl.ObservationState,
	target int64,
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

	// Timestamps are int64, so natural ordering applies. Uniswap V3 needs a
	// wraparound-aware comparison here only because it stores them as uint32.
	// If the target is chronologically at or after the newest observation, we can early return
	if beforeOrAt.BlockTimestamp() <= target {
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
	if beforeOrAt.BlockTimestamp() > target {
		return nil, nil, errors.New(errObservationTooOld)
	}

	// If we've reached this point, we have to binary search
	return binarySearch(os, target, index, cardinality)
}

func binarySearch(
	os *pl.ObservationState,
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

		targetAtOrAfter := beforeOrAt.BlockTimestamp() <= target

		// check if we've found the answer!
		if targetAtOrAfter && target <= atOrAfter.BlockTimestamp() {
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
	time int64,
	secondsAgos []uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) ([]int64, []string, error) {
	if cardinality <= 0 {
		return nil, nil, errors.New("observation cardinality must be greater than 0")
	}

	historyCount := len(secondsAgos)
	tickCumulatives := make([]int64, historyCount)
	secondsPerLiquidityCumulativeX128s := make([]string, historyCount)

	for i, secondsAgo := range secondsAgos {
		tickCumulative, secondsPerLiquidity, err := observeSingle(
			os,
			time,
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
