package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
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
			num1:     consts.MAX_UINT256,
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
			num2:     consts.MAX_UINT256,
			expected: "115792089237316195423570985008687907853269984665640564039457584007913129639934",
		},
		{
			name:     "large values (num2 smaller)",
			num1:     consts.MAX_UINT256,
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

func TestGetPrevAsString(t *testing.T) {
	tests := []struct {
		name            string
		_realm          std.Realm
		expectedAddr    string
		expectedPkgPath string
	}{
		{
			name:            "user call",
			_realm:          std.NewUserRealm(std.Address("user")),
			expectedAddr:    "user",
			expectedPkgPath: "",
		},
		{
			name:            "code call",
			_realm:          std.NewCodeRealm("gno.land/r/demo/realm"),
			expectedAddr:    std.DerivePkgAddr("gno.land/r/demo/realm").String(),
			expectedPkgPath: "gno.land/r/demo/realm",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(tt._realm)
			func() {
				testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
				addr, pkgPath := getPrevAsString()
				uassert.Equal(t, tt.expectedAddr, addr)
				uassert.Equal(t, tt.expectedPkgPath, pkgPath)
			}()
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
		{"normal conversion - small", u256.NewUint(123), 123, false, ""},
		{"normal conversion - medium", u256.NewUint(1000000), 1000000, false, ""},
		{"zero", u256.NewUint(0), 0, false, ""},
		
		// Boundary cases
		{"max uint64 - 2", u256.NewUint(18446744073709551613), 18446744073709551613, false, ""},
		{"max uint64 - 1", u256.NewUint(18446744073709551614), 18446744073709551614, false, ""},
		{"max uint64", u256.NewUint(1<<64 - 1), 1<<64 - 1, false, ""},
		
		// Overflow cases
		{"overflow - max uint64 + 1", u256.MustFromDecimal("18446744073709551616"), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(18446744073709551616) overflows uint64 range (max 18446744073709551615)"},
		{"overflow - large value", u256.MustFromDecimal(consts.MAX_UINT128), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(340282366920938463463374607431768211455) overflows uint64 range (max 18446744073709551615)"},
		{"overflow - very large value", u256.MustFromDecimal(consts.MAX_UINT256), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(115792089237316195423570985008687907853269984665640564039457584007913129639935) overflows uint64 range (max 18446744073709551615)"},
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

			res := safeConvertToUint64(tt.value)
			if res != tt.wantRes {
				t.Errorf("safeConvertToUint64() = %v, want %v", res, tt.wantRes)
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
		{"max int64 + 1 (overflow)", u256.NewUint(9223372036854775808), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(9223372036854775808) overflows int64 range (max 9223372036854775807)"},
		
		// Mid-range boundaries
		{"2^32", u256.NewUint(4294967296), 4294967296, false, ""},
		{"2^48", u256.NewUint(281474976710656), 281474976710656, false, ""},
		
		// Values between max int64 and max uint64
		{"value between max int64 and max uint64 (1)", u256.NewUint(10000000000000000000), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(10000000000000000000) overflows int64 range (max 9223372036854775807)"},
		{"value between max int64 and max uint64 (2)", u256.NewUint(15000000000000000000), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(15000000000000000000) overflows int64 range (max 9223372036854775807)"},
		
		// Extreme cases - these will fail on uint64 conversion first
		{"max uint64 + 1 (overflow)", u256.MustFromDecimal("18446744073709551616"), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(18446744073709551616) overflows uint64 range (max 18446744073709551615)"},
		{"very large number (MAX_UINT128)", u256.MustFromDecimal(consts.MAX_UINT128), 0, true, "[GNOSWAP-POOL-005] out of range for numeric value: amount(340282366920938463463374607431768211455) overflows uint64 range (max 18446744073709551615)"},
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
		{"2^64", consts.Q64, consts.Q64, false, ""},
		{"2^96", consts.Q96, consts.Q96, false, ""},
		
		// Boundary cases
		{"close to MAX_INT128", "170141183460469231731687303715884105726", "170141183460469231731687303715884105726", false, ""},
		{"MAX_INT128", consts.MAX_INT128, consts.MAX_INT128, false, ""},
		
		// Overflow cases
		{"just over MAX_INT128", "170141183460469231731687303715884105728", "", true, "[GNOSWAP-POOL-026] overflow: amount(170141183460469231731687303715884105728) overflows int128 range"},
		{"large overflow", consts.MAX_UINT128, "", true, "[GNOSWAP-POOL-026] overflow: amount(340282366920938463463374607431768211455) overflows int128 range"},
		{"extreme overflow", consts.MAX_UINT256, "", true, "[GNOSWAP-POOL-026] overflow: amount(115792089237316195423570985008687907853269984665640564039457584007913129639935) overflows int128 range"},
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

func TestToUint128(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "within range - no change",
			input:    "12345",
			expected: "12345",
		},
		{
			name:     "zero value",
			input:    "0",
			expected: "0",
		},
		{
			name:     "max uint128 - no change",
			input:    consts.MAX_UINT128,
			expected: consts.MAX_UINT128,
		},
		{
			name:     "overflow - should mask to max uint128",
			input:    consts.MAX_UINT256,
			expected: consts.MAX_UINT128,
		},
		{
			name:     "overflow - just over max uint128",
			input:    "340282366920938463463374607431768211456", // MAX_UINT128 + 1
			expected: "0", // Should wrap to 0 due to masking
		},
		// Additional masking tests
		{
			name:     "exactly 2^128 wraps to 0",
			input:    "340282366920938463463374607431768211456", // 2^128
			expected: "0",
		},
		{
			name:     "2^128 + 1 wraps to 1",
			input:    "340282366920938463463374607431768211457",
			expected: "1",
		},
		{
			name:     "2^129 wraps to 0",
			input:    "680564733841876926926749214863536422912", // 2^129
			expected: "0",
		},
		{
			name:     "q96 value",
			input:    consts.Q96,
			expected: consts.Q96,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			original := u256.MustFromDecimal(tt.input)
			originalStr := original.ToString()
			
			result := toUint128(original)
			
			// Verify result
			uassert.Equal(t, tt.expected, result.ToString())
			
			// Verify input wasn't mutated
			uassert.Equal(t, originalStr, original.ToString())
		})
	}
}

func TestToUint128NilPanic(t *testing.T) {
	defer func() {
		if r := recover(); r != nil {
			expected := "[GNOSWAP-POOL-006] invalid input data || value is nil"
			if r != expected {
				t.Errorf("expected panic message %v, got %v", expected, r)
			}
		} else {
			t.Errorf("expected panic, but none occurred")
		}
	}()
	
	toUint128(nil)
}

func TestToUint128InputPreservation(t *testing.T) {
	// Test that input is never modified, especially in overflow cases
	t.Run("overflow case - input preservation", func(t *testing.T) {
		original := u256.MustFromDecimal(consts.MAX_UINT256)
		originalStr := original.ToString()
		
		result := toUint128(original)
		
		// Original should be unchanged
		uassert.Equal(t, originalStr, original.ToString())
		// Result should be masked
		uassert.Equal(t, consts.MAX_UINT128, result.ToString())
		// Result and original should be different instances
		uassert.False(t, result == original)
	})
	
	t.Run("within range case - input preservation", func(t *testing.T) {
		original := u256.NewUint(1000)
		originalStr := original.ToString()
		
		result := toUint128(original)
		
		// Original should be unchanged
		uassert.Equal(t, originalStr, original.ToString())
		// Result should be same as original
		uassert.Equal(t, originalStr, result.ToString())
		// But should be the same instance since no modification needed
		uassert.True(t, result == original)
	})
}

func TestAssertOnlyNotNil(t *testing.T) {
	tests := []struct {
		name        string
		input       *u256.Uint
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "nil input",
			input:       nil,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-006] invalid input data || value is nil",
		},
		{
			name:        "valid zero",
			input:       u256.NewUint(0),
			shouldPanic: false,
		},
		{
			name:        "valid non-zero",
			input:       u256.NewUint(123),
			shouldPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					assertOnlyNotNil(tt.input)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertOnlyNotNil(tt.input)
				})
			}
		})
	}
}

func TestDerivePkgAddr(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Position package path",
			input:    "gno.land/r/gnoswap/v1/position",
			expected: "g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5",
		},
		{
			name:     "Pool package path",
			input:    "gno.land/r/gnoswap/v1/pool",
			expected: "g148tjamj80yyrm309z7rk690an22thd2l3z8ank",
		},
		{
			name:     "Router package path",
			input:    "gno.land/r/gnoswap/v1/router",
			expected: "g1lm2l7tf49h3mykesct7rhfml30yx8dw5xrval7",
		},
		{
			name:     "GNS package path",
			input:    "gno.land/r/gnoswap/v1/gns",
			expected: "g1jgqwaa2le3yr63d533fj785qkjspumzv22ys5m",
		},
		{
			name:     "Empty package path",
			input:    "",
			expected: "g1dqzh5qknkx0kasfkwvx0qfcztcgdmwl3p0hzzr",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := derivePkgAddr(tc.input)
			uassert.Equal(t, tc.expected, got.String())
		})
	}
}

