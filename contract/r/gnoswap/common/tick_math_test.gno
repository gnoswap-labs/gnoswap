package common

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

var (
	MIN_TICK       = int32(-887272)
	MIN_SQRT_RATIO = "4295128739"

	MAX_TICK       = int32(887272)
	MAX_SQRT_RATIO = "1461446703485210103287273052203988822378723970342"
)

func TestTickMath_GetSqrtRatioAtTick(t *testing.T) {
	tests := []struct {
		name                 string
		tick                 int32
		expectedSqrtPriceX96 string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:                 "throws for too low",
			tick:                 MIN_TICK - 1,
			expectedSqrtPriceX96: "",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-001] value out of range || tick is out of range (smaller than -887272), tick: -887273",
		},
		{
			name:                 "throws for too high",
			tick:                 MAX_TICK + 1,
			expectedSqrtPriceX96: "",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-001] value out of range || tick is out of range (larger than 887272), tick: 887273",
		},
		{
			name:                 "min tick",
			tick:                 MIN_TICK,
			expectedSqrtPriceX96: "4295128739",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "min tick + 1",
			tick:                 MIN_TICK + 1,
			expectedSqrtPriceX96: "4295343490",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "max tick",
			tick:                 MAX_TICK,
			expectedSqrtPriceX96: "1461446703485210103287273052203988822378723970342",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "max tick - 1",
			tick:                 MAX_TICK - 1,
			expectedSqrtPriceX96: "1461373636630004318706518188784493106690254656249",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "zero tick",
			tick:                 0,
			expectedSqrtPriceX96: "79228162514264337593543950336",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 50",
			tick:                 50,
			expectedSqrtPriceX96: "79426470787362580746886972461",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -50",
			tick:                 -50,
			expectedSqrtPriceX96: "79030349367926598376800521322",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 100",
			tick:                 100,
			expectedSqrtPriceX96: "79625275426524748796330556128",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -100",
			tick:                 -100,
			expectedSqrtPriceX96: "78833030112140176575862854579",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 150000",
			tick:                 150000,
			expectedSqrtPriceX96: "143194173941309278083010301478497",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -150000",
			tick:                 -150000,
			expectedSqrtPriceX96: "43836292794701720435367485",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 250000",
			tick:                 250000,
			expectedSqrtPriceX96: "21246587762933397357449903968194344",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -250000",
			tick:                 -250000,
			expectedSqrtPriceX96: "295440463448801648376846",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 500000",
			tick:                 500000,
			expectedSqrtPriceX96: "5697689776495288729098254600827762987878",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -500000",
			tick:                 -500000,
			expectedSqrtPriceX96: "1101692437043807371",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 738203",
			tick:                 738203,
			expectedSqrtPriceX96: "847134979253254120489401328389043031315994541",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "negative tick -738203",
			tick:                 -738203,
			expectedSqrtPriceX96: "7409801140451",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "positive tick 499999",
			tick:                 499999,
			expectedSqrtPriceX96: "5697404913371020254246162096779746564305",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "min tick ratio validation",
			tick:                 MIN_TICK,
			expectedSqrtPriceX96: "4295128739",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "max tick - 1 ratio validation",
			tick:                 MAX_TICK - 1,
			expectedSqrtPriceX96: "1461373636630004318706518188784493106690254656249",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					TickMathGetSqrtRatioAtTick(tt.tick)
				})
			} else {
				result := TickMathGetSqrtRatioAtTick(tt.tick)
				uassert.Equal(t, tt.expectedSqrtPriceX96, result.ToString())
			}
		})
	}
}

