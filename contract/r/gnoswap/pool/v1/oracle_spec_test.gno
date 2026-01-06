package v1

import (
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	pl "gno.land/r/gnoswap/pool"
)

func TestOracleInitialize(t *testing.T) {
	tests := []struct {
		name string
		fn   func(t *testing.T)
	}{
		{"index is 0", testInitializeIndexIsZero},
		{"cardinality is 1", testInitializeCardinalityIsOne},
		{"cardinality next is 1", testInitializeCardinalityNextIsOne},
		{"sets first slot timestamp only", testInitializeSetsFirstSlot},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

func testInitializeIndexIsZero(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)
	uassert.Equal(t, uint16(0), os.Index())
}

func testInitializeCardinalityIsOne(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)
	uassert.Equal(t, uint16(1), os.Cardinality())
}

func testInitializeCardinalityNextIsOne(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)
	uassert.Equal(t, uint16(1), os.CardinalityLimit())
}

func testInitializeSetsFirstSlot(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	obs0 := os.Observations()[0]
	uassert.True(t, obs0.Initialized())
	uassert.Equal(t, currentTime, obs0.BlockTimestamp())
	uassert.Equal(t, int64(0), obs0.TickCumulative())
	uassert.Equal(t, "0", obs0.SecondsPerLiquidityCumulativeX128().ToString())
}

func TestOracleGrow(t *testing.T) {
	tests := []struct {
		name string
		fn   func(t *testing.T)
	}{
		{"increases the cardinality next for the first call", testGrowIncreasesCardinalityNext},
		{"does not touch the first slot", testGrowDoesNotTouchFirstSlot},
		{"is no op if oracle is already gte that size", testGrowNoOpIfAlreadyLarge},
		{"adds data to all the slots", testGrowAddsDataToSlots},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

func testGrowIncreasesCardinalityNext(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 5)
	uassert.NoError(t, err)
	os.SetCardinalityLimit(5)

	uassert.Equal(t, uint16(0), os.Index())
	uassert.Equal(t, uint16(1), os.Cardinality())
	uassert.Equal(t, uint16(5), os.CardinalityLimit())
}

func testGrowDoesNotTouchFirstSlot(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 5)
	uassert.NoError(t, err)

	obs0 := os.Observations()[0]
	uassert.Equal(t, "0", obs0.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(0), obs0.TickCumulative())
	uassert.Equal(t, currentTime, obs0.BlockTimestamp())
	uassert.True(t, obs0.Initialized())
}

func testGrowNoOpIfAlreadyLarge(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	newCard, err := grow(os, 1, 5)
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(5), newCard)

	newCard, err = grow(os, 5, 3)
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(5), newCard)
}

func testGrowAddsDataToSlots(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 5)
	uassert.NoError(t, err)

	for i := uint16(1); i < 5; i++ {
		obs := os.Observations()[i]
		uassert.Equal(t, "0", obs.SecondsPerLiquidityCumulativeX128().ToString())
		uassert.Equal(t, int64(0), obs.TickCumulative())
		uassert.False(t, obs.Initialized())
	}
}

func TestOracleWrite(t *testing.T) {
	tests := []struct {
		name string
		fn   func(t *testing.T)
	}{
		{"single element array gets overwritten", testSingleElementOverwrite},
		{"does nothing if time has not changed", testDoesNothingIfTimeUnchanged},
		{"writes an index if time has changed", testWritesIndexOnTimeChange},
		{"grows cardinality when writing past", testGrowsCardinalityWhenWritingPast},
		{"wraps around", testWrapsAround},
		{"accumulates liquidity", testAccumulatesLiquidity},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

func testSingleElementOverwrite(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	err := writeObservation(os, currentTime+1, 0, u256.Zero())
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(0), os.Index())

	obs0 := os.Observations()[0]
	uassert.True(t, obs0.Initialized())
	uassert.Equal(t, "340282366920938463463374607431768211456", obs0.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(0), obs0.TickCumulative())
	uassert.Equal(t, currentTime+1, obs0.BlockTimestamp())

	err = writeObservation(os, currentTime+6, 2, u256.NewUint(5))
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(0), os.Index())

	obs0 = os.Observations()[0]
	uassert.Equal(t, "680564733841876926926749214863536422912", obs0.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(10), obs0.TickCumulative())
	uassert.Equal(t, currentTime+6, obs0.BlockTimestamp())

	err = writeObservation(os, currentTime+9, -1, u256.NewUint(8))
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(0), os.Index())

	obs0 = os.Observations()[0]
	uassert.Equal(t, "808170621437228850725514692650449502208", obs0.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(7), obs0.TickCumulative())
	uassert.Equal(t, currentTime+9, obs0.BlockTimestamp())
}

