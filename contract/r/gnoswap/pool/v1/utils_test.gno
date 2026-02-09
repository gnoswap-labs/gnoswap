package v1

import (
	"strings"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
	pl "gno.land/r/gnoswap/pool"
)

const (
	MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

	UINT64_MAX uint64 = 18446744073709551615
)

func TestU256Min(t *testing.T) {
	tests := []struct {
		name     string
		num1     string
		num2     string
		expected string
	}{
		// Basic cases
		{
			name:     "num1 is less than num2",
			num1:     "1",
			num2:     "2",
			expected: "1",
		},
		{
			name:     "num1 is greater than num2",
			num1:     "2",
			num2:     "1",
			expected: "1",
		},
		{
			name:     "num1 is equal to num2",
			num1:     "1",
			num2:     "1",
			expected: "1",
		},

		// Edge cases with zero
		{
			name:     "compare max u256 with zero",
			num1:     MAX_UINT256,
			num2:     "0",
			expected: "0",
		},
		{
			name:     "compare zero with non-zero",
			num1:     "0",
			num2:     "1",
			expected: "0",
		},

		// Close values
		{
			name:     "very close values (num1 smaller)",
			num1:     "999999999999999999",
			num2:     "1000000000000000000",
			expected: "999999999999999999",
		},
		{
			name:     "very close values (num2 smaller)",
			num1:     "1000000000000000000",
			num2:     "999999999999999999",
			expected: "999999999999999999",
		},

		// Large values
		{
			name:     "large values (num1 smaller)",
			num1:     "115792089237316195423570985008687907853269984665640564039457584007913129639934",
			num2:     MAX_UINT256,
			expected: "115792089237316195423570985008687907853269984665640564039457584007913129639934",
		},
		{
			name:     "large values (num2 smaller)",
			num1:     MAX_UINT256,
			num2:     "115792089237316195423570985008687907853269984665640564039457584007913129639934",
			expected: "115792089237316195423570985008687907853269984665640564039457584007913129639934",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			num1 := u256.MustFromDecimal(tt.num1)
			num2 := u256.MustFromDecimal(tt.num2)
			expected := u256.MustFromDecimal(tt.expected)

			result := u256Min(num1, num2)
			uassert.Equal(t, expected.ToString(), result.ToString())
		})
	}
}

func TestU256Min_AdditionalCases(t *testing.T) {
	tests := []struct {
		name     string
		num1     string
		num2     string
		expected string
	}{
		// Q values comparison
		{
			name:     "Q64 vs Q96",
			num1:     Q64,
			num2:     Q96,
			expected: Q64,
		},
		{
			name:     "Q96 vs Q128",
			num1:     Q96,
			num2:     Q128,
			expected: Q96,
		},
		// Price boundaries
		{
			name:     "MIN_SQRT_RATIO vs MAX_SQRT_RATIO",
			num1:     MIN_SQRT_RATIO,
			num2:     MAX_SQRT_RATIO,
			expected: MIN_SQRT_RATIO,
		},
		// Different magnitudes
		{
			name:     "very small vs very large",
			num1:     "1",
			num2:     MAX_UINT256,
			expected: "1",
		},
		{
			name:     "consecutive values",
			num1:     "999999999999999999999999999999999999999",
			num2:     "1000000000000000000000000000000000000000",
			expected: "999999999999999999999999999999999999999",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			num1 := u256.MustFromDecimal(tt.num1)
			num2 := u256.MustFromDecimal(tt.num2)
			expected := u256.MustFromDecimal(tt.expected)

			result := u256Min(num1, num2)
			uassert.Equal(t, expected.ToString(), result.ToString())

			// Test commutativity
			resultReversed := u256Min(num2, num1)
			uassert.Equal(t, expected.ToString(), resultReversed.ToString())
		})
	}
}

func TestSafeConvertToUint64(t *testing.T) {
	tests := []struct {
		name      string
		value     *u256.Uint
		wantRes   uint64
		wantPanic bool
		errorMsg  string
	}{
		// Normal cases
		{
			name:      "normal conversion - small",
			value:     u256.NewUint(123),
			wantRes:   123,
			wantPanic: false,
			errorMsg:  "",
		},
		{
			name:      "normal conversion - medium",
			value:     u256.NewUint(1000000),
			wantRes:   1000000,
			wantPanic: false,
			errorMsg:  "",
		},
		{
			name:      "zero",
			value:     u256.NewUint(0),
			wantRes:   0,
			wantPanic: false,
			errorMsg:  "",
		},

		// Boundary cases
		{
			name:      "max uint64 - 2",
			value:     u256.NewUint(18446744073709551613),
			wantRes:   18446744073709551613,
			wantPanic: false,
			errorMsg:  "",
		},
		{
			name:      "max uint64 - 1",
			value:     u256.NewUint(18446744073709551614),
			wantRes:   18446744073709551614,
			wantPanic: false,
			errorMsg:  "",
		},
		{
			name:      "max uint64",
			value:     u256.NewUint(1<<64 - 1),
			wantRes:   1<<64 - 1,
			wantPanic: false,
			errorMsg:  "",
		},

		// Overflow cases
		{
			name:      "overflow - max uint64 + 1",
			value:     u256.MustFromDecimal("18446744073709551616"),
			wantRes:   0,
			wantPanic: true,
			errorMsg:  "[GNOSWAP-POOL-003] out of range for numeric value: amount(18446744073709551616) overflows uint64 range (max 18446744073709551615)",
		},
		{
			name:      "overflow - large value",
			value:     u256.MustFromDecimal(MAX_UINT128),
			wantRes:   0,
			wantPanic: true,
			errorMsg:  "[GNOSWAP-POOL-003] out of range for numeric value: amount(340282366920938463463374607431768211455) overflows uint64 range (max 18446744073709551615)",
		},
		{
			name:      "overflow - very large value",
			value:     u256.MustFromDecimal(MAX_UINT256),
			wantRes:   0,
			wantPanic: true,
			errorMsg:  "[GNOSWAP-POOL-003] out of range for numeric value: amount(115792089237316195423570985008687907853269984665640564039457584007913129639935) overflows uint64 range (max 18446744073709551615)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.wantPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					safeConvertToUint64(tt.value)
				})
			} else {
				res := safeConvertToUint64(tt.value)
				uassert.Equal(t, tt.wantRes, res)
			}
		})
	}
}