func TestCheckOverFlowInt128(t *testing.T) {
	tests := []struct {
		name        string
		input       *i256.Int
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "Valid value within int128 range",
			input:       i256.MustFromDecimal("1"),
			shouldPanic: false,
		},
		{
			name:        "Edge case - MAX_INT128",
			input:       i256.MustFromDecimal(consts.MAX_INT128),
			shouldPanic: false,
		},
		{
			name:        "Overflow case - exceeds MAX_INT128",
			input:       i256.MustFromDecimal("170141183460469231731687303715884105728"), // MAX_INT128 + 1
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-026] overflow: amount(170141183460469231731687303715884105728) overflows int128 range",
		},
		// Test negative values - they should NOT panic since they're within int128 range
		{
			name:        "negative small value",
			input:       i256.MustFromDecimal("-1"),
			shouldPanic: false,
		},
		{
			name:        "negative large value",
			input:       i256.MustFromDecimal("-170141183460469231731687303715884105728"), // -2^127
			shouldPanic: false,
		},
		{
			name:        "very large positive (MAX_INT256)",
			input:       i256.MustFromDecimal(consts.MAX_INT256),
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-026] overflow: amount(57896044618658097711785492504343953926634992332820282019728792003956564819967) overflows int128 range",
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
			checkOverFlowInt128(tt.input)
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
			errorMsg:    "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(15) MOD tickSpacing(10) != 0(5)",
		},
		{
			name:        "Invalid tick - negative tick",
			tick:        -35,
			tickSpacing: 20,
			shouldPanic: true,
			errorMsg:    "[GNOSWAP-POOL-022] invalid tick and tick spacing requested || tick(-35) MOD tickSpacing(20) != 0(-15)",
		},
		// Edge cases with extreme tick values
		{
			name:        "min tick boundary",
			tick:        consts.MIN_TICK, // -887272
			tickSpacing: 1,
			shouldPanic: false,
		},
		{
			name:        "max tick boundary", 
			tick:        consts.MAX_TICK, // 887272
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

func TestAssertOnlyValidAddress(t *testing.T) {
	tests := []struct {
		name     string
		addr     std.Address
		expected bool
		errorMsg string
	}{
		{
			name:     "Success - valid address",
			addr:     "g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d", // ADMIN address from consts
			expected: true,
		},
		{
			name:     "Failure - invalid address",
			addr:     "g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8", // invalid length
			expected: false,
			errorMsg: "[GNOSWAP-POOL-023] invalid address || (g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8)",
		},
		{
			name:     "Failure - empty address",
			addr:     "",
			expected: false,
			errorMsg: "[GNOSWAP-POOL-023] invalid address || ()",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expected {
				uassert.NotPanics(t, func() {
					assertOnlyValidAddress(tc.addr)
				})
			} else {
				uassert.PanicsWithMessage(t, tc.errorMsg, func() {
					assertOnlyValidAddress(tc.addr)
				})
			}
		})
	}
}