func testDoesNothingIfTimeUnchanged(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	err = writeObservation(os, currentTime+1, 0, u256.Zero())
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(1), os.Index())

	err = writeObservation(os, currentTime+1, 3, u256.NewUint(2))
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(1), os.Index())
}

func testWritesIndexOnTimeChange(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 3)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(3)

	err = writeObservation(os, currentTime+6, 0, u256.Zero())
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(1), os.Index())

	err = writeObservation(os, currentTime+10, 3, u256.NewUint(2))
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(2), os.Index())

	obs1 := os.Observations()[1]
	uassert.Equal(t, int64(0), obs1.TickCumulative())
	uassert.Equal(t, "2041694201525630780780247644590609268736", obs1.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.True(t, obs1.Initialized())
	uassert.Equal(t, currentTime+6, obs1.BlockTimestamp())
}

func testGrowsCardinalityWhenWritingPast(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	_, err = grow(os, 2, 4)
	uassert.NoError(t, err)
	os.SetCardinalityLimit(4)
	uassert.Equal(t, uint16(1), os.Cardinality())

	err = writeObservation(os, currentTime+3, 0, u256.Zero())
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(4), os.Cardinality())

	err = writeObservation(os, currentTime+7, 5, u256.NewUint(6))
	uassert.NoError(t, err)
	uassert.Equal(t, uint16(4), os.Cardinality())
	uassert.Equal(t, uint16(2), os.Index())

	obs2 := os.Observations()[2]
	uassert.Equal(t, "1247702012043441032699040227249816775338", obs2.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(20), obs2.TickCumulative())
	uassert.True(t, obs2.Initialized())
	uassert.Equal(t, currentTime+7, obs2.BlockTimestamp())
}

func testWrapsAround(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 3)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(3)

	err = writeObservation(os, currentTime+3, 0, u256.Zero())
	uassert.NoError(t, err)

	err = writeObservation(os, currentTime+7, 1, u256.NewUint(2))
	uassert.NoError(t, err)

	err = writeObservation(os, currentTime+12, 2, u256.NewUint(3))
	uassert.NoError(t, err)

	uassert.Equal(t, uint16(0), os.Index())

	obs0 := os.Observations()[0]
	uassert.Equal(t, "2268549112806256423089164049545121409706", obs0.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, int64(14), obs0.TickCumulative())
	uassert.True(t, obs0.Initialized())
	uassert.Equal(t, currentTime+12, obs0.BlockTimestamp())
}

func testAccumulatesLiquidity(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 4)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(4)

	err = writeObservation(os, currentTime+3, 0, u256.Zero())
	uassert.NoError(t, err)

	err = writeObservation(os, currentTime+7, 3, u256.NewUint(2))
	uassert.NoError(t, err)

	err = writeObservation(os, currentTime+12, -7, u256.NewUint(6))
	uassert.NoError(t, err)

	uassert.Equal(t, uint16(3), os.Index())

	obs1 := os.Observations()[1]
	uassert.True(t, obs1.Initialized())
	uassert.Equal(t, int64(0), obs1.TickCumulative())
	uassert.Equal(t, "1020847100762815390390123822295304634368", obs1.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, currentTime+3, obs1.BlockTimestamp())

	obs2 := os.Observations()[2]
	uassert.True(t, obs2.Initialized())
	uassert.Equal(t, int64(12), obs2.TickCumulative())
	uassert.Equal(t, "1701411834604692317316873037158841057280", obs2.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, currentTime+7, obs2.BlockTimestamp())

	obs3 := os.Observations()[3]
	uassert.True(t, obs3.Initialized())
	uassert.Equal(t, int64(-23), obs3.TickCumulative())
	uassert.Equal(t, "1984980473705474370203018543351981233493", obs3.SecondsPerLiquidityCumulativeX128().ToString())
	uassert.Equal(t, currentTime+12, obs3.BlockTimestamp())

	obs4, ok := os.Observations()[4]
	if ok {
		uassert.False(t, obs4.Initialized())
	}
}