func TestSafeConvertToInt64(t *testing.T) {
	tests := []struct {
		name      string
		value     *u256.Uint
		wantRes   int64
		wantPanic bool
		errorMsg  string
	}{
		// Normal cases
		{"small positive number", u256.NewUint(123), 123, false, ""},
		{"medium positive number", u256.NewUint(1000000), 1000000, false, ""},
		{"zero", u256.NewUint(0), 0, false, ""},

		// Boundary cases for int64
		{"max int64 - 1", u256.NewUint(9223372036854775806), 9223372036854775806, false, ""},
		{"max int64", u256.NewUint(9223372036854775807), 9223372036854775807, false, ""},
		{"max int64 + 1 (overflow)", u256.NewUint(9223372036854775808), 0, true, "[GNOSWAP-POOL-003] out of range for numeric value: amount(9223372036854775808) overflows int64 range (max 9223372036854775807)"},

		// Mid-range boundaries
		{"2^32", u256.NewUint(4294967296), 4294967296, false, ""},
		{"2^48", u256.NewUint(281474976710656), 281474976710656, false, ""},

		// Values between max int64 and max uint64
		{"value between max int64 and max uint64 (1)", u256.NewUint(10000000000000000000), 0, true, "[GNOSWAP-POOL-003] out of range for numeric value: amount(10000000000000000000) overflows int64 range (max 9223372036854775807)"},
		{"value between max int64 and max uint64 (2)", u256.NewUint(15000000000000000000), 0, true, "[GNOSWAP-POOL-003] out of range for numeric value: amount(15000000000000000000) overflows int64 range (max 9223372036854775807)"},

		// Extreme cases - these will fail on uint64 conversion first
		{"max uint64 + 1 (overflow)", u256.MustFromDecimal("18446744073709551616"), 0, true, "[GNOSWAP-POOL-003] out of range for numeric value: amount(18446744073709551616) overflows uint64 range (max 18446744073709551615)"},
		{"very large number (MAX_UINT128)", u256.MustFromDecimal(MAX_UINT128), 0, true, "[GNOSWAP-POOL-003] out of range for numeric value: amount(340282366920938463463374607431768211455) overflows uint64 range (max 18446744073709551615)"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.wantPanic {
						t.Errorf("unexpected panic: %v", r)
					}
					return
				}
				if tt.wantPanic {
					t.Errorf("expected panic, but none occurred")
				}
			}()

			res := safeConvertToInt64(tt.value)
			if res != tt.wantRes {
				t.Errorf("safeConvertToInt64() = %v, want %v", res, tt.wantRes)
			}
		})
	}
}

func TestSafeConvertToInt128(t *testing.T) {
	tests := []struct {
		name      string
		value     string
		wantRes   string
		wantPanic bool
		errorMsg  string
	}{
		// Normal cases
		{"zero", "0", "0", false, ""},
		{"small positive value", "123", "123", false, ""},
		{"medium positive value", "1000000", "1000000", false, ""},

		// Power of 2 boundaries
		{"2^64", Q64, Q64, false, ""},
		{"2^96", Q96, Q96, false, ""},

		// Boundary cases
		{"close to MAX_INT128", "170141183460469231731687303715884105726", "170141183460469231731687303715884105726", false, ""},
		{"MAX_INT128", MAX_INT128, MAX_INT128, false, ""},

		// Overflow cases
		{"just over MAX_INT128", "170141183460469231731687303715884105728", "", true, "[GNOSWAP-POOL-020] overflow: amount(170141183460469231731687303715884105728) overflows int128 range"},
		{"large overflow", MAX_UINT128, "", true, "[GNOSWAP-POOL-020] overflow: amount(340282366920938463463374607431768211455) overflows int128 range"},
		{"extreme overflow", MAX_UINT256, "", true, "[GNOSWAP-POOL-020] overflow: amount(115792089237316195423570985008687907853269984665640564039457584007913129639935) overflows int128 range"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.wantPanic {
						t.Errorf("unexpected panic: %v", r)
					}
					return
				}
				if tt.wantPanic {
					t.Errorf("expected panic, but none occurred")
				}
			}()

			res := safeConvertToInt128(u256.MustFromDecimal(tt.value))
			if res.ToString() != tt.wantRes {
				t.Errorf("safeConvertToInt128() = %v, want %v", res.ToString(), tt.wantRes)
			}
		})
	}
}

func TestToUint128InputPreservation(t *testing.T) {
	tests := []struct {
		name                      string
		input                     string
		expectedResult            string
		expectedOriginal          string
		shouldBeDifferentInstance bool
	}{
		{
			name:                      "overflow case - input preservation",
			input:                     MAX_UINT256,
			expectedResult:            MAX_UINT128,
			expectedOriginal:          MAX_UINT256,
			shouldBeDifferentInstance: true,
		},
		{
			name:                      "within range case - input preservation",
			input:                     "1000",
			expectedResult:            "1000",
			expectedOriginal:          "1000",
			shouldBeDifferentInstance: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			original := u256.MustFromDecimal(tt.input)
			result := toUint128(original)

			// Original should be unchanged
			uassert.Equal(t, tt.expectedOriginal, original.ToString())
			// Result should have expected value
			uassert.Equal(t, tt.expectedResult, result.ToString())

			// Check instance relationship
			if tt.shouldBeDifferentInstance {
				uassert.True(t, result != original, "result should be a different instance")
			} else {
				uassert.True(t, result == original, "result should be the same instance")
			}
		})
	}
}

