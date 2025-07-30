package pool

import (
	"testing"

	"gno.land/r/gnoswap/v1/common"

	fuzzer "gno.land/p/gnoswap/fuzztest"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type poolTestHelper struct {
	t *testing.T
}

func newPoolTestHelper(t *testing.T) *poolTestHelper {
	return &poolTestHelper{t: t}
}

func (h *poolTestHelper) assertPanic(f func(), shouldPanic bool, context string) {
	defer func() {
		r := recover()
		if shouldPanic && r == nil {
			h.t.Errorf("%s: expected panic but got none", context)
		} else if !shouldPanic && r != nil {
			h.t.Errorf("%s: unexpected panic: %v", context, r)
		}
	}()
	f()
}

// TestFuzzSafeConvertToInt128 tests the safeConvertToInt128 function for overflow/underflow
func TestFuzzSafeConvertToInt128(t *testing.T) {
	helper := newPoolTestHelper(t)
	gen := fuzzer.NewUint256Generator(true, 256)

	overflowCount := 0
	successCount := 0

	for i := 0; i < 1000; i++ {
		value := gen.Generate().(*u256.Uint)

		// Check if value exceeds MAX_INT128
		maxInt128 := u256.MustFromDecimal(MAX_INT128)
		shouldOverflow := value.Gt(maxInt128)

		helper.assertPanic(func() {
			result := safeConvertToInt128(value)
			if result == nil {
				t.Errorf("safeConvertToInt128 returned nil for value %s", value.ToString())
			}
			successCount++
		}, shouldOverflow, "safeConvertToInt128")

		if shouldOverflow {
			overflowCount++
		}
	}

	t.Logf("safeConvertToInt128: %d successful conversions, %d overflows detected", successCount, overflowCount)

	boundaryTests := []struct {
		value       string
		shouldPanic bool
		description string
	}{
		{MAX_INT128, false, "MAX_INT128"},
		{"170141183460469231731687303715884105728", true, "MAX_INT128 + 1"},
		{MAX_UINT128, true, "MAX_UINT128"},
		{"0", false, "zero"},
		{"1", false, "one"},
	}

	for _, test := range boundaryTests {
		helper.assertPanic(func() {
			val := u256.MustFromDecimal(test.value)
			safeConvertToInt128(val)
		}, test.shouldPanic, test.description)
	}
}

func TestFuzzSafeConvertToUint64(t *testing.T) {
	helper := newPoolTestHelper(t)
	gen := fuzzer.NewUint256Generator(true, 128)

	for i := 0; i < 1000; i++ {
		value := gen.Generate().(*u256.Uint)

		maxUint64 := u256.MustFromDecimal(MAX_UINT64)
		shouldOverflow := value.Gt(maxUint64)

		helper.assertPanic(func() {
			result := safeConvertToUint64(value)
			if !shouldOverflow && result > ^uint64(0) {
				t.Errorf("safeConvertToUint64 returned invalid value: %d", result)
			}
		}, shouldOverflow, "safeConvertToUint64")
	}
}

func TestFuzzSafeConvertToInt64(t *testing.T) {
	helper := newPoolTestHelper(t)
	gen := fuzzer.NewUint256Generator(true, 128)

	for i := 0; i < 1000; i++ {
		value := gen.Generate().(*u256.Uint)

		maxInt64 := u256.MustFromDecimal(MAX_INT64)
		shouldOverflow := value.Gt(maxInt64)

		helper.assertPanic(func() {
			result := safeConvertToInt64(value)
			if !shouldOverflow && result < 0 {
				t.Errorf("safeConvertToInt64 returned negative value: %d", result)
			}
		}, shouldOverflow, "safeConvertToInt64")
	}
}

func TestFuzzLiquidityMathAddDelta(t *testing.T) {
	helper := newPoolTestHelper(t)
	xGen := fuzzer.NewUint256Generator(true, 256)
	yGen := fuzzer.NewInt256Generator(true, true, 256)

	underflowCount := 0
	overflowCount := 0
	successCount := 0

	for i := 0; i < 1000; i++ {
		x := xGen.Generate().(*u256.Uint)
		y := yGen.Generate().(*i256.Int)

		shouldFail := false

		if y.IsNeg() {
			// Check for underflow: |y| > x
			absY := y.Abs()
			if absY.Gt(x) {
				shouldFail = true
				underflowCount++
			}
		} else if !y.IsZero() {
			// Check for overflow: x + y would overflow uint256
			absY := y.Abs()
			maxUint256 := u256.MustFromDecimal(MAX_UINT256)
			if absY.Gt(maxUint256) {
				shouldFail = true
				overflowCount++
			}
		}

		helper.assertPanic(func() {
			result := liquidityMathAddDelta(x, y)

			// Verify result correctness
			if y.IsNeg() {
				expected := new(u256.Uint).Sub(x, y.Abs())
				if !result.Eq(expected) {
					t.Errorf("liquidityMathAddDelta incorrect result for subtraction")
				}
			} else {
				expected := new(u256.Uint).Add(x, y.Abs())
				if !result.Eq(expected) {
					t.Errorf("liquidityMathAddDelta incorrect result for addition")
				}
			}
			successCount++
		}, shouldFail, "liquidityMathAddDelta")
	}

	t.Logf("liquidityMathAddDelta: %d successful, %d underflows, %d overflows",
		successCount, underflowCount, overflowCount)

	// nil inputs
	helper.assertPanic(func() {
		liquidityMathAddDelta(nil, i256.One())
	}, true, "nil x input")

	helper.assertPanic(func() {
		liquidityMathAddDelta(u256.One(), nil)
	}, true, "nil y input")
}

func TestFuzzToUint128(t *testing.T) {
	helper := newPoolTestHelper(t)
	gen := fuzzer.NewUint256Generator(true, 256)

	truncatedCount := 0
	unchangedCount := 0

	for i := 0; i < 1000; i++ {
		value := gen.Generate().(*u256.Uint)

		helper.assertPanic(func() {
			result := toUint128(value)

			maxUint128 := u256.MustFromDecimal(MAX_UINT128)

			if value.Gt(maxUint128) {
				// when the value is greater than 128 bits,
				// theoretically it should be truncated to 128 bits
				if result.Gt(maxUint128) {
					t.Errorf("toUint128 failed to truncate value: %s", result.ToString())
				}
				truncatedCount++
			} else {
				// value should remain unchanged
				if !result.Eq(value) {
					t.Errorf("toUint128 modified value within range: %s != %s",
						value.ToString(), result.ToString())
				}
				unchangedCount++
			}
		}, false, "toUint128")
	}

	t.Logf("toUint128: %d values truncated, %d unchanged", truncatedCount, unchangedCount)

	helper.assertPanic(func() {
		toUint128(nil)
	}, true, "nil input")
}

func TestFuzzU256Min(t *testing.T) {
	gen := fuzzer.NewUint256Generator(true, 256)

	for i := 0; i < 1000; i++ {
		num1 := gen.Generate().(*u256.Uint)
		num2 := gen.Generate().(*u256.Uint)

		result := u256Min(num1, num2)

		if num1.Lt(num2) {
			if !result.Eq(num1) {
				t.Errorf("u256Min returned wrong value: expected %s, got %s",
					num1.ToString(), result.ToString())
			}
		} else {
			if !result.Eq(num2) {
				t.Errorf("u256Min returned wrong value: expected %s, got %s",
					num2.ToString(), result.ToString())
			}
		}
	}

	val := u256.MustFromDecimal("12345678901234567890")
	result := u256Min(val, val)
	if !result.Eq(val) {
		t.Errorf("u256Min with equal values failed")
	}
}

func TestFuzzCheckTickSpacing(t *testing.T) {
	helper := newPoolTestHelper(t)

	validSpacings := []int32{1, 10, 60, 200}

	for _, spacing := range validSpacings {
		// multiples of spacings are valid
		for i := 0; i < 100; i++ {
			multiplier := int32(fuzzer.IntRange(-1000, 1000).Generate().(int))
			tick := multiplier * spacing

			helper.assertPanic(func() {
				checkTickSpacing(tick, spacing)
			}, false, "valid tick spacing")
		}

		// invalid ticks (not multiples of spacing)
		if spacing > 1 {
			for i := 0; i < 100; i++ {
				multiplier := int32(fuzzer.IntRange(-1000, 1000).Generate().(int))
				offset := int32(fuzzer.IntRange(1, int(spacing-1)).Generate().(int))
				tick := multiplier*spacing + offset

				helper.assertPanic(func() {
					checkTickSpacing(tick, spacing)
				}, true, "invalid tick spacing")
			}
		}
	}
}

func TestFuzzOverflows(t *testing.T) {
	helper := newPoolTestHelper(t)

	t.Run("MultiplicationOverflow", func(t *testing.T) {
		// NOTE: u256 multiplication wraps on overflow, doesn't panic
		// Test that we can detect overflow by checking if `result < operands`
		largeVals := []struct {
			val         string
			description string
		}{
			{"115792089237316195423570985008687907853269984665640564039457584007913129639935", "MAX_UINT256"},
			{"57896044618658097711785492504343953926634992332820282019728792003956564819967", "MAX_UINT256 / 2"},
			{MAX_UINT128, "MAX_UINT128"},
		}

		overflowCount := 0
		for _, test1 := range largeVals {
			for _, test2 := range largeVals {
				v1 := u256.MustFromDecimal(test1.val)
				v2 := u256.MustFromDecimal(test2.val)

				result := new(u256.Uint).Mul(v1, v2)

				// Check for overflow by seeing if result wrapped
				// For large values, multiplication should wrap
				if v1.Gt(u256.One()) && v2.Gt(u256.One()) {
					// If both `operands > 1`, `result` should be > both `operands`
					// Otherwise, overflow occurred
					if result.Lt(v1) || result.Lt(v2) {
						overflowCount++
						t.Logf("Overflow detected: %s * %s wrapped to %s",
							test1.description, test2.description, result.ToString())
					}
				}
			}
		}

		if overflowCount == 0 {
			t.Errorf("Expected multiplication overflows but none detected")
		}
	})

	t.Run("uint256 -> int256 -> int128", func(t *testing.T) {
		tests := []struct {
			value       string
			shouldFail  bool
			description string
		}{
			{"170141183460469231731687303715884105727", false, "MAX_INT128"},
			{"170141183460469231731687303715884105728", true, "MAX_INT128 + 1"},
			{"340282366920938463463374607431768211455", true, "MAX_UINT128"},
			{MAX_INT256, true, "MAX_INT256"},
		}

		for _, tt := range tests {
			helper.assertPanic(func() {
				val := u256.MustFromDecimal(tt.value)
				int256Val := i256.FromUint256(val)

				maxInt128 := i256.MustFromDecimal(MAX_INT128)
				if int256Val.Gt(maxInt128) {
					panic("value exceeds int128 range")
				}
			}, tt.shouldFail, tt.description)
		}
	})
}

// TestFuzzTickToSqrtPriceX96 tests TickMathGetSqrtRatioAtTick function
func TestFuzzTickToSqrtPriceX96(t *testing.T) {
	helper := newPoolTestHelper(t)

	// Test valid tick range
	t.Run("ValidTickRange", func(t *testing.T) {
		tickGen := fuzzer.IntRange(-887272, 887272)

		for i := 0; i < 1000; i++ {
			tick := int32(tickGen.Generate().(int))

			helper.assertPanic(func() {
				sqrtPrice := common.TickMathGetSqrtRatioAtTick(tick)

				// Verify result is within valid range
				minSqrtRatio := u256.MustFromDecimal("4295128739")
				maxSqrtRatio := u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")

				if sqrtPrice.Lt(minSqrtRatio) || sqrtPrice.Gt(maxSqrtRatio) {
					t.Errorf("sqrtPrice %s out of valid range for tick %d", sqrtPrice.ToString(), tick)
				}

				// Verify monotonicity: higher tick = higher sqrtPrice
				if tick < 887272 {
					nextSqrtPrice := common.TickMathGetSqrtRatioAtTick(tick + 1)
					if !nextSqrtPrice.Gt(sqrtPrice) {
						t.Errorf("Monotonicity violated: tick %d sqrtPrice %s >= tick %d sqrtPrice %s",
							tick, sqrtPrice.ToString(), tick+1, nextSqrtPrice.ToString())
					}
				}
			}, false, "valid tick to sqrtPrice conversion")
		}
	})

	// Test invalid tick range
	t.Run("InvalidTickRange", func(t *testing.T) {
		invalidTicks := []int32{
			-887273,
			-1000000,
			887273,
			1000000,
			-2147483648, // MIN_INT32
			2147483647,  // MAX_INT32
		}

		for _, tick := range invalidTicks {
			helper.assertPanic(func() {
				common.TickMathGetSqrtRatioAtTick(tick)
			}, true, "invalid tick should panic")
		}
	})

	// Test boundary values
	t.Run("BoundaryValues", func(t *testing.T) {
		boundaryTests := []struct {
			tick              int32
			expectedSqrtPrice string
			description       string
		}{
			{-887272, "4295128739", "MIN_TICK"},
			{887272, "1461446703485210103287273052203988822378723970342", "MAX_TICK"},
			{0, "79228162514264337593543950336", "ZERO_TICK"}, // sqrt(1) * 2^96
		}

		for _, test := range boundaryTests {
			sqrtPrice := common.TickMathGetSqrtRatioAtTick(test.tick)
			expected := u256.MustFromDecimal(test.expectedSqrtPrice)

			if !sqrtPrice.Eq(expected) {
				t.Errorf("%s: expected sqrtPrice %s, got %s",
					test.description, test.expectedSqrtPrice, sqrtPrice.ToString())
			}
		}
	})
}

func TestFuzzSqrtPriceX96ToTick(t *testing.T) {
	helper := newPoolTestHelper(t)

	t.Run("Valid sqrtPrice range", func(t *testing.T) {
		for i := 0; i < 1000; i++ {
			// Generate random tick and get its sqrtPrice
			tickGen := fuzzer.IntRange(-887272, 887272)
			originalTick := int32(tickGen.Generate().(int))
			sqrtPrice := common.TickMathGetSqrtRatioAtTick(originalTick)

			helper.assertPanic(func() {
				resultTick := common.TickMathGetTickAtSqrtRatio(sqrtPrice)

				// The result should be the same or slightly lower due to rounding
				// TickMathGetTickAtSqrtRatio returns the greatest tick for which
				// getSqrtRatioAtTick(tick) <= sqrtPriceX96
				if resultTick > originalTick {
					t.Errorf("Result tick %d > original tick %d", resultTick, originalTick)
				}

				// The difference should be at most 1 due to rounding
				if originalTick-resultTick > 1 {
					t.Errorf("Tick difference too large: original %d, result %d", originalTick, resultTick)
				}
			}, false, "valid sqrtPrice to tick conversion")
		}
	})

	t.Run("Invalid sqrtPrice range", func(t *testing.T) {
		invalidSqrtPrices := []string{
			"0",
			"1",
			"4295128738", // MIN_SQRT_RATIO - 1
			"1461446703485210103287273052203988822378723970343", // MAX_SQRT_RATIO + 1
			MAX_UINT256,
		}

		for _, sqrtPriceStr := range invalidSqrtPrices {
			sqrtPrice := u256.MustFromDecimal(sqrtPriceStr)
			helper.assertPanic(func() {
				common.TickMathGetTickAtSqrtRatio(sqrtPrice)
			}, true, "invalid sqrtPrice should panic")
		}
	})

	t.Run("Round trip conversion", func(t *testing.T) {
		tickGen := fuzzer.IntRange(-887272, 887271) // Exclude MAX_TICK (887272)

		for i := 0; i < 500; i++ {
			originalTick := int32(tickGen.Generate().(int))

			// Convert tick -> sqrtPrice -> tick
			sqrtPrice := common.TickMathGetSqrtRatioAtTick(originalTick)
			resultTick := common.TickMathGetTickAtSqrtRatio(sqrtPrice)

			// Due to rounding, resultTick should be either originalTick or originalTick-1
			if resultTick != originalTick && resultTick != originalTick-1 {
				t.Errorf("Round-trip conversion failed: original %d, result %d", originalTick, resultTick)
			}

			// If we convert the resultTick back to sqrtPrice, it should be <= original sqrtPrice
			resultSqrtPrice := common.TickMathGetSqrtRatioAtTick(resultTick)
			if resultSqrtPrice.Gt(sqrtPrice) {
				t.Errorf("Round-trip sqrtPrice increased: original %s, result %s",
					sqrtPrice.ToString(), resultSqrtPrice.ToString())
			}
		}

		// Special test for MAX_TICK
		maxTick := int32(887272)
		maxSqrtPrice := common.TickMathGetSqrtRatioAtTick(maxTick)

		// TickMathGetTickAtSqrtRatio should panic for MAX_SQRT_RATIO
		helper.assertPanic(func() {
			common.TickMathGetTickAtSqrtRatio(maxSqrtPrice)
		}, true, "MAX_SQRT_RATIO should panic in TickMathGetTickAtSqrtRatio")
	})

	t.Run("Precision at boundaries", func(t *testing.T) {
		// Test ticks near boundaries (excluding MAX_TICK)
		boundaryTicks := []int32{
			-887272, -887271, -887270, // Near MIN_TICK
			-1, 0, 1, // Near zero
			887270, 887271, // Near MAX_TICK (excluding 887272)
		}

		for _, tick := range boundaryTicks {
			sqrtPrice := common.TickMathGetSqrtRatioAtTick(tick)
			resultTick := common.TickMathGetTickAtSqrtRatio(sqrtPrice)

			// Verify the invariant: getSqrtRatioAtTick(resultTick) <= sqrtPrice < getSqrtRatioAtTick(resultTick + 1)
			resultSqrtPrice := common.TickMathGetSqrtRatioAtTick(resultTick)
			if resultSqrtPrice.Gt(sqrtPrice) {
				t.Errorf("Invariant violated at tick %d: resultSqrtPrice %s > sqrtPrice %s",
					tick, resultSqrtPrice.ToString(), sqrtPrice.ToString())
			}

			if resultTick < 887272 {
				nextSqrtPrice := common.TickMathGetSqrtRatioAtTick(resultTick + 1)
				if !sqrtPrice.Lt(nextSqrtPrice) {
					t.Errorf("Invariant violated at tick %d: sqrtPrice %s >= nextSqrtPrice %s",
						tick, sqrtPrice.ToString(), nextSqrtPrice.ToString())
				}
			}
		}

		// Special test for edge case: sqrtPrice values near MAX_SQRT_RATIO
		maxSqrtRatio := u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")

		// Test that sqrtPrice < MAX_SQRT_RATIO works
		justBelowMax := new(u256.Uint).Sub(maxSqrtRatio, u256.One())
		tick := common.TickMathGetTickAtSqrtRatio(justBelowMax)
		if tick != 887271 {
			t.Errorf("Expected tick 887271 for sqrtPrice just below MAX_SQRT_RATIO, got %d", tick)
		}

		// Test MIN_TICK edge case
		minTick := int32(-887272)
		minSqrtPrice := common.TickMathGetSqrtRatioAtTick(minTick)
		resultMinTick := common.TickMathGetTickAtSqrtRatio(minSqrtPrice)
		if resultMinTick != minTick {
			t.Errorf("MIN_TICK round-trip failed: expected %d, got %d", minTick, resultMinTick)
		}
	})
}