func TestOracleObserve(t *testing.T) {
	tests := []struct {
		name string
		fn   func(t *testing.T)
	}{
		{"fails if an older observation does not exist", testObserveFailsIfOlderNotExist},
		{"interpolates correctly at max liquidity", testObserveInterpolatesMaxLiquidity},
		{"interpolates correctly at min liquidity", testObserveInterpolatesMinLiquidity},
		{"interpolates the same as 0 liquidity for 1 liquidity", testObserveInterpolatesSameAs0For1},
		{"single observation at current time", testObserveSingleAtCurrentTime},
		{"single observation in past at exactly seconds ago", testObserveSinglePastExact},
		{"single observation in past counterfactual in past", testObserveSinglePastCounterfactualPast},
		{"single observation in past counterfactual now", testObserveSinglePastCounterfactualNow},
		{"two observations in chronological order 0 seconds ago exact", testObserveTwoChronological0Exact},
		{"two observations in chronological order 0 seconds ago counterfactual", testObserveTwoChronological0Counterfactual},
		{"two observations in chronological order seconds ago is exactly on first observation", testObserveTwoChronologicalExactFirst},
		{"two observations in chronological order seconds ago is between first and second", testObserveTwoChronologicalBetween},
		{"two observations in reverse order 0 seconds ago exact", testObserveTwoReverse0Exact},
		{"two observations in reverse order 0 seconds ago counterfactual", testObserveTwoReverse0Counterfactual},
		{"two observations in reverse order seconds ago is exactly on first observation", testObserveTwoReverseExactFirst},
		{"two observations in reverse order seconds ago is between first and second", testObserveTwoReverseBetween},
		{"can fetch multiple observations", testObserveFetchMultiple},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

func testObserveFailsIfOlderNotExist(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, _, err := observeSingle(os, currentTime+5, 1, 2, 0, u256.NewUint(4), 1)
	uassert.Error(t, err)
}

func testObserveInterpolatesMaxLiquidity(t *testing.T) {
	currentTime := time.Now().Unix()
	maxLiquidity := u256.MustFromDecimal("340282366920938463463374607431768211455")

	// initialize({ liquidity: MaxUint128, tick: 0, time: 0 })
	os := pl.NewObservationState(currentTime)
	// Manually set first observation with MaxUint128 liquidity
	firstObs := os.Observations()[0]
	os.Observations()[0] = pl.NewObservation(
		currentTime,
		firstObs.TickCumulative(),
		u256.Zero(),                                   // liquidityCumulative
		u256.Zero(),                                   // secondsPerLiquidityCumulativeX128
		true,
	)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 13, tick: 0, liquidity: 0 })
	// Writes with OLD liquidity (MaxUint128)
	err = writeObservation(os, currentTime+13, 0, maxLiquidity)
	uassert.NoError(t, err)

	// observeSingle(0) at time=13
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+13, 0, 0, 1, u256.Zero(), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	// 13 seconds * 2^128 / MaxUint128 = 13
	uassert.Equal(t, "13", secondsPerLiq.ToString())
}

func testObserveInterpolatesMinLiquidity(t *testing.T) {
	currentTime := time.Now().Unix()
	maxLiquidity := u256.MustFromDecimal("340282366920938463463374607431768211455")

	// initialize({ liquidity: 0, tick: 0, time: 0 })
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 13, tick: 0, liquidity: MaxUint128 })
	// Writes with OLD liquidity (0, uses max(1,0)=1)
	err = writeObservation(os, currentTime+13, 0, u256.Zero())
	uassert.NoError(t, err)

	// observeSingle(0) - current time
	// 13 seconds * 2^128 / 1 = 13 << 128
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+13, 0, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected := u256.NewUint(13).Lsh(u256.NewUint(13), 128) // 13 << 128
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(6) - 6 seconds ago = time 7
	// 7 seconds * 2^128 / 1 = 7 << 128
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 6, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected = u256.NewUint(7).Lsh(u256.NewUint(7), 128) // 7 << 128
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(12) - 12 seconds ago = time 1
	// 1 second * 2^128 / 1 = 1 << 128
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 12, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected = u256.NewUint(1).Lsh(u256.NewUint(1), 128) // 1 << 128
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(13) - 13 seconds ago = time 0
	// 0 seconds = 0
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 13, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	uassert.Equal(t, "0", secondsPerLiq.ToString())
}