func TestToUint128_PowerOfTwoBoundaries(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Q64 (2^64)",
			input:    Q64,
			expected: Q64,
		},
		{
			name:     "Q96 (2^96)",
			input:    Q96,
			expected: Q96,
		},
		{
			name:     "2^127",
			input:    "170141183460469231731687303715884105728",
			expected: "170141183460469231731687303715884105728",
		},
		{
			name:     "Q128 (2^128) wraps to 0",
			input:    Q128,
			expected: "0",
		},
		{
			name:     "2^128 + 1 wraps to 1",
			input:    "340282366920938463463374607431768211457",
			expected: "1",
		},
		{
			name:     "2^129 wraps to 0",
			input:    "680564733841876926926749214863536422912",
			expected: "0",
		},
		{
			name:     "MAX_UINT128 * 2 + 10",
			input:    "680564733841876926926749214863536422920",
			expected: "8",
		},
		// Price boundaries
		{
			name:     "MIN_SQRT_RATIO",
			input:    MIN_SQRT_RATIO,
			expected: MIN_SQRT_RATIO,
		},
		{
			name:     "MAX_SQRT_RATIO overflows uint128",
			input:    MAX_SQRT_RATIO,
			expected: "318775800626314356294205765087544249638",
			// MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
			// This value is used as the maximum price square root in Uniswap V3
			// When masked to uint128 (keeping only lower 128 bits):
			// Binary: ...10101010101010101010101010100110 (lower 128 bits)
			// Decimal: 318775800626314356294205765087544249638
		},
		{
			name:     "MIN_PRICE",
			input:    MIN_PRICE,
			expected: MIN_PRICE,
		},
		{
			name:     "MAX_PRICE overflows uint128",
			input:    MAX_PRICE,
			expected: "318775800626314356294205765087544249637",
			// MAX_PRICE = MAX_SQRT_RATIO - 1 = 1461446703485210103287273052203988822378723970341
			// When masked to uint128:
			// Result: 318775800626314356294205765087544249637 (masked MAX_SQRT_RATIO - 1)
			// This masking ensures price calculations remain within bounds
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			original := u256.MustFromDecimal(tt.input)
			originalStr := original.ToString()

			result := toUint128(original)

			uassert.Equal(t, tt.expected, result.ToString())
			uassert.Equal(t, originalStr, original.ToString())
		})
	}
}

func TestVerifyToUint128MaskingLogic(t *testing.T) {
	// 1. Verify toUint128 function logic
	// toUint128 keeps only lower 128 bits when value > MAX_UINT128

	// Verify MAX_UINT128
	maxUint128 := u256.MustFromDecimal(MAX_UINT128)
	uassert.Equal(t, "340282366920938463463374607431768211455", maxUint128.ToString())
	uassert.Equal(t, MAX_UINT128, maxUint128.ToString())

	// 2. Verify MAX_SQRT_RATIO

	uassert.Equal(t, MAX_SQRT_RATIO, "1461446703485210103287273052203988822378723970342")
	uassert.True(t, maxSqrtRatio.Gt(maxUint128), "MAX_SQRT_RATIO should be > MAX_UINT128")

	// 3. Verify masking logic
	// mask = (1 << 128) - 1 = MAX_UINT128
	mask := new(u256.Uint).Lsh(u256.One(), 128)
	mask = new(u256.Uint).Sub(mask, u256.One())
	uassert.Equal(t, mask.ToString(), maxUint128.ToString())

	// 4. Verify actual masking
	maskedMaxSqrt := new(u256.Uint).And(maxSqrtRatio, mask)
	uassert.Equal(t, "318775800626314356294205765087544249638", maskedMaxSqrt.ToString())

	// 5. Verify toUint128 function result matches manual masking
	toUint128Result := toUint128(maxSqrtRatio)
	uassert.Equal(t, maskedMaxSqrt.ToString(), toUint128Result.ToString())

	// 6. Verify MAX_PRICE (MAX_SQRT_RATIO - 1)
	maxPrice := u256.MustFromDecimal(MAX_PRICE)
	uassert.Equal(t, MAX_PRICE, "1461446703485210103287273052203988822378723970341")

	// Verify MAX_PRICE = MAX_SQRT_RATIO - 1
	maxSqrtMinusOne := new(u256.Uint).Sub(maxSqrtRatio, u256.One())
	uassert.True(t, maxPrice.Eq(maxSqrtMinusOne), "MAX_PRICE should equal MAX_SQRT_RATIO - 1")

	// 7. Verify MAX_PRICE masking
	maskedMaxPrice := new(u256.Uint).And(maxPrice, mask)
	uassert.Equal(t, "318775800626314356294205765087544249637", maskedMaxPrice.ToString())

	toUint128PriceResult := toUint128(maxPrice)
	uassert.Equal(t, maskedMaxPrice.ToString(), toUint128PriceResult.ToString())

	// 8. Verify difference between masked values is 1
	diff := new(u256.Uint).Sub(maskedMaxSqrt, maskedMaxPrice)
	uassert.Equal(t, "1", diff.ToString())

	// Final verification
	uassert.Equal(t, "318775800626314356294205765087544249638", toUint128Result.ToString())
	uassert.Equal(t, "318775800626314356294205765087544249637", toUint128PriceResult.ToString())
}

// Additional verification: Ensure masked values are within uint128 range
func TestToUint128MaskedValuesRange(t *testing.T) {
	maxUint128 := u256.MustFromDecimal(MAX_UINT128)

	// toUint128 results
	resultMaxSqrt := toUint128(maxSqrtRatio)
	resultMaxPrice := toUint128(u256.MustFromDecimal(MAX_PRICE))

	// Verify results are <= MAX_UINT128
	uassert.True(t, resultMaxSqrt.Lte(maxUint128), "Masked MAX_SQRT_RATIO should be <= MAX_UINT128")
	uassert.True(t, resultMaxPrice.Lte(maxUint128), "Masked MAX_PRICE should be <= MAX_UINT128")

	// Verify specific values
	uassert.Equal(t, "318775800626314356294205765087544249638", resultMaxSqrt.ToString())
	uassert.Equal(t, "318775800626314356294205765087544249637", resultMaxPrice.ToString())
}