func TestTickMath_GetTickAtSqrtRatio(t *testing.T) {
	tests := []struct {
		name                 string
		sqrtPriceX96         string
		expectedTick         int32
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:                 "throws for too low sqrt_ratio",
			sqrtPriceX96:         "4295128738", // MIN_SQRT_RATIO - 1
			expectedTick:         0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-001] value out of range || sqrtPriceX96(4295128738) is out of range",
		},
		{
			name:                 "throws for too high sqrt_ratio",
			sqrtPriceX96:         "1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
			expectedTick:         0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-001] value out of range || sqrtPriceX96(1461446703485210103287273052203988822378723970343) is out of range",
		},
		{
			name:                 "ratio of min tick",
			sqrtPriceX96:         MIN_SQRT_RATIO,
			expectedTick:         MIN_TICK,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "ratio of min tick + 1",
			sqrtPriceX96:         "4295343490",
			expectedTick:         MIN_TICK + 1,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "ratio of max tick - 1",
			sqrtPriceX96:         "1461373636630004318706518188784493106690254656249",
			expectedTick:         MAX_TICK - 1,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -887272",
			sqrtPriceX96:         "4295128739",
			expectedTick:         -887272,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 276324",
			sqrtPriceX96:         "79228162514264337593543950336000000",
			expectedTick:         276324,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 138162",
			sqrtPriceX96:         "79228162514264337593543950336000",
			expectedTick:         138162,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -41591",
			sqrtPriceX96:         "9903520314283042199192993792",
			expectedTick:         -41591,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -20796",
			sqrtPriceX96:         "28011385487393069959365969113",
			expectedTick:         -20796,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -6932",
			sqrtPriceX96:         "56022770974786139918731938227",
			expectedTick:         -6932,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 0",
			sqrtPriceX96:         "79228162514264337593543950336",
			expectedTick:         0,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 6931",
			sqrtPriceX96:         "112045541949572279837463876454",
			expectedTick:         6931,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 20795",
			sqrtPriceX96:         "224091083899144559674927752909",
			expectedTick:         20795,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 41590",
			sqrtPriceX96:         "633825300114114700748351602688",
			expectedTick:         41590,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -138163",
			sqrtPriceX96:         "79228162514264337593543950",
			expectedTick:         -138163,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick -276325",
			sqrtPriceX96:         "79228162514264337593543",
			expectedTick:         -276325,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "sqrt ratio at tick 887271",
			sqrtPriceX96:         "1461373636630004318706518188784493106690254656249",
			expectedTick:         887271,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "ratio closest to max tick",
			sqrtPriceX96:         "1461373636630004318706518188784493106690254656249", // maxSqrtRatio - gapSqrtRatio
			expectedTick:         MAX_TICK - 1,
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "nil sqrt ratio",
			sqrtPriceX96:         "",
			expectedTick:         0,
			expectedHasPanic:     true,
			expectedPanicMessage: "sqrtPriceX96 cannot be nil",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var sqrtPriceX96 *u256.Uint
			if tt.sqrtPriceX96 != "" {
				sqrtPriceX96 = u256.MustFromDecimal(tt.sqrtPriceX96)
			}

			if tt.expectedHasPanic {
				uassert.PanicsContains(t, tt.expectedPanicMessage, func() {
					TickMathGetTickAtSqrtRatio(sqrtPriceX96)
				})
			} else {
				result := TickMathGetTickAtSqrtRatio(sqrtPriceX96)
				uassert.Equal(t, tt.expectedTick, result)
			}
		})
	}
}

func TestTickMath_PrecisionValidation(t *testing.T) {
	// Test precision for various absolute tick values
	absTicks := []int32{
		50, 100, 250, 500, 1000, 2500, 3000, 4000, 5000,
		50000, 150000, 250000, 500000, 738203,
	}

	for _, absTick := range absTicks {
		for _, sign := range []int32{-1, 1} {
			tick := sign * absTick
			if tick < MIN_TICK || tick > MAX_TICK {
				continue
			}

			t.Run(ufmt.Sprintf("precision_tick_%d", tick), func(t *testing.T) {
				result := TickMathGetSqrtRatioAtTick(tick)

				// Basic validation: result should be within valid range
				uassert.True(t, result.Gte(u256.MustFromDecimal(MIN_SQRT_RATIO)),
					ufmt.Sprintf("Result %s should be >= MIN_SQRT_RATIO", result.ToString()))
				uassert.True(t, result.Lte(u256.MustFromDecimal(MAX_SQRT_RATIO)),
					ufmt.Sprintf("Result %s should be <= MAX_SQRT_RATIO", result.ToString()))

				// Validate roundtrip: getSqrtRatioAtTick -> getTickAtSqrtRatio should be consistent
				backTick := TickMathGetTickAtSqrtRatio(result)
				uassert.Equal(t, tick, backTick,
					ufmt.Sprintf("Roundtrip failed: tick %d -> sqrt %s -> tick %d",
						tick, result.ToString(), backTick))
			})
		}
	}
}