func testObserveInterpolatesSameAs0For1(t *testing.T) {
	currentTime := time.Now().Unix()
	maxLiquidity := u256.MustFromDecimal("340282366920938463463374607431768211455")

	// initialize({ liquidity: 1, tick: 0, time: 0 })
	os := pl.NewObservationState(currentTime)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 13, tick: 0, liquidity: MaxUint128 })
	// Writes with OLD liquidity (1)
	err = writeObservation(os, currentTime+13, 0, u256.One())
	uassert.NoError(t, err)

	// Same expectations as min liquidity test (both use max(1, liquidity) = 1)
	// observeSingle(0) - 13 << 128
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+13, 0, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected := u256.NewUint(13).Lsh(u256.NewUint(13), 128)
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(6) - 7 << 128
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 6, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected = u256.NewUint(7).Lsh(u256.NewUint(7), 128)
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(12) - 1 << 128
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 12, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	expected = u256.NewUint(1).Lsh(u256.NewUint(1), 128)
	uassert.Equal(t, expected.ToString(), secondsPerLiq.ToString())

	// observeSingle(13) - 0
	tickCum, secondsPerLiq, err = observeSingle(os, currentTime+13, 13, 0, 1, maxLiquidity, 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	uassert.Equal(t, "0", secondsPerLiq.ToString())
}

func testObserveSingleAtCurrentTime(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+5, 0, 2, 0, u256.NewUint(4), 1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	uassert.Equal(t, "0", secondsPerLiq.ToString())
}

func testObserveSinglePastExact(t *testing.T) {
	// initialize({ liquidity: 4, tick: 2, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	// advanceTime(3) - time is now 8, but no update() called
	// Only one observation at time=5

	// observeSingle(3) - look back 3 seconds to time=5
	// Should return the initial observation which has tick=0, secondsPerLiq=0
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+8, 3, 2, 0, u256.NewUint(4), 1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	uassert.Equal(t, "0", secondsPerLiq.ToString())
}

func testObserveSinglePastCounterfactualPast(t *testing.T) {
	// initialize({ liquidity: 4, tick: 2, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	// advanceTime(3) - time is now 8, no update() called
	// Only one observation at time=5

	// observeSingle(1) - look back 1 second to time=7 (counterfactual)
	// Extrapolate from time=5 to time=7: 2 seconds with tick=2, liquidity=4
	// tickCumulative = 0 + 2*2 = 4
	// secondsPerLiq = 0 + 2 * 2^128 / 4 = 2^128 / 2
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+8, 1, 2, 0, u256.NewUint(4), 1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(4), tickCum)
	uassert.Equal(t, "170141183460469231731687303715884105728", secondsPerLiq.ToString())
}

func testObserveSinglePastCounterfactualNow(t *testing.T) {
	// initialize({ liquidity: 4, tick: 2, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	// advanceTime(3) - time is now 8, no update() called
	// Only one observation at time=5

	// observeSingle(0) - current time=8 (counterfactual)
	// Extrapolate from time=5 to time=8: 3 seconds with tick=2, liquidity=4
	// tickCumulative = 0 + 2*3 = 6
	// secondsPerLiq = 0 + 3 * 2^128 / 4 = 3 * 2^128 / 4
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+8, 0, 2, 0, u256.NewUint(4), 1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(6), tickCum)
	uassert.Equal(t, "255211775190703847597530955573826158592", secondsPerLiq.ToString())
}

func testObserveTwoChronological0Exact(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+9, 0, 1, 1, u256.NewUint(2), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-20), tickCum)
	uassert.Equal(t, "272225893536750770770699685945414569164", secondsPerLiq.ToString())
}

func testObserveTwoChronological0Counterfactual(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+16, 0, 1, 1, u256.NewUint(2), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-13), tickCum)
	uassert.Equal(t, "1463214177760035392892510811956603309260", secondsPerLiq.ToString())
}