func TestPermissionFunctions(t *testing.T) {
	t.Run("user realm detection", func(t *testing.T) {
		testing.SetRealm(std.NewUserRealm(std.Address("user")))
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
			uassert.True(t, isUserCall())
		}()
	})
	
	t.Run("code realm detection", func(t *testing.T) {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/realm"))
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
			uassert.False(t, isUserCall())
		}()
	})
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
		q96 := u256.MustFromDecimal(consts.Q96)
		result := safeConvertToInt128(q96)
		uassert.Equal(t, consts.Q96, result.ToString())
		
		// Q128 should also work
		q128Val := u256.MustFromDecimal(consts.Q128)
		result2 := safeConvertToInt128(q128Val)
		uassert.Equal(t, consts.Q128, result2.ToString())
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
			{"uint8", uint8(255), "255", false, ""},
			{"uint32", uint32(4294967295), "4294967295", false, ""},
			{"uint64", uint64(18446744073709551615), "18446744073709551615", false, ""},
			{"uint8 zero", uint8(0), "0", false, ""},
			{"invalid type", "string", "", true, "invalid type: string"},
			{"invalid type int", int(42), "", true, "invalid type: int"},
		}
		
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.panics {
					defer func() {
						if r := recover(); r == nil {
							t.Errorf("expected panic, but none occurred")
						}
					}()
					formatUint(tt.input)
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
			{"int32", int32(-2147483648), "-2147483648", false, ""},
			{"int64", int64(9223372036854775807), "9223372036854775807", false, ""},
			{"int", int(42), "42", false, ""},
			{"int negative", int(-42), "-42", false, ""},
			{"int32 zero", int32(0), "0", false, ""},
			{"invalid type", "string", "", true, "invalid type: string"},
			{"invalid type uint", uint(42), "", true, "invalid type: uint"},
		}
		
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if tt.panics {
					defer func() {
						if r := recover(); r == nil {
							t.Errorf("expected panic, but none occurred")
						}
					}()
					formatInt(tt.input)
				} else {
					result := formatInt(tt.input)
					uassert.Equal(t, tt.expected, result)
				}
			})
		}
	})
	
	t.Run("formatBool", func(t *testing.T) {
		uassert.Equal(t, "true", formatBool(true))
		uassert.Equal(t, "false", formatBool(false))
	})
}

func TestCheckTransferError(t *testing.T) {
	t.Run("no error", func(t *testing.T) {
		uassert.NotPanics(t, func() {
			checkTransferError(nil)
		})
	})
	
	// Since we can't easily create an error in the test without importing errors package,
	// and the actual transfer errors would come from token transfer operations,
	// we'll skip the error case test or test it differently in integration tests
}

func TestRealm(t *testing.T) {
	t.Run("getPrevRealm", func(t *testing.T) {
		testing.SetRealm(std.NewUserRealm(std.Address("test_user")))
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
			r := getPrevRealm()
			uassert.True(t, r.IsUser())
			uassert.Equal(t, "test_user", r.Address().String())
		}()
	})
	
	t.Run("getPrevAddr", func(t *testing.T) {
		testing.SetRealm(std.NewUserRealm(std.Address("test_user2")))
		func() {
			testing.SetRealm(std.NewCodeRealm("gno.land/r/demo/tests"))
			addr := getPrevAddr()
			uassert.Equal(t, "test_user2", addr.String())
		}()
	})
}