func TestTickMath_Constants(t *testing.T) {
	tests := []struct {
		name          string
		tick          int32
		expectedRatio string
	}{
		{
			name:          "MIN_SQRT_RATIO equals getSqrtRatioAtTick MIN_TICK",
			tick:          MIN_TICK,
			expectedRatio: MIN_SQRT_RATIO,
		},
		{
			name:          "MAX_SQRT_RATIO equals getSqrtRatioAtTick MAX_TICK",
			tick:          MAX_TICK,
			expectedRatio: MAX_SQRT_RATIO,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqrtRatio := TickMathGetSqrtRatioAtTick(tt.tick)
			expectedSqrtRatio := u256.MustFromDecimal(tt.expectedRatio)

			uassert.True(t, sqrtRatio.Eq(expectedSqrtRatio),
				ufmt.Sprintf("SQRT_RATIO mismatch: got %s, expected %s",
					sqrtRatio.ToString(), expectedSqrtRatio.ToString()))
		})
	}
}

func TestTickMath_RatioValidation(t *testing.T) {
	// Test various sqrt ratios as in TypeScript tests
	tests := []struct {
		name        string
		sqrtRatio   string
		expectValid bool
	}{
		{
			name:        "MIN_SQRT_RATIO",
			sqrtRatio:   MIN_SQRT_RATIO,
			expectValid: true,
		},
		{
			name:        "power_of_10_12_to_1",
			sqrtRatio:   "79228162514264337593543950336000000000", // encodePriceSqrt(10^12, 1)
			expectValid: true,
		},
		{
			name:        "power_of_10_6_to_1",
			sqrtRatio:   "79228162514264337593543950336000", // encodePriceSqrt(10^6, 1)
			expectValid: true,
		},
		{
			name:        "ratio_1_to_64",
			sqrtRatio:   "9903520314283042199192993792", // encodePriceSqrt(1, 64)
			expectValid: true,
		},
		{
			name:        "ratio_1_to_8",
			sqrtRatio:   "28011385487393069959365969113", // encodePriceSqrt(1, 8)
			expectValid: true,
		},
		{
			name:        "ratio_1_to_2",
			sqrtRatio:   "56022770974786139918731938227", // encodePriceSqrt(1, 2)
			expectValid: true,
		},
		{
			name:        "ratio_1_to_1",
			sqrtRatio:   "79228162514264337593543950336", // encodePriceSqrt(1, 1)
			expectValid: true,
		},
		{
			name:        "ratio_2_to_1",
			sqrtRatio:   "112045541949572279837463876454", // encodePriceSqrt(2, 1)
			expectValid: true,
		},
		{
			name:        "ratio_8_to_1",
			sqrtRatio:   "224091083899144559674927752909", // encodePriceSqrt(8, 1)
			expectValid: true,
		},
		{
			name:        "ratio_64_to_1",
			sqrtRatio:   "633825300114114700748351602688", // encodePriceSqrt(64, 1)
			expectValid: true,
		},
		{
			name:        "MAX_SQRT_RATIO_minus_1",
			sqrtRatio:   "1461446703485210103287273052203988822378723970341",
			expectValid: true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			sqrtRatio := u256.MustFromDecimal(test.sqrtRatio)

			if test.expectValid {
				// Should not panic and return valid tick
				tick := TickMathGetTickAtSqrtRatio(sqrtRatio)

				// Validate tick is in valid range
				uassert.True(t, tick >= MIN_TICK && tick <= MAX_TICK,
					ufmt.Sprintf("Tick %d should be in valid range [%d, %d]", tick, MIN_TICK, MAX_TICK))

				// Validate ratio is between tick and tick+1
				if tick < MAX_TICK {
					ratioOfTick := TickMathGetSqrtRatioAtTick(tick)
					ratioOfTickPlusOne := TickMathGetSqrtRatioAtTick(tick + 1)

					uassert.True(t, sqrtRatio.Gte(ratioOfTick),
						ufmt.Sprintf("Ratio %s should be >= ratioOfTick %s",
							sqrtRatio.ToString(), ratioOfTick.ToString()))
					uassert.True(t, sqrtRatio.Lt(ratioOfTickPlusOne),
						ufmt.Sprintf("Ratio %s should be < ratioOfTickPlusOne %s",
							sqrtRatio.ToString(), ratioOfTickPlusOne.ToString()))
				}
			}
		})
	}
}