func testObserveTwoChronologicalExactFirst(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+16, 11, 1, 1, u256.NewUint(2), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), tickCum)
	uassert.Equal(t, "0", secondsPerLiq.ToString())
}

func testObserveTwoChronologicalBetween(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+16, 9, 1, 1, u256.NewUint(2), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-10), tickCum)
	uassert.Equal(t, "136112946768375385385349842972707284582", secondsPerLiq.ToString())
}

func testObserveTwoReverse0Exact(t *testing.T) {
	// initialize({ liquidity: 5, tick: -5, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
	// Writes with OLD (tick=-5, liq=5)
	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	// After first update, cardinality grows to 2
	os.SetCardinality(2)

	// update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
	// Writes with OLD (tick=1, liq=2)
	err = writeObservation(os, currentTime+12, 1, u256.NewUint(2))
	uassert.NoError(t, err)

	// observeSingle(0) at time=12
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+12, 0, -5, 0, u256.NewUint(4), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-17), tickCum)
	uassert.Equal(t, "782649443918158465965761597093066886348", secondsPerLiq.ToString())
}

func testObserveTwoReverse0Counterfactual(t *testing.T) {
	// initialize({ liquidity: 5, tick: -5, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	os.SetCardinality(2)

	// update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
	err = writeObservation(os, currentTime+12, 1, u256.NewUint(2))
	uassert.NoError(t, err)

	// advanceTime(7) - time is now 19
	// observeSingle(0) at time=19 (counterfactual)
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+19, 0, -5, 0, u256.NewUint(4), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-52), tickCum)
	uassert.Equal(t, "1378143586029800777026667160098661256396", secondsPerLiq.ToString())
}

func testObserveTwoReverseExactFirst(t *testing.T) {
	// initialize({ liquidity: 5, tick: -5, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	os.SetCardinality(2)

	// update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
	err = writeObservation(os, currentTime+12, 1, u256.NewUint(2))
	uassert.NoError(t, err)

	// advanceTime(7) - time is now 19
	// observeSingle(10) - look back 10 seconds to time=9 (exactly on first observation)
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+19, 10, -5, 0, u256.NewUint(4), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-20), tickCum)
	uassert.Equal(t, "272225893536750770770699685945414569164", secondsPerLiq.ToString())
}

func testObserveTwoReverseBetween(t *testing.T) {
	// initialize({ liquidity: 5, tick: -5, time: 5 })
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	_, err := grow(os, 1, 2)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(2)

	// update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
	err = writeObservation(os, currentTime+9, -5, u256.NewUint(5))
	uassert.NoError(t, err)

	os.SetCardinality(2)

	// update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
	err = writeObservation(os, currentTime+12, 1, u256.NewUint(2))
	uassert.NoError(t, err)

	// advanceTime(7) - time is now 19
	// observeSingle(9) - look back 9 seconds to time=10 (between observations at 9 and 12)
	tickCum, secondsPerLiq, err := observeSingle(os, currentTime+19, 9, -5, 0, u256.NewUint(4), 2)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-19), tickCum)
	uassert.Equal(t, "442367076997220002502386989661298674892", secondsPerLiq.ToString())
}

func testObserveFetchMultiple(t *testing.T) {
	currentTime := time.Now().Unix()
	os := pl.NewObservationState(currentTime + 5)

	liquidity := u256.NewUint(1 << 15)

	_, err := grow(os, 1, 4)
	uassert.NoError(t, err)
	os.SetCardinality(1)
	os.SetCardinalityLimit(4)

	err = writeObservation(os, currentTime+18, 2, liquidity)
	uassert.NoError(t, err)

	secondsAgos := []uint32{0, 3, 8, 13, 15, 18}
	currentLiquidity := u256.NewUint(1 << 12)

	tickCumulatives, secondsPerLiquidityX128s, err := observe(
		os,
		currentTime+23,
		secondsAgos,
		6,
		1,
		currentLiquidity,
		2,
	)
	uassert.NoError(t, err)
	uassert.Equal(t, 6, len(tickCumulatives))

	uassert.Equal(t, int64(56), tickCumulatives[0])
	uassert.Equal(t, int64(38), tickCumulatives[1])
	uassert.Equal(t, int64(20), tickCumulatives[2])
	uassert.Equal(t, int64(10), tickCumulatives[3])
	uassert.Equal(t, int64(6), tickCumulatives[4])
	uassert.Equal(t, int64(0), tickCumulatives[5])

	uassert.Equal(t, 6, len(secondsPerLiquidityX128s))
	uassert.Equal(t, "550383467004691728624232610897330176", secondsPerLiquidityX128s[0].ToString())
	uassert.Equal(t, "301153217795020002454768787094765568", secondsPerLiquidityX128s[1].ToString())
	uassert.Equal(t, "103845937170696552570609926584401920", secondsPerLiquidityX128s[2].ToString())
	uassert.Equal(t, "51922968585348276285304963292200960", secondsPerLiquidityX128s[3].ToString())
	uassert.Equal(t, "31153781151208965771182977975320576", secondsPerLiquidityX128s[4].ToString())
	uassert.Equal(t, "0", secondsPerLiquidityX128s[5].ToString())
}