func TestCheckOverFlowInt128_BoundaryValues(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		shouldPanic bool
		errorMsg    string
	}{
		// Exact boundaries
		{
			name:        "MAX_INT128 exact",
			input:       MAX_INT128,
			shouldPanic: false,
		},
		{
			name:        "MAX_INT128 + 1",
			input:       "170141183460469231731687303715884105728",
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-020] overflow: amount(170141183460469231731687303715884105728) overflows int128 range",
		},
		// Negative values
		{
			name:        "negative MAX_INT128",
			input:       "-170141183460469231731687303715884105727",
			shouldPanic: false,
		},
		{
			name:        "negative MAX_INT128 - 1",
			input:       "-170141183460469231731687303715884105728",
			shouldPanic: false,
		},
		// Q values
		{
			name:        "Q96 within range",
			input:       Q96,
			shouldPanic: false,
		},
		{
			name:        "Q128 exceeds range",
			input:       Q128,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-020] overflow: amount(340282366920938463463374607431768211456) overflows int128 range",
		},
		// Special values
		{
			name:        "zero",
			input:       "0",
			shouldPanic: false,
		},
		{
			name:        "one",
			input:       "1",
			shouldPanic: false,
		},
		{
			name:        "negative one",
			input:       "-1",
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value := i256.MustFromDecimal(tt.input)
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					checkOverFlowInt128(value)
				})
			} else {
				uassert.NotPanics(t, func() {
					checkOverFlowInt128(value)
				})
			}
		})
	}
}

func TestCheckTickSpacing(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "Valid tick - divisible by tickSpacing",
			tick:        120,
			tickSpacing: 60,
			shouldPanic: false,
		},
		{
			name:        "Valid tick - zero tick",
			tick:        0,
			tickSpacing: 10,
			shouldPanic: false,
		},
		{
			name:        "Invalid tick - not divisible",
			tick:        15,
			tickSpacing: 10,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(15) MOD tickSpacing(10) != 0(5)",
		},
		{
			name:        "Invalid tick - negative tick",
			tick:        -35,
			tickSpacing: 20,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(-35) MOD tickSpacing(20) != 0(-15)",
		},
		// Edge cases with extreme tick values
		{
			name:        "min tick boundary",
			tick:        MIN_TICK, // -887272
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "max tick boundary",
			tick:        MAX_TICK, // 887272
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "large tick spacing",
			tick:        600,
			tickSpacing: 200,
			shouldPanic: false,
		},
		{
			name:        "negative tick valid spacing",
			tick:        -600,
			tickSpacing: 200,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.shouldPanic {
						t.Errorf("Unexpected panic: %v", r)
					}
				} else if tt.shouldPanic {
					t.Errorf("Expected panic but none occurred")
				}
			}()
			checkTickSpacing(tt.tick, tt.tickSpacing)
		})
	}
}

func TestCheckTickSpacing_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		tick        int32
		tickSpacing int32
		shouldPanic bool
		errorMsg    string
	}{
		// Boundary values with tick spacing 1
		{
			name:        "MIN_TICK with spacing 1",
			tick:        MIN_TICK,
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "MAX_TICK with spacing 1",
			tick:        MAX_TICK,
			tickSpacing: 1,
			shouldPanic: false,
		},
		// Fee tier tick spacings
		{
			name:        "fee tier 100 - valid tick",
			tick:        12345,
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "fee tier 500 - valid tick",
			tick:        12340,
			tickSpacing: 10,
			shouldPanic: false,
		},
		{
			name:        "fee tier 500 - invalid tick",
			tick:        12345,
			tickSpacing: 10,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(12345) MOD tickSpacing(10) != 0(5)",
		},
		{
			name:        "fee tier 3000 - valid tick",
			tick:        -12360,
			tickSpacing: 60,
			shouldPanic: false,
		},
		{
			name:        "fee tier 3000 - invalid tick",
			tick:        -12359,
			tickSpacing: 60,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(-12359) MOD tickSpacing(60) != 0(-59)",
		},
		{
			name:        "fee tier 10000 - valid tick",
			tick:        -12400,
			tickSpacing: 200,
			shouldPanic: false,
		},
		{
			name:        "fee tier 10000 - invalid tick",
			tick:        -12399,
			tickSpacing: 200,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(-12399) MOD tickSpacing(200) != 0(-199)",
		},
		// Extreme boundary cases
		{
			name:        "near MIN_TICK aligned",
			tick:        -887200,
			tickSpacing: 100,
			shouldPanic: false,
		},
		{
			name:        "near MIN_TICK not aligned",
			tick:        -887271,
			tickSpacing: 100,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(-887271) MOD tickSpacing(100) != 0(-71)",
		},
		{
			name:        "maximum tick spacing",
			tick:        0,
			tickSpacing: 887272,
			shouldPanic: false,
		},
		{
			name:        "maximum tick spacing not aligned",
			tick:        1,
			tickSpacing: 887272,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-017] invalid tick and tick spacing requested || tick(1) MOD tickSpacing(887272) != 0(1)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					checkTickSpacing(tt.tick, tt.tickSpacing)
				})
			} else {
				uassert.NotPanics(t, func() {
					checkTickSpacing(tt.tick, tt.tickSpacing)
				})
			}
		})
	}
}

// Additional edge case tests for better coverage
func TestConversionBoundaryValues(t *testing.T) {
	t.Run("uint64 power of 2 boundaries", func(t *testing.T) {
		// Test various power of 2 values
		pow32 := u256.NewUint(1 << 32) // 4,294,967,296
		result := safeConvertToUint64(pow32)
		uassert.Equal(t, uint64(1<<32), result)

		pow48 := u256.NewUint(1 << 48)
		result = safeConvertToUint64(pow48)
		uassert.Equal(t, uint64(1<<48), result)

		pow63 := u256.NewUint(1 << 63) // 9,223,372,036,854,775,808
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("expected panic for 2^63, but none occurred")
			}
		}()
		safeConvertToInt64(pow63)
	})

	t.Run("edge case q values", func(t *testing.T) {
		// Q96 should work with int128
		q96 := u256.MustFromDecimal(Q96)
		result := safeConvertToInt128(q96)
		uassert.Equal(t, Q96, result.ToString())

		// Q128 is actually 2^128 which is larger than MAX_INT128 (2^127 - 1)
		// So it should panic
		q128Val := u256.MustFromDecimal(Q128)
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("expected panic for Q128 value, but none occurred")
			}
		}()
		safeConvertToInt128(q128Val)
	})
}