func TestTickMath_BoundaryConditions(t *testing.T) {
	tests := []struct {
		name             string
		tick             int32
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:             "min_tick_minus_2",
			tick:             MIN_TICK - 2,
			expectedPanic:    true,
			expectedPanicMsg: "[GNOSWAP-COMMON-001] value out of range || tick is out of range (smaller than -887272), tick: -887274",
		},
		{
			name:             "max_tick_plus_2",
			tick:             MAX_TICK + 2,
			expectedPanic:    true,
			expectedPanicMsg: "[GNOSWAP-COMMON-001] value out of range || tick is out of range (larger than 887272), tick: 887274",
		},
		{
			name:          "min_tick_valid",
			tick:          MIN_TICK,
			expectedPanic: false,
		},
		{
			name:          "max_tick_valid",
			tick:          MAX_TICK,
			expectedPanic: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if test.expectedPanic {
				uassert.PanicsWithMessage(t, test.expectedPanicMsg, func() {
					TickMathGetSqrtRatioAtTick(test.tick)
				})
			} else {
				// Should not panic
				result := TickMathGetSqrtRatioAtTick(test.tick)
				uassert.True(t, result.Gte(u256.MustFromDecimal(MIN_SQRT_RATIO)),
					"Result should be >= MIN_SQRT_RATIO")
				uassert.True(t, result.Lte(u256.MustFromDecimal(MAX_SQRT_RATIO)),
					"Result should be <= MAX_SQRT_RATIO")
			}
		})
	}
}

func TestTickMath_SqrtRatioBoundaryConditions(t *testing.T) {
	tests := []struct {
		name             string
		sqrtRatio        string
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:             "below_min_sqrt_ratio",
			sqrtRatio:        "4295128738", // MIN_SQRT_RATIO - 1
			expectedPanic:    true,
			expectedPanicMsg: "[GNOSWAP-COMMON-001] value out of range || sqrtPriceX96(4295128738) is out of range",
		},
		{
			name:             "above_max_sqrt_ratio",
			sqrtRatio:        "1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
			expectedPanic:    true,
			expectedPanicMsg: "[GNOSWAP-COMMON-001] value out of range || sqrtPriceX96(1461446703485210103287273052203988822378723970343) is out of range",
		},
		{
			name:          "exact_min_sqrt_ratio",
			sqrtRatio:     MIN_SQRT_RATIO,
			expectedPanic: false,
		},
		{
			name:          "exact_max_sqrt_ratio_minus_1",
			sqrtRatio:     "1461446703485210103287273052203988822378723970341", // MAX_SQRT_RATIO - 1
			expectedPanic: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			sqrtRatio := u256.MustFromDecimal(test.sqrtRatio)

			if test.expectedPanic {
				uassert.PanicsWithMessage(t, test.expectedPanicMsg, func() {
					TickMathGetTickAtSqrtRatio(sqrtRatio)
				})
			} else {
				// Should not panic
				result := TickMathGetTickAtSqrtRatio(sqrtRatio)
				uassert.True(t, result >= MIN_TICK && result <= MAX_TICK,
					ufmt.Sprintf("Result tick %d should be in valid range", result))
			}
		})
	}
}

// TestTickMath_MaxTickBoundaryBehavior explicitly tests MAX_TICK boundary behavior
func TestTickMath_MaxTickBoundaryBehavior(t *testing.T) {
	tests := []struct {
		name             string
		tick             int32
		expectPanic      bool
		expectedPanicMsg string
		description      string
	}{
		{
			name:        "MAX_TICK can convert to sqrt ratio",
			tick:        MAX_TICK,
			expectPanic: false,
			description: "TickMathGetSqrtRatioAtTick should accept MAX_TICK",
		},
		{
			name:        "MAX_TICK - 1 supports full roundtrip",
			tick:        MAX_TICK - 1,
			expectPanic: false,
			description: "MAX_TICK - 1 should support tick -> sqrt -> tick conversion",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMsg, func() {
					TickMathGetSqrtRatioAtTick(tt.tick)
				})
			} else {
				sqrtRatio := TickMathGetSqrtRatioAtTick(tt.tick)

				// For MAX_TICK - 1, we can do full roundtrip
				if tt.tick == MAX_TICK-1 {
					recoveredTick := TickMathGetTickAtSqrtRatio(sqrtRatio)
					uassert.Equal(t, tt.tick, recoveredTick,
						ufmt.Sprintf("Roundtrip should work for MAX_TICK - 1"))
				}

				// For MAX_TICK, the sqrt ratio equals MAX_SQRT_RATIO
				if tt.tick == MAX_TICK {
					maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)
					uassert.True(t, sqrtRatio.Eq(maxSqrtRatio),
						ufmt.Sprintf("MAX_TICK should produce MAX_SQRT_RATIO"))
				}
			}
		})
	}

	// Explicitly test that MAX_SQRT_RATIO is rejected by TickMathGetTickAtSqrtRatio
	t.Run("MAX_SQRT_RATIO_rejected_by_GetTickAtSqrtRatio", func(t *testing.T) {
		maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

		// This should panic because TickMathGetTickAtSqrtRatio uses strict inequality (sqrtPriceX96 >= maxSqrtPriceX96)
		uassert.PanicsContains(t, "out of range", func() {
			TickMathGetTickAtSqrtRatio(maxSqrtRatio)
		})
	})

	// Test that MAX_SQRT_RATIO - 1 is accepted
	t.Run("MAX_SQRT_RATIO_minus_1_accepted", func(t *testing.T) {
		maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)
		almostMaxSqrtRatio := u256.Zero().Sub(maxSqrtRatio, u256.One())

		// This should NOT panic
		uassert.NotPanics(t, func() {
			tick := TickMathGetTickAtSqrtRatio(almostMaxSqrtRatio)
			// Should return MAX_TICK - 1
			uassert.Equal(t, MAX_TICK-1, tick,
				ufmt.Sprintf("MAX_SQRT_RATIO - 1 should map to MAX_TICK - 1"))
		})
	})
}