func TestOracleFiveObservations(t *testing.T) {
	tests := []struct {
		name string
		fn   func(t *testing.T)
	}{
		{"index cardinality cardinality next", testFiveObservationsIndexCardinality},
		{"latest observation same time as latest", testFiveObservationsLatestSameTime},
		{"latest observation 5 seconds after latest", testFiveObservationsLatest5SecondsAfter},
		{"current observation 5 seconds after latest", testFiveObservationsCurrent5SecondsAfter},
		{"between latest observation and just before latest observation at same time as latest", testFiveObservationsBetweenLatestSameTime},
		{"between latest observation and just before latest observation after the latest observation", testFiveObservationsBetweenLatestAfter},
		{"oldest observation", testFiveObservationsOldest},
		{"oldest observation after some time", testFiveObservationsOldestAfterTime},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.fn(t)
		})
	}
}

func setupFiveObservations(startTime int64) *pl.ObservationState {
	os := pl.NewObservationState(startTime)

	grow(os, 1, 5)
	os.SetCardinality(1)
	os.SetCardinalityLimit(5)

	writeObservation(os, startTime+3, -5, u256.NewUint(5))
	writeObservation(os, startTime+5, 1, u256.NewUint(2))
	writeObservation(os, startTime+9, -6, u256.NewUint(4))
	writeObservation(os, startTime+10, -2, u256.NewUint(4))
	writeObservation(os, startTime+13, -2, u256.NewUint(9))
	writeObservation(os, startTime+19, 4, u256.NewUint(2))

	return os
}

func testFiveObservationsIndexCardinality(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	uassert.Equal(t, uint16(1), os.Index())
	uassert.Equal(t, uint16(5), os.Cardinality())
	uassert.Equal(t, uint16(5), os.CardinalityLimit())
}

func testFiveObservationsLatestSameTime(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+19, 0, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-21), tickCum)
	uassert.Equal(t, "2104079302127802832415199655953100107502", secondsPerLiq.ToString())
}

func testFiveObservationsLatest5SecondsAfter(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+24, 5, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-21), tickCum)
	uassert.Equal(t, "2104079302127802832415199655953100107502", secondsPerLiq.ToString())
}

func testFiveObservationsCurrent5SecondsAfter(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+24, 0, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(9), tickCum)
	uassert.Equal(t, "2347138135642758877746181518404363115684", secondsPerLiq.ToString())
}

func testFiveObservationsBetweenLatestSameTime(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+19, 3, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-33), tickCum)
	uassert.Equal(t, "1593655751746395137220137744805447790318", secondsPerLiq.ToString())
}

func testFiveObservationsBetweenLatestAfter(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+24, 8, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-33), tickCum)
	uassert.Equal(t, "1593655751746395137220137744805447790318", secondsPerLiq.ToString())
}

func testFiveObservationsOldest(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+19, 14, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-13), tickCum)
	uassert.Equal(t, "544451787073501541541399371890829138329", secondsPerLiq.ToString())
}

func testFiveObservationsOldestAfterTime(t *testing.T) {
	startTime := time.Now().Unix()
	os := setupFiveObservations(startTime)

	tickCum, secondsPerLiq, err := observeSingle(os, startTime+25, 20, 6, 1, u256.NewUint(7), 5)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(-13), tickCum)
	uassert.Equal(t, "544451787073501541541399371890829138329", secondsPerLiq.ToString())
}