func TestSafeConversions_ExactBoundaries(t *testing.T) {
	t.Run("uint64 exact boundary", func(t *testing.T) {
		// MAX_UINT64
		maxValue := u256.MustFromDecimal(MAX_UINT64)
		result := safeConvertToUint64(maxValue)
		uassert.Equal(t, UINT64_MAX, result)

		// MAX_UINT64 + 1
		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"[GNOSWAP-POOL-003] out of range for numeric value: amount(18446744073709551616) overflows uint64 range (max 18446744073709551615)",
			func() { safeConvertToUint64(overValue) })
	})

	t.Run("int64 exact boundary", func(t *testing.T) {
		// MAX_INT64
		maxValue := u256.MustFromDecimal(MAX_INT64)
		result := safeConvertToInt64(maxValue)
		uassert.Equal(t, INT64_MAX, result)

		// MAX_INT64 + 1
		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"[GNOSWAP-POOL-003] out of range for numeric value: amount(9223372036854775808) overflows int64 range (max 9223372036854775807)",
			func() { safeConvertToInt64(overValue) })
	})

	t.Run("int128 exact boundary", func(t *testing.T) {
		// MAX_INT128
		maxValue := u256.MustFromDecimal(MAX_INT128)
		result := safeConvertToInt128(maxValue)
		uassert.Equal(t, MAX_INT128, result.ToString())

		// MAX_INT128 + 1
		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"[GNOSWAP-POOL-020] overflow: amount(170141183460469231731687303715884105728) overflows int128 range",
			func() { safeConvertToInt128(overValue) })
	})
}

func TestFormatFunctions(t *testing.T) {
	t.Run("formatUint", func(t *testing.T) {
		tests := []struct {
			name     string
			input    any
			expected string
			panics   bool
			errorMsg string
		}{
			{
				name:     "uint8",
				input:    uint8(255),
				expected: "255",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "uint32",
				input:    uint32(4294967295),
				expected: "4294967295",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "uint64",
				input:    uint64(18446744073709551615),
				expected: "18446744073709551615",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "uint8 zero",
				input:    uint8(0),
				expected: "0",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "invalid type string",
				input:    "string",
				expected: "",
				panics:   true,
				errorMsg: "invalid type: string",
			},
			{
				name:     "invalid type int",
				input:    int(42),
				expected: "",
				panics:   true,
				errorMsg: "invalid type: int",
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.panics {
					uassert.PanicsWithMessage(t, tt.errorMsg, func() {
						formatUint(tt.input)
					})
				} else {
					result := formatUint(tt.input)
					uassert.Equal(t, tt.expected, result)
				}
			})
		}
	})

	t.Run("formatInt", func(t *testing.T) {
		tests := []struct {
			name     string
			input    any
			expected string
			panics   bool
			errorMsg string
		}{
			{
				name:     "int32",
				input:    int32(-2147483648),
				expected: "-2147483648",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "int64",
				input:    int64(9223372036854775807),
				expected: "9223372036854775807",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "int",
				input:    int(42),
				expected: "42",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "int negative",
				input:    int(-42),
				expected: "-42",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "int32 zero",
				input:    int32(0),
				expected: "0",
				panics:   false,
				errorMsg: "",
			},
			{
				name:     "invalid type string",
				input:    "string",
				expected: "",
				panics:   true,
				errorMsg: "invalid type: string",
			},
			{
				name:     "invalid type uint",
				input:    uint(42),
				expected: "",
				panics:   true,
				errorMsg: "invalid type: uint",
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.panics {
					uassert.PanicsWithMessage(t, tt.errorMsg, func() {
						formatInt(tt.input)
					})
				} else {
					result := formatInt(tt.input)
					uassert.Equal(t, tt.expected, result)
				}
			})
		}
	})

	t.Run("formatBool", func(t *testing.T) {
		tests := []struct {
			name     string
			input    bool
			expected string
		}{
			{
				name:     "true",
				input:    true,
				expected: "true",
			},
			{
				name:     "false",
				input:    false,
				expected: "false",
			},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				result := formatBool(tt.input)
				uassert.Equal(t, tt.expected, result)
			})
		}
	})
}

// TestToUint128 tests the toUint128 function with edge cases
func TestToUint128(t *testing.T) {
	tests := []struct {
		name        string
		input       *u256.Uint
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "nil value panics",
			input:       nil,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-004] invalid input data || value is nil",
		},
		{
			name:        "zero value",
			input:       u256.Zero(),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "one value",
			input:       u256.One(),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "max uint128",
			input:       u256.MustFromDecimal(MAX_UINT128),
			expected:    MAX_UINT128,
			shouldPanic: false,
		},
		{
			name:        "max uint128 + 1 gets masked",
			input:       new(u256.Uint).Add(u256.MustFromDecimal(MAX_UINT128), u256.One()),
			expected:    "0", // wraps around due to masking
			shouldPanic: false,
		},
		{
			name:        "large value gets masked",
			input:       u256.MustFromDecimal("340282366920938463463374607431768211456"), // 2^128
			expected:    "0",                                                             // wraps to 0
			shouldPanic: false,
		},
		{
			name:        "Q96 value",
			input:       u256.MustFromDecimal(Q96),
			expected:    Q96,
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					toUint128(tt.input)
				})
			} else {
				result := toUint128(tt.input)
				uassert.Equal(t, tt.expected, result.ToString())
			}
		})
	}
}

