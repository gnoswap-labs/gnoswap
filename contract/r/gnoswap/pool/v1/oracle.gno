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

// oracleConsult calculates the time-weighted average price between two points in time.
// It returns the arithmetic mean tick and harmonic mean liquidity over the time period.
//
// Parameters:
//   - p: pool whose current tick, price, and active liquidity anchor the consultation.
//   - observations: circular observation tree containing historical oracle samples.
//   - secondsAgo: positive lookback duration in seconds from the current block time.
//
// Returns:
//   - int32: arithmetic mean tick over the lookback, rounded toward negative infinity.
//   - *u256.Uint: harmonic mean liquidity over the lookback, or zero when no liquidity growth accrued.
//   - error: non-nil when the lookback is zero, observations are unavailable, or consultation fails.
func oracleConsult(p *pl.Pool, observations *pl.ObservationTree, secondsAgo uint32) (int32, *u256.Uint, error) {
	if secondsAgo == 0 {
		return 0, nil, errors.New("secondsAgo must be greater than 0")
	}

	if observations == nil {
		return 0, nil, errors.New("observations not initialized")
	}
	slot0 := p.Slot0()

	// Get observations for current time and secondsAgo
	secondsAgos := []uint32{secondsAgo, 0}
	blockTimestamp := time.Now().Unix()

	tickCumulatives, secondsPerLiquidityCumulativeX128s, err := observe(
		observations,
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

// snapshotCumulativesInside returns the accumulators that accrued while the
// current price was inside [tickLower, tickUpper), following Uniswap V3's
// snapshotCumulativesInside flow.
//
// Parameters:
//   - p: pool whose current tick and initialized boundary ticks define the range state.
//   - observations: observation tree used to obtain a current cumulative snapshot when price is in range.
//   - tickLower: inclusive lower tick boundary of the position range.
//   - tickUpper: exclusive upper tick boundary of the position range.
//
// Returns:
//   - int64: cumulative tick value accrued inside the range.
//   - *u256.Uint: seconds-per-liquidity accumulator accrued inside, scaled by 2^128.
//   - uint32: seconds spent with the price inside the range.
//   - error: non-nil when bounds are invalid, a boundary is uninitialized, or observations cannot be read.
func snapshotCumulativesInside(
	p *pl.Pool,
	observations *pl.ObservationTree,
	tickLower int32,
	tickUpper int32,
) (int64, *u256.Uint, uint32, error) {
	if err := validateTicks(tickLower, tickUpper); err != nil {
		return 0, nil, 0, err
	}

	lower := getTick(p, tickLower)
	if !lower.Initialized() {
		return 0, nil, 0, makeErrorWithDetails(errDataNotFound, "lower tick is not initialized")
	}

	upper := getTick(p, tickUpper)
	if !upper.Initialized() {
		return 0, nil, 0, makeErrorWithDetails(errDataNotFound, "upper tick is not initialized")
	}

	lowerSecondsPerLiquidityOutsideX128 := u256.MustFromDecimal(lower.SecondsPerLiquidityOutsideX128())
	upperSecondsPerLiquidityOutsideX128 := u256.MustFromDecimal(upper.SecondsPerLiquidityOutsideX128())
	slot0 := p.Slot0()

	if slot0.Tick() < tickLower {
		return lower.TickCumulativeOutside() - upper.TickCumulativeOutside(),
			u256.Zero().Sub(lowerSecondsPerLiquidityOutsideX128, upperSecondsPerLiquidityOutsideX128),
			lower.SecondsOutside() - upper.SecondsOutside(), nil
	}

	if slot0.Tick() < tickUpper {
		if observations == nil {
			return 0, nil, 0, errors.New("observations not initialized")
		}

		currentTime := time.Now().Unix()
		tickCumulative, secondsPerLiquidityCumulativeX128, err := observeSingle(
			observations,
			currentTime,
			0,
			slot0.Tick(),
			slot0.ObservationIndex(),
			p.Liquidity(),
			slot0.ObservationCardinality(),
		)
		if err != nil {
			return 0, nil, 0, err
		}

		secondsPerLiquidityInsideX128 := u256.Zero().Sub(
			u256.Zero().Sub(
				u256.MustFromDecimal(secondsPerLiquidityCumulativeX128),
				lowerSecondsPerLiquidityOutsideX128,
			),
			upperSecondsPerLiquidityOutsideX128,
		)

		return tickCumulative - lower.TickCumulativeOutside() - upper.TickCumulativeOutside(),
			secondsPerLiquidityInsideX128,
			uint32(currentTime) - lower.SecondsOutside() - upper.SecondsOutside(), nil
	}

	return upper.TickCumulativeOutside() - lower.TickCumulativeOutside(),
		u256.Zero().Sub(upperSecondsPerLiquidityOutsideX128, lowerSecondsPerLiquidityOutsideX128),
		upper.SecondsOutside() - lower.SecondsOutside(), nil
}

// transform creates an observation at blockTimestamp from the previous observation.
//
// Parameters:
//   - last: previous initialized observation used as the cumulative baseline.
//   - blockTimestamp: timestamp for the new observation; it must not precede last's timestamp.
//   - tick: current tick applied over the elapsed interval.
//   - liquidity: active liquidity used for seconds-per-liquidity accumulation; zero is treated as one.
//
// Returns:
//   - pl.Observation: observation with updated tick and seconds-per-liquidity cumulatives.
//   - error: non-nil when blockTimestamp is earlier than the previous observation.
func transform(last pl.Observation, blockTimestamp int64, tick int32, liquidity *u256.Uint) (pl.Observation, error) {
	timeDelta := blockTimestamp - last.BlockTimestamp()
	if timeDelta < 0 {
		return pl.DefaultObservation(), errors.New("time delta must be greater than 0")
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

	observation := pl.MakeObservation(
		blockTimestamp,
		tickCumulative,
		secondsPerLiquidityCumulativeX128.ToString(),
		true,
	)
	return observation, nil
}

// grow reserves observation slots until the requested cardinality is reached.
//
// Parameters:
//   - observations: observation tree to populate with uninitialized slots.
//   - current: current observation cardinality; it must be greater than zero.
//   - next: requested cardinality; it must not exceed maxObservationCardinality.
//
// Returns:
//   - uint16: resulting cardinality, unchanged when next is not greater than current.
//   - error: non-nil when the tree is nil, current is zero, or next exceeds the maximum.
func grow(observations *pl.ObservationTree, current, next uint16) (uint16, error) {
	if observations == nil {
		return current, errors.New("observations not initialized")
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

	// Reserve every new slot now so the caller that increases capacity pays for
	// its storage. This matches Uniswap's Oracle.grow behavior and prevents an
	// unrestricted reservation from shifting allocation cost to later swappers.
	for i := current; i < next; i++ {
		observations.Set(i, pl.MakeObservation(1, 0, "0", false))
	}

	return next, nil
}

// writeObservation writes a transformed observation when the timestamp changed.
//
// Parameters:
//   - observations: circular observation tree receiving the new sample.
//   - index: index of the most recently written observation.
//   - blockTimestamp: timestamp for the observation.
//   - tick: current tick used to advance cumulative tick.
//   - liquidity: active liquidity used to advance seconds-per-liquidity.
//   - cardinality: current number of usable observation slots.
//   - cardinalityNext: requested future capacity; it is applied when the ring is full.
//
// Returns:
//   - indexUpdated: index at which the new observation is stored, or the input index when the timestamp is unchanged.
//   - cardinalityUpdated: observation capacity after any growth.
//   - err: non-nil when observations or cardinality are invalid or transformation fails.
func writeObservation(
	observations *pl.ObservationTree,
	index uint16,
	blockTimestamp int64,
	tick int32,
	liquidity *u256.Uint,
	cardinality uint16,
	cardinalityNext uint16,
) (indexUpdated uint16, cardinalityUpdated uint16, err error) {
	if observations == nil {
		return 0, 0, errors.New("observations not initialized")
	}
	if cardinality == 0 {
		return 0, 0, errors.New("observation cardinality must be greater than 0")
	}

	last, err := observationAt(observations, index)
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
	observation, err := transform(last, blockTimestamp, tick, liquidity)
	if err != nil {
		return 0, 0, err
	}

	observations.Set(indexUpdated, observation)
	return indexUpdated, cardinalityUpdated, nil
}

// observationAt returns the observation at a specific index.
//
// Parameters:
//   - observations: observation tree to query.
//   - index: ring-buffer index to read.
//
// Returns:
//   - pl.Observation: stored observation at the index.
//   - error: non-nil when the tree is nil or no observation exists at the index.
func observationAt(observations *pl.ObservationTree, index uint16) (pl.Observation, error) {
	if observations == nil {
		return pl.DefaultObservation(), errors.New("observations not initialized")
	}
	obs, ok := observations.Get(index)
	if !ok {
		return pl.DefaultObservation(), errors.New(errNotInitializedObservation)
	}

	return obs, nil
}

// observeSingle returns cumulative tick and seconds-per-liquidity data for one
// observation time relative to the supplied current time.
//
// Parameters:
//   - observations: circular observation tree containing historical samples.
//   - time: current timestamp used as the reference for secondsAgo.
//   - secondsAgo: lookback duration in seconds; zero returns the current cumulative values.
//   - tick: current tick used to create a virtual current observation when needed.
//   - index: index of the latest observation in the ring.
//   - liquidity: current active liquidity used for a virtual observation.
//   - cardinality: number of observation slots available for the search.
//
// Returns:
//   - int64: cumulative tick at the requested target time.
//   - string: seconds-per-liquidity cumulative value at the target, scaled by 2^128 and encoded as decimal.
//   - error: non-nil when the target predates available history, an observation is missing, or interpolation fails.
func observeSingle(
	observations *pl.ObservationTree,
	time int64,
	secondsAgo uint32,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (int64, string, error) {
	if secondsAgo == 0 {
		// if secondsAgo is 0, return current values
		last, err := observationAt(observations, index)
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
		observations,
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
//
// Parameters:
//   - observations: circular observation tree to search.
//   - target: timestamp for which surrounding observations are required.
//   - tick: current tick used to transform a target after the latest observation.
//   - index: index of the latest observation in the ring.
//   - liquidity: current active liquidity used for a transformed target observation.
//   - cardinality: number of observation slots in the ring.
//
// Returns:
//   - pl.Observation: initialized observation at or before target.
//   - pl.Observation: observation at or after target, or a default value when target equals the latest sample.
//   - error: non-nil when observations are missing or target is older than retained history.
func getSurroundingObservations(
	observations *pl.ObservationTree,
	target int64,
	tick int32,
	index uint16,
	liquidity *u256.Uint,
	cardinality uint16,
) (pl.Observation, pl.Observation, error) {
	// Optimistically set before to the newest observation
	beforeOrAt, err := observationAt(observations, index)
	if err != nil {
		return pl.DefaultObservation(), pl.DefaultObservation(), err
	}

	// Timestamps are int64, so natural ordering applies. Uniswap V3 needs a
	// wraparound-aware comparison here only because it stores them as uint32.
	// If the target is chronologically at or after the newest observation, we can early return
	if beforeOrAt.BlockTimestamp() <= target {
		if beforeOrAt.BlockTimestamp() == target {
			// If newest observation equals target, we're in the same block, so we can ignore atOrAfter
			return beforeOrAt, pl.DefaultObservation(), nil
		}
		// Otherwise, we need to transform
		atOrAfter, err := transform(beforeOrAt, target, tick, liquidity)
		if err != nil {
			return pl.DefaultObservation(), pl.DefaultObservation(), err
		}
		return beforeOrAt, atOrAfter, nil
	}

	// Now, set before to the oldest observation
	start := (index + 1) % cardinality
	beforeOrAt, err = observationAt(observations, start)
	if err != nil || !beforeOrAt.Initialized() {
		beforeOrAt, err = observationAt(observations, 0)
		if err != nil {
			return pl.DefaultObservation(), pl.DefaultObservation(), err
		}
	}

	// Ensure that the target is chronologically at or after the oldest observation
	if beforeOrAt.BlockTimestamp() > target {
		return pl.DefaultObservation(), pl.DefaultObservation(), errors.New(errObservationTooOld)
	}

	// If we've reached this point, we have to binary search
	return binarySearch(observations, target, index, cardinality)
}

// binarySearch locates the initialized observations surrounding a target timestamp.
//
// Parameters:
//   - observations: circular observation tree to search.
//   - target: timestamp that must fall within retained observation history.
//   - index: index of the latest observation in the ring.
//   - cardinality: number of observation slots in the ring.
//
// Returns:
//   - pl.Observation: initialized observation at or before target.
//   - pl.Observation: observation at or after target.
//   - error: non-nil when an observation slot cannot be read.
func binarySearch(
	observations *pl.ObservationTree,
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
		beforeOrAt, err = observationAt(observations, beforeIndex)
		if err != nil || !beforeOrAt.Initialized() {
			// we've landed on an uninitialized tick, keep searching higher (more recently)
			l = i + 1
			continue
		}

		afterIndex := uint16((i + 1) % uint64(cardinality))
		atOrAfter, err = observationAt(observations, afterIndex)
		if err != nil {
			return pl.DefaultObservation(), pl.DefaultObservation(), err
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

// observe returns cumulative tick and seconds-per-liquidity values for each
// requested lookback in secondsAgos.
//
// Parameters:
//   - observations: circular observation tree containing historical samples.
//   - time: current timestamp used as the reference for each lookback.
//   - secondsAgos: lookback durations in seconds, one output pair per entry.
//   - tick: current tick used for virtual current observations.
//   - index: index of the latest observation in the ring.
//   - liquidity: current active liquidity used for virtual observations.
//   - cardinality: number of observation slots available for lookup.
//
// Returns:
//   - []int64: cumulative tick values aligned with secondsAgos.
//   - []string: seconds-per-liquidity cumulative values aligned with secondsAgos, scaled by 2^128.
//   - error: non-nil when cardinality is zero or any requested lookback cannot be resolved.
func observe(
	observations *pl.ObservationTree,
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
			observations,
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