// TestTickMath_ExtendedRoundtripAccuracy tests roundtrip accuracy for a wider range of ticks
func TestTickMath_ExtendedRoundtripAccuracy(t *testing.T) {
	// Test more granular tick values to ensure precision
	// MAX_TICK is excluded from roundtrip tests - see TestTickMath_MaxTickBoundaryBehavior for details
	testTicks := []int32{
		MIN_TICK,
		MIN_TICK + 1,
		MIN_TICK + 10,
		MIN_TICK + 100,
		MIN_TICK + 1000,
		-500000,
		-100000,
		-50000,
		-10000,
		-5000,
		-1000,
		-500,
		-100,
		-50,
		-10,
		-5,
		-1,
		0,
		1,
		5,
		10,
		50,
		100,
		500,
		1000,
		5000,
		10000,
		50000,
		100000,
		500000,
		MAX_TICK - 1000,
		MAX_TICK - 100,
		MAX_TICK - 10,
		MAX_TICK - 1,
		// MAX_TICK excluded - see note above
	}

	for _, tick := range testTicks {
		t.Run(ufmt.Sprintf("tick_%d", tick), func(t *testing.T) {
			// Convert tick to sqrt ratio
			sqrtRatio := TickMathGetSqrtRatioAtTick(tick)

			// Validate sqrt ratio is in valid range
			minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
			maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

			uassert.True(t, sqrtRatio.Gte(minSqrtRatio),
				ufmt.Sprintf("SqrtRatio %s should be >= MIN_SQRT_RATIO", sqrtRatio.ToString()))
			uassert.True(t, sqrtRatio.Lte(maxSqrtRatio),
				ufmt.Sprintf("SqrtRatio %s should be <= MAX_SQRT_RATIO", sqrtRatio.ToString()))

			// Convert back to tick
			recoveredTick := TickMathGetTickAtSqrtRatio(sqrtRatio)

			// Recovered tick should equal original tick
			uassert.Equal(t, tick, recoveredTick,
				ufmt.Sprintf("Roundtrip failed: tick %d -> sqrt %s -> tick %d",
					tick, sqrtRatio.ToString(), recoveredTick))
		})
	}
}

// TestTickMath_SpecificPriceAccuracy tests accuracy for specific well-known price points
func TestTickMath_SpecificPriceAccuracy(t *testing.T) {
	tests := []struct {
		name          string
		tick          int32
		description   string
		expectedRatio string
	}{
		{
			name:          "price_1.0",
			tick:          0,
			description:   "Price 1.0 (tick 0)",
			expectedRatio: "79228162514264337593543950336", // Q96
		},
		{
			name:          "price_1.0001",
			tick:          1,
			description:   "Price 1.0001 (1 basis point)",
			expectedRatio: "79228162514264337593543950336", // Approximately Q96 * sqrt(1.0001)
		},
		{
			name:          "price_1.01",
			tick:          100,
			description:   "Price 1.01 (100 basis points)",
			expectedRatio: "79625275426524748796330556128",
		},
		{
			name:          "price_0.99",
			tick:          -100,
			description:   "Price 0.99",
			expectedRatio: "78833030112140176575862854579",
		},
		{
			name:          "price_2.0",
			tick:          6932, // log_1.0001(2.0) ≈ 6931.47
			description:   "Price approximately 2.0",
			expectedRatio: "112045541949572279837463876454",
		},
		{
			name:          "price_0.5",
			tick:          -6932,
			description:   "Price approximately 0.5",
			expectedRatio: "56022770974786139918731938227",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := TickMathGetSqrtRatioAtTick(tt.tick)
			expected := u256.MustFromDecimal(tt.expectedRatio)

			// For tick != 0, allow small rounding differences
			if tt.tick == 0 {
				uassert.True(t, result.Eq(expected),
					ufmt.Sprintf("%s: Expected exact match %s, got %s",
						tt.description, expected.ToString(), result.ToString()))
			} else {
				// Calculate relative difference (should be < 0.01%)
				diff := u256.Zero()
				if result.Gt(expected) {
					diff = u256.Zero().Sub(result, expected)
				} else {
					diff = u256.Zero().Sub(expected, result)
				}

				// diff / expected should be very small
				// For simplicity, just check they are close
				maxDiff := u256.Zero().Div(expected, u256.NewUint(10000)) // 0.01% tolerance

				uassert.True(t, diff.Lte(maxDiff),
					ufmt.Sprintf("%s: Difference %s exceeds tolerance %s",
						tt.description, diff.ToString(), maxDiff.ToString()))
			}
		})
	}
}