// TestCheckOverFlowInt128 tests overflow detection for int128
func TestCheckOverFlowInt128(t *testing.T) {
	tests := []struct {
		name        string
		input       *i256.Int
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "zero value",
			input:       i256.Zero(),
			shouldPanic: false,
		},
		{
			name:        "positive value within range",
			input:       i256.MustFromDecimal("1000000000000000000"),
			shouldPanic: false,
		},
		{
			name:        "max int128",
			input:       i256.MustFromDecimal(MAX_INT128),
			shouldPanic: false,
		},
		{
			name:        "max int128 + 1",
			input:       new(i256.Int).Add(i256.MustFromDecimal(MAX_INT128), i256.One()),
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-020] overflow: amount(170141183460469231731687303715884105728) overflows int128 range",
		},
		{
			name:        "very large value",
			input:       i256.MustFromDecimal("999999999999999999999999999999999999999"),
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Error("Expected panic but none occurred")
					}
				}()
				checkOverFlowInt128(tt.input)
			} else {
				uassert.NotPanics(t, func() {
					checkOverFlowInt128(tt.input)
				})
			}
		})
	}
}

// TestFormatUint_AdditionalEdgeCases tests additional edge cases for formatUint
func TestFormatUint_AdditionalEdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "uint16 max",
			input:       uint16(65535),
			expected:    "65535",
			shouldPanic: false,
		},
		{
			name:        "uint16 zero",
			input:       uint16(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint16 one",
			input:       uint16(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "float64 type",
			input:       float64(3.14),
			shouldPanic: true,
			errorMsg:    "invalid type: unknown",
		},
		{
			name:        "bool type",
			input:       true,
			shouldPanic: true,
			errorMsg:    "invalid type: bool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					formatUint(tt.input)
				})
			} else {
				result := formatUint(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestSafeAddInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Success cases
		{
			name:        "positive + positive",
			a:           100,
			b:           200,
			expected:    300,
			shouldPanic: false,
		},
		{
			name:        "negative + negative",
			a:           -100,
			b:           -200,
			expected:    -300,
			shouldPanic: false,
		},
		{
			name:        "positive + negative",
			a:           100,
			b:           -50,
			expected:    50,
			shouldPanic: false,
		},
		{
			name:        "negative + positive",
			a:           -100,
			b:           150,
			expected:    50,
			shouldPanic: false,
		},
		{
			name:        "zero + positive",
			a:           0,
			b:           100,
			expected:    100,
			shouldPanic: false,
		},
		{
			name:        "zero + negative",
			a:           0,
			b:           -100,
			expected:    -100,
			shouldPanic: false,
		},
		{
			name:        "max + zero",
			a:           INT64_MAX,
			b:           0,
			expected:    INT64_MAX,
			shouldPanic: false,
		},
		{
			name:        "min + zero",
			a:           INT64_MIN,
			b:           0,
			expected:    INT64_MIN,
			shouldPanic: false,
		},
		{
			name:        "max + negative (safe)",
			a:           INT64_MAX,
			b:           -1,
			expected:    INT64_MAX - 1,
			shouldPanic: false,
		},
		{
			name:        "min + positive (safe)",
			a:           INT64_MIN,
			b:           1,
			expected:    INT64_MIN + 1,
			shouldPanic: false,
		},

		// Overflow cases
		{
			name:        "overflow: max + 1",
			a:           INT64_MAX,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "overflow: max + positive",
			a:           INT64_MAX,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "overflow: large + large",
			a:           INT64_MAX / 2,
			b:           INT64_MAX/2 + 2,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},

		// Underflow cases
		{
			name:        "underflow: min + (-1)",
			a:           INT64_MIN,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "underflow: min + negative",
			a:           INT64_MIN,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "underflow: large negative + large negative",
			a:           INT64_MIN / 2,
			b:           INT64_MIN/2 - 1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeAddInt64(tt.a, tt.b)
				})
			} else {
				result := safeAddInt64(tt.a, tt.b)
				uassert.Equal(t, tt.expected, result,
					ufmt.Sprintf("safeAddInt64(%d, %d) = %d, want %d", tt.a, tt.b, result, tt.expected))
			}
		})
	}
}

func TestSafeSubInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Success cases
		{
			name:        "positive - positive",
			a:           200,
			b:           100,
			expected:    100,
			shouldPanic: false,
		},
		{
			name:        "negative - negative",
			a:           -100,
			b:           -200,
			expected:    100,
			shouldPanic: false,
		},
		{
			name:        "positive - negative",
			a:           100,
			b:           -50,
			expected:    150,
			shouldPanic: false,
		},
		{
			name:        "negative - positive",
			a:           -100,
			b:           50,
			expected:    -150,
			shouldPanic: false,
		},
		{
			name:        "zero - positive",
			a:           0,
			b:           100,
			expected:    -100,
			shouldPanic: false,
		},
		{
			name:        "zero - negative",
			a:           0,
			b:           -100,
			expected:    100,
			shouldPanic: false,
		},
		{
			name:        "max - zero",
			a:           INT64_MAX,
			b:           0,
			expected:    INT64_MAX,
			shouldPanic: false,
		},
		{
			name:        "min - zero",
			a:           INT64_MIN,
			b:           0,
			expected:    INT64_MIN,
			shouldPanic: false,
		},
		{
			name:        "max - positive (safe)",
			a:           INT64_MAX,
			b:           1,
			expected:    INT64_MAX - 1,
			shouldPanic: false,
		},
		{
			name:        "min - negative (safe)",
			a:           INT64_MIN,
			b:           -1,
			expected:    INT64_MIN + 1,
			shouldPanic: false,
		},

		// Underflow cases
		{
			name:        "underflow: min - 1",
			a:           INT64_MIN,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "underflow: min - positive",
			a:           INT64_MIN,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "underflow: negative - large positive",
			a:           -100,
			b:           INT64_MAX,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "underflow: min - max",
			a:           INT64_MIN,
			b:           INT64_MAX,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},

		// Overflow cases
		{
			name:        "overflow: max - (-1)",
			a:           INT64_MAX,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "overflow: max - negative",
			a:           INT64_MAX,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "overflow: positive - large negative",
			a:           100,
			b:           INT64_MIN,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "overflow: max - min",
			a:           INT64_MAX,
			b:           INT64_MIN,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeSubInt64(tt.a, tt.b)
				})
			} else {
				result := safeSubInt64(tt.a, tt.b)
				uassert.Equal(t, tt.expected, result,
					ufmt.Sprintf("safeSubInt64(%d, %d) = %d, want %d", tt.a, tt.b, result, tt.expected))
			}
		})
	}
}

// TestU256Min_EdgeCases tests the u256Min utility function
func TestU256Min_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		a           *u256.Uint
		b           *u256.Uint
		expected    *u256.Uint
		description string
	}{
		{
			name:        "both zero",
			a:           u256.Zero(),
			b:           u256.Zero(),
			expected:    u256.Zero(),
			description: "Min of two zeros should be zero",
		},
		{
			name:        "first zero",
			a:           u256.Zero(),
			b:           u256.NewUint(100),
			expected:    u256.Zero(),
			description: "Min of zero and non-zero should be zero",
		},
		{
			name:        "second zero",
			a:           u256.NewUint(100),
			b:           u256.Zero(),
			expected:    u256.Zero(),
			description: "Min of non-zero and zero should be zero",
		},
		{
			name:        "equal values",
			a:           u256.NewUint(1000),
			b:           u256.NewUint(1000),
			expected:    u256.NewUint(1000),
			description: "Min of equal values should return that value",
		},
		{
			name:        "first smaller",
			a:           u256.NewUint(500),
			b:           u256.NewUint(1000),
			expected:    u256.NewUint(500),
			description: "Min should return first when it's smaller",
		},
		{
			name:        "second smaller",
			a:           u256.NewUint(1000),
			b:           u256.NewUint(500),
			expected:    u256.NewUint(500),
			description: "Min should return second when it's smaller",
		},
		{
			name:        "one unit difference",
			a:           u256.NewUint(1000),
			b:           u256.NewUint(1001),
			expected:    u256.NewUint(1000),
			description: "Should correctly handle one unit difference",
		},
		{
			name:        "max uint128 vs smaller",
			a:           u256.MustFromDecimal(MAX_UINT128),
			b:           u256.NewUint(1000),
			expected:    u256.NewUint(1000),
			description: "Min of MAX_UINT128 and smaller value should be smaller value",
		},
		{
			name:        "both max uint128",
			a:           u256.MustFromDecimal(MAX_UINT128),
			b:           u256.MustFromDecimal(MAX_UINT128),
			expected:    u256.MustFromDecimal(MAX_UINT128),
			description: "Min of two MAX_UINT128 should be MAX_UINT128",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := u256Min(tt.a, tt.b)
			uassert.Equal(t, tt.expected.ToString(), result.ToString(), tt.description)
		})
	}
}

func TestTicksToString(t *testing.T) {
	type positionSetup struct {
		tickLower int32
		tickUpper int32
		liquidity string
	}

	tests := []struct {
		name                string
		positions           []positionSetup
		startTick           int32
		endTick             int32
		expectedResult      string
		expectedContains    []string
		expectedNotContains []string
		expectedMinLength   int
		expectedTickCount   int
	}{
		{
			name:           "no ticks in range",
			positions:      []positionSetup{},
			startTick:      100,
			endTick:        200,
			expectedResult: "[]",
		},
		{
			name:           "non-existent ticks in range",
			positions:      []positionSetup{},
			startTick:      100,
			endTick:        200,
			expectedResult: "[]",
		},
		{
			name: "single tick with shortened field names",
			positions: []positionSetup{
				{tickLower: -10, tickUpper: 10, liquidity: "1000000"},
			},
			startTick:         -10,
			endTick:           -10,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":`, `"lg":`, `"ln":`, `"fg0":`, `"fg1":`,
				`"tco":`, `"spl":`, `"so":`, `"i":`,
			},
			expectedNotContains: []string{
				`"tick":`, `"liquidityGross":`, `"liquidityNet":`,
				`"feeGrowthOutside0X128":`, `"feeGrowthOutside1X128":`,
				`"tickCumulativeOutside":`, `"secondsPerLiquidityOutsideX128":`,
				`"secondsOutside":`, `"initialized":`,
			},
		},
		{
			name: "multiple ticks in range",
			positions: []positionSetup{
				{tickLower: -100, tickUpper: 100, liquidity: "1000000"},
			},
			startTick:         -100,
			endTick:           100,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":-100`, `"t":100`,
			},
			expectedTickCount: 2,
		},
		{
			name: "range with only initialized ticks",
			positions: []positionSetup{
				{tickLower: -50, tickUpper: 50, liquidity: "1000000"},
			},
			startTick:         -50,
			endTick:           100,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":-50`, `"t":50`,
			},
			expectedNotContains: []string{
				`"t":0`, `"t":100`,
			},
		},
		{
			name: "multiple positions with overlapping ticks",
			positions: []positionSetup{
				{tickLower: -100, tickUpper: 0, liquidity: "500000"},
				{tickLower: 0, tickUpper: 100, liquidity: "750000"},
			},
			startTick:         -100,
			endTick:           100,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":-100`, `"t":0`, `"t":100`,
			},
			expectedTickCount: 3,
		},
		{
			name: "reversed range (endTick < startTick)",
			positions: []positionSetup{
				{tickLower: -100, tickUpper: 100, liquidity: "1000000"},
			},
			startTick:         100,
			endTick:           -100,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":-100`, `"t":100`,
			},
			expectedTickCount: 2,
		},
		{
			name: "positive ticks only - string ordering problem",
			positions: []positionSetup{
				{tickLower: 0, tickUpper: 10, liquidity: "1000000"},
				{tickLower: 10, tickUpper: 20, liquidity: "1000000"},
				{tickLower: 20, tickUpper: 30, liquidity: "1000000"},
				{tickLower: 90, tickUpper: 100, liquidity: "1000000"},
			},
			startTick:         0,
			endTick:           100,
			expectedMinLength: 3,
			expectedContains: []string{
				`"t":0`, `"t":10`, `"t":20`, `"t":30`, `"t":90`, `"t":100`,
			},
			expectedTickCount: 6,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPoolTest(t)
			tickSpacing := getMockInstance().GetFeeAmountTickSpacing(fee500)
			poolParams := newPoolParams(fooPath, barPath, fee500, "79228162514264337593543950336", tickSpacing, 0)
			pool := newPool(poolParams)

			// Setup positions
			for _, pos := range tt.positions {
				params := ModifyPositionParams{
					owner:          addr01,
					tickLower:      pos.tickLower,
					tickUpper:      pos.tickUpper,
					liquidityDelta: i256.MustFromDecimal(pos.liquidity),
				}
				_, _, _, err := modifyPosition(pool, params)
				if err != nil {
					t.Fatalf("Failed to create position: %v", err)
				}
			}

			result := ticksToString(pool, tt.startTick, tt.endTick)

			// Exact match assertion
			if tt.expectedResult != "" {
				uassert.Equal(t, tt.expectedResult, result)
				return
			}

			// Minimum length assertion
			if tt.expectedMinLength > 0 {
				uassert.True(t, len(result) >= tt.expectedMinLength,
					ufmt.Sprintf("result length %d should be >= %d", len(result), tt.expectedMinLength))
			}

			// Contains assertions
			for _, substr := range tt.expectedContains {
				uassert.True(t, strings.Contains(result, substr),
					ufmt.Sprintf("result should contain '%s'", substr))
			}

			// Not contains assertions
			for _, substr := range tt.expectedNotContains {
				uassert.False(t, strings.Contains(result, substr),
					ufmt.Sprintf("result should not contain '%s'", substr))
			}

			// Tick count assertion
			if tt.expectedTickCount > 0 {
				actualCount := strings.Count(result, `"t":`)
				uassert.Equal(t, tt.expectedTickCount, actualCount,
					ufmt.Sprintf("expected %d ticks, got %d", tt.expectedTickCount, actualCount))
			}
		})
	}
}