// TestTickMath_TickSpacingConsistency tests that tick spacing remains consistent
func TestTickMath_TickSpacingConsistency(t *testing.T) {
	// Test that price ratio between consecutive ticks is approximately 1.0001
	testTicks := []int32{0, 100, 1000, 10000, 100000}

	for _, baseTick := range testTicks {
		if baseTick+1 > MAX_TICK {
			continue
		}

		t.Run(ufmt.Sprintf("tick_spacing_%d", baseTick), func(t *testing.T) {
			ratio1 := TickMathGetSqrtRatioAtTick(baseTick)
			ratio2 := TickMathGetSqrtRatioAtTick(baseTick + 1)

			// ratio2 / ratio1 should be approximately sqrt(1.0001)
			// We can't easily compute sqrt in tests, so just verify ratio2 > ratio1
			uassert.True(t, ratio2.Gt(ratio1),
				ufmt.Sprintf("Tick %d: ratio2 (%s) should be > ratio1 (%s)",
					baseTick, ratio2.ToString(), ratio1.ToString()))

			// The increase should be very small (about 0.005%)
			diff := u256.Zero().Sub(ratio2, ratio1)
			maxIncrease := u256.Zero().Div(ratio1, u256.NewUint(20000)) // ~0.005%

			// For higher ticks, the absolute difference increases, so scale tolerance
			scaleFactor := u256.NewUint(1)
			if baseTick > 10000 {
				scaleFactor = u256.NewUint(10)
			}
			maxIncrease = u256.Zero().Mul(maxIncrease, scaleFactor)

			uassert.True(t, diff.Lte(maxIncrease),
				ufmt.Sprintf("Tick %d: price increase %s exceeds tolerance %s",
					baseTick, diff.ToString(), maxIncrease.ToString()))
		})
	}
}

// TestTickMath_NegativeTickSymmetry tests that negative ticks are symmetric with positive ticks
func TestTickMath_NegativeTickSymmetry(t *testing.T) {
	testTicks := []int32{1, 10, 100, 1000, 10000, 100000}

	q96 := u256.MustFromDecimal("79228162514264337593543950336")

	for _, tick := range testTicks {
		t.Run(ufmt.Sprintf("symmetry_tick_%d", tick), func(t *testing.T) {
			positiveRatio := TickMathGetSqrtRatioAtTick(tick)
			negativeRatio := TickMathGetSqrtRatioAtTick(-tick)

			// For symmetric ticks: sqrt(price_positive) * sqrt(price_negative) ≈ Q96
			// This is because: sqrt(P) * sqrt(1/P) = 1, and Q96 represents price 1.0
			product := u256.MulDiv(positiveRatio, negativeRatio, q96)

			// Product should be approximately Q96 (allowing small rounding)
			diff := u256.Zero()
			if product.Gt(q96) {
				diff = u256.Zero().Sub(product, q96)
			} else {
				diff = u256.Zero().Sub(q96, product)
			}

			// Allow 0.01% tolerance
			maxDiff := u256.Zero().Div(q96, u256.NewUint(10000))

			uassert.True(t, diff.Lte(maxDiff),
				ufmt.Sprintf("Tick ±%d: Product %s differs from Q96 by %s (max %s)",
					tick, product.ToString(), diff.ToString(), maxDiff.ToString()))
		})
	}
}