func TestIterateTicksBoundary(t *testing.T) {
	tests := []struct {
		name          string
		setupTicks    []int32
		startTick     int32
		endTick       int32
		expectedTicks []int32
		description   string
	}{
		{
			name:          "single tick - startTick equals endTick",
			setupTicks:    []int32{-100, 0, 100},
			startTick:     0,
			endTick:       0,
			expectedTicks: []int32{0},
			description:   "When startTick == endTick, should return only that tick",
		},
		{
			name:          "endTick is inclusive",
			setupTicks:    []int32{0, 10, 20, 30},
			startTick:     0,
			endTick:       20,
			expectedTicks: []int32{0, 10, 20},
			description:   "endTick should be included in the result",
		},
		{
			name:          "startTick is inclusive",
			setupTicks:    []int32{0, 10, 20, 30},
			startTick:     10,
			endTick:       30,
			expectedTicks: []int32{10, 20, 30},
			description:   "startTick should be included in the result",
		},
		{
			name:          "no ticks in range",
			setupTicks:    []int32{-100, 100},
			startTick:     -50,
			endTick:       50,
			expectedTicks: []int32{},
			description:   "Range with no ticks should return empty",
		},
		{
			name:          "startTick greater than endTick",
			setupTicks:    []int32{0, 10, 20},
			startTick:     20,
			endTick:       0,
			expectedTicks: []int32{},
			description:   "Reversed range should return empty (not swap)",
		},
		{
			name:          "negative ticks range",
			setupTicks:    []int32{-100, -50, -20, -10},
			startTick:     -100,
			endTick:       -10,
			expectedTicks: []int32{-100, -50, -20, -10},
			description:   "Negative ticks should be in numeric order",
		},
		{
			name:          "across zero boundary",
			setupTicks:    []int32{-20, -10, 0, 10, 20},
			startTick:     -10,
			endTick:       10,
			expectedTicks: []int32{-10, 0, 10},
			description:   "Range crossing zero should work correctly",
		},
		{
			name:          "MIN_TICK boundary",
			setupTicks:    []int32{-887270, -887260, -887250},
			startTick:     -887270,
			endTick:       -887250,
			expectedTicks: []int32{-887270, -887260, -887250},
			description:   "Should handle MIN_TICK region correctly",
		},
		{
			name:          "MAX_TICK boundary",
			setupTicks:    []int32{887250, 887260, 887270},
			startTick:     887250,
			endTick:       887270,
			expectedTicks: []int32{887250, 887260, 887270},
			description:   "Should handle MAX_TICK region correctly (inclusive)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPoolTest(t)
			tickSpacing := getMockInstance().GetFeeAmountTickSpacing(fee500)
			poolParams := newPoolParams(fooPath, barPath, fee500, "79228162514264337593543950336", tickSpacing, 0)
			pool := newPool(poolParams)

			// Setup ticks by creating positions
			for i, tick := range tt.setupTicks {
				var tickLower, tickUpper int32
				if i < len(tt.setupTicks)-1 {
					tickLower = tick
					tickUpper = tt.setupTicks[i+1]
				} else {
					// Last tick: create a small range
					tickLower = tick - tickSpacing
					tickUpper = tick
				}

				params := ModifyPositionParams{
					owner:          addr01,
					tickLower:      tickLower,
					tickUpper:      tickUpper,
					liquidityDelta: i256.MustFromDecimal("1000000"),
				}
				_, _, _, err := modifyPosition(pool, params)
				if err != nil {
					t.Logf("Warning: Failed to create position for tick %d: %v", tick, err)
				}
			}

			// Iterate ticks
			actualTicks := []int32{}
			pool.IterateTicks(tt.startTick, tt.endTick, func(tick int32, _ pl.TickInfo) bool {
				actualTicks = append(actualTicks, tick)
				return false
			})

			// Verify results
			if len(tt.expectedTicks) != len(actualTicks) {
				t.Errorf("%s\nExpected %d ticks: %v\nGot %d ticks: %v",
					tt.description,
					len(tt.expectedTicks), tt.expectedTicks,
					len(actualTicks), actualTicks)
				return
			}

			for i, expectedTick := range tt.expectedTicks {
				if actualTicks[i] != expectedTick {
					t.Errorf("%s\nAt index %d: expected tick %d, got %d",
						tt.description, i, expectedTick, actualTicks[i])
				}
			}

			t.Logf("✓ %s", tt.description)
			t.Logf("  Range: [%d, %d], Result: %v", tt.startTick, tt.endTick, actualTicks)
		})
	}
}
