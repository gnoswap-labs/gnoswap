package v1

import (
	"testing"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/uassert"

	u256 "gno.land/p/gnoswap/uint256"
)

func assertPanic(t *testing.T, expectedMsg string, fn func()) {
	t.Helper()
	defer func() {
		r := recover()
		if r == nil {
			t.Errorf("expected panic but got none")
		} else if r != expectedMsg {
			t.Errorf("expected panic %v, got %v", expectedMsg, r)
		}
	}()
	fn()
}

func TestAssertValidNumberString(t *testing.T) {
	tests := []struct {
		name                 string
		input                string
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		// Valid Cases
		{
			name:                 "assertValidNumberString is success by valid positive number",
			input:                "12345",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "assertValidNumberString is success by valid negative number",
			input:                "-98765",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "assertValidNumberString is success by zero",
			input:                "0",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},
		{
			name:                 "assertValidNumberString is success by negative zero",
			input:                "-0",
			expectedHasPanic:     false,
			expectedPanicMessage: "",
		},

		// Invalid Cases
		{
			name:                 "assertValidNumberString is failed by empty string",
			input:                "",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input is empty",
		},
		{
			name:                 "assertValidNumberString is failed by alphabet in string",
			input:                "12a45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input string : 12a45",
		},
		{
			name:                 "assertValidNumberString is failed by special characters",
			input:                "123@45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input string : 123@45",
		},
		{
			name:                 "assertValidNumberString is failed by leading plus sign",
			input:                "+12345",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input string : +12345",
		},
		{
			name:                 "assertValidNumberString is failed by multiple negative signs",
			input:                "--12345",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input string : --12345",
		},
		{
			name:                 "assertValidNumberString is failed by space in string",
			input:                "123 45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-005] invalid input data || input string : 123 45",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			initPositionTest(t)

			if tt.expectedHasPanic {
				uassert.PanicsWithMessage(t, tt.expectedPanicMessage, func() {
					assertValidNumberString(tt.input)
				})
			} else {
				assertValidNumberString(tt.input)
				uassert.Equal(t, true, true)
			}
		})
	}
}

func TestPositionIdFrom(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
	}{
		{
			name:        "positionIdFrom is failed by nil",
			input:       nil,
			expected:    "[GNOSWAP-POSITION-005] invalid input data || positionId is nil",
			shouldPanic: true,
		},
		{
			name:        "positionIdFrom is failed by unsupported type",
			input:       float64(1),
			expected:    "[GNOSWAP-POSITION-005] invalid input data || unsupported positionId type",
			shouldPanic: true,
		},
		{
			name:        "positionIdFrom is success by string",
			input:       "1",
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "positionIdFrom is success by int",
			input:       int(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "positionIdFrom is success by uint64",
			input:       uint64(1),
			expected:    "1",
			shouldPanic: false,
		},
		{
			name:        "positionIdFrom is success by grc721.TokenID",
			input:       grc721.TokenID("1"),
			expected:    "1",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			defer func() {
				r := recover()
				if r == nil {
					if tc.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tc.name)
						return
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
						}
					case error:
						if r.(error).Error() != tc.expected {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expected)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expected)
					}
				}
			}()

			if !tc.shouldPanic {
				got := positionIdFrom(tc.input)
				uassert.Equal(t, tc.expected, string(got))
			} else {
				positionIdFrom(tc.input)
			}
		})
	}
}

func TestIsOwner(t *testing.T) {
	tests := []struct {
		name       string
		positionId uint64
		addr       address
		expected   bool
	}{
		{
			name:       "is owner is success by owner is admin",
			positionId: 1,
			addr:       adminAddr,
			expected:   true,
		},
		{
			name:       "is owner is failed by is not owner",
			positionId: 1,
			addr:       alice,
			expected:   false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			testing.SetRealm(posRealm)
			mockInstance.nftAccessor.Mint(adminAddr, positionIdFrom(tc.positionId))

			got := mockInstance.isOwner(tc.positionId, tc.addr)

			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOperator(t *testing.T) {
	tests := []struct {
		name       string
		positionId uint64
		addr       address
		expected   bool
	}{
		{
			name:       "is operator is success by is operator",
			positionId: 1,
			addr:       alice,
			expected:   true,
		},
		{
			name:       "is operator is failed by is not operator",
			positionId: 1,
			addr:       bob,
			expected:   false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			// given
			position := newDummyPosition(tc.positionId)
			position.SetOperator(alice)
			mockInstance.createNewPosition(tc.positionId, position)

			// when
			got := mockInstance.isOperator(tc.positionId, tc.addr)

			// then
			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestPoolKeyDivide(t *testing.T) {
	tests := []struct {
		name          string
		poolKey       string
		expectedPath0 string
		expectedPath1 string
		expectedFee   uint32
		expectedError string
		shouldPanic   bool
	}{
		{
			name:          "pool key divide is success by valid poolKey",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
			expectedPath0: gnsPath,
			expectedPath1: wugnotPath,
			expectedFee:   fee500,
			shouldPanic:   false,
		},
		{
			name:          "pool key divide is failed by invalid poolKey",
			poolKey:       "gno.land/r/onbloc",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey(gno.land/r/onbloc)",
			shouldPanic:   true,
		},
		{
			name:          "pool key divide is failed by empty poolKey",
			poolKey:       "",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey()",
			shouldPanic:   true,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			defer func() {
				r := recover()
				if r == nil {
					if tc.shouldPanic {
						t.Errorf(">>> %s: expected panic but got none", tc.name)
						return
					}
				} else {
					switch r.(type) {
					case string:
						if r.(string) != tc.expectedError {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expectedError)
						}
					case error:
						if r.(error).Error() != tc.expectedError {
							t.Errorf(">>> %s: got panic %v, want %v", tc.name, r.(error).Error(), tc.expectedError)
						}
					default:
						t.Errorf(">>> %s: got panic %v, want %v", tc.name, r, tc.expectedError)
					}
				}
			}()

			if !tc.shouldPanic {
				gotToken0, gotToken1, gotFee := splitOf(tc.poolKey)
				uassert.Equal(t, tc.expectedPath0, gotToken0)
				uassert.Equal(t, tc.expectedPath1, gotToken1)
				uassert.Equal(t, tc.expectedFee, gotFee)
			} else {
				splitOf(tc.poolKey)
			}
		})
	}
}

func TestSplitOf(t *testing.T) {
	tests := []struct {
		name          string
		poolKey       string
		expectedPath0 string
		expectedPath1 string
		expectedFee   uint32
		expectedError string
		shouldPanic   bool
	}{
		{
			name:          "split of is failed by empty poolKey",
			poolKey:       "",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey()",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by invalid delimiter",
			poolKey:       "gno.land/r/gnoswap:v1/gns:gno.land/r/gnoland/wugnot-500",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(gno.land/r/gnoland/wugnot-500)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by non-numeric fee",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:fee",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(fee)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by missing fee part",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee()",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by insufficient parts",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/demo",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey(gno.land/r/gnoswap/gns:gno.land/r/demo)",
			shouldPanic:   true,
		},
		{
			name:          "split of is success by valid poolKey",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:500",
			expectedPath0: "gno.land/r/gnoswap/gns",
			expectedPath1: "gno.land/r/gnoland/wugnot",
			expectedFee:   500,
			shouldPanic:   false,
		},
		{
			name:          "split of is success by poolKey with large fee",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:10000",
			expectedPath0: "gno.land/r/gnoswap/gns",
			expectedPath1: "gno.land/r/gnoland/wugnot",
			expectedFee:   10000,
			shouldPanic:   false,
		},
		{
			name:          "split of is success by poolKey with minimal fee",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:1",
			expectedPath0: "gno.land/r/gnoswap/gns",
			expectedPath1: "gno.land/r/gnoland/wugnot",
			expectedFee:   1,
			shouldPanic:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.shouldPanic {
				assertPanic(t, tc.expectedError, func() {
					splitOf(tc.poolKey)
				})
			} else {
				gotToken0, gotToken1, gotFee := splitOf(tc.poolKey)
				uassert.Equal(t, tc.expectedPath0, gotToken0, "Token0 mismatch")
				uassert.Equal(t, tc.expectedPath1, gotToken1, "Token1 mismatch")
				uassert.Equal(t, tc.expectedFee, gotFee, "Fee mismatch")
			}
		})
	}
}

func TestSubUint256(t *testing.T) {
	tests := []struct {
		name     string
		x        *u256.Uint
		y        *u256.Uint
		expected *u256.Uint
	}{
		{
			name:     "Normal case: x > y",
			x:        u256.NewUint(100),
			y:        u256.NewUint(50),
			expected: u256.NewUint(50),
		},
		{
			name:     "Equality case: x == y",
			x:        u256.NewUint(100),
			y:        u256.NewUint(100),
			expected: u256.NewUint(0),
		},
		{
			name: "Underflow case: x < y",
			x:    u256.NewUint(50),
			y:    u256.NewUint(100),
			expected: func() *u256.Uint {
				// 2^256 - 1 - 100 + 50 = 2^256 - 51
				max := u256.MustFromDecimal(MAX_UINT256)
				diff := u256.Zero().Sub(max, u256.NewUint(100))
				result := u256.Zero().Add(diff, u256.NewUint(50))
				return u256.Zero().Add(result, u256.One())
			}(),
		},
		{
			name:     "y = 0",
			x:        u256.NewUint(100),
			y:        u256.NewUint(0),
			expected: u256.NewUint(100),
		},
		{
			name: "x = 0, y > 0",
			x:    u256.NewUint(0),
			y:    u256.NewUint(100),
			expected: func() *u256.Uint {
				// 2^256 - 1 - 100 + 0 = 2^256 - 101 + 1
				max := u256.MustFromDecimal(MAX_UINT256)
				diff := u256.Zero().Sub(max, u256.NewUint(100))
				result := u256.Zero().Add(diff, u256.One())
				return result
			}(),
		},
		{
			name:     "Large numbers: normal subtraction",
			x:        u256.MustFromDecimal("1000000000000000000000"),
			y:        u256.MustFromDecimal("500000000000000000000"),
			expected: u256.MustFromDecimal("500000000000000000000"),
		},
		{
			name: "Large numbers: underflow",
			x:    u256.MustFromDecimal("500000000000000000000"),
			y:    u256.MustFromDecimal("1000000000000000000000"),
			expected: func() *u256.Uint {
				// 2^256 - 1 - 1000000000000000000000 + 500000000000000000000 + 1
				max := u256.MustFromDecimal(MAX_UINT256)
				diff := u256.Zero().Sub(max, u256.MustFromDecimal("1000000000000000000000"))
				result := u256.Zero().Add(diff, u256.MustFromDecimal("500000000000000000000"))
				return u256.Zero().Add(result, u256.One())
			}(),
		},
		{
			name: "Underflow: 0 - 1 (most basic off-by-one check)",
			x:    u256.NewUint(0),
			y:    u256.NewUint(1),
			expected: func() *u256.Uint {
				// 0 - 1 = -1 mod 2^256 = 2^256 - 1
				return u256.Zero().Sub(u256.NewUint(0), u256.NewUint(1))
			}(),
		},
		{
			name: "Underflow: direct comparison with u256.Sub",
			x:    u256.NewUint(50),
			y:    u256.NewUint(100),
			expected: func() *u256.Uint {
				return u256.Zero().Sub(u256.NewUint(50), u256.NewUint(100))
			}(),
		},
		{
			name: "Verify off-by-one: 10 - 11",
			x:    u256.NewUint(10),
			y:    u256.NewUint(11),
			expected: func() *u256.Uint {
				return u256.Zero().Sub(u256.NewUint(10), u256.NewUint(11))
			}(),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := subUint256(tt.x, tt.y)
			uassert.Equal(t, tt.expected.ToString(), result.ToString(),
				"subUint256(%s, %s) should equal %s",
				tt.x.ToString(), tt.y.ToString(), tt.expected.ToString())
		})
	}
}

// TestFormatUint tests formatUint function with edge cases
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "uint8 zero",
			input:       uint8(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint8 max",
			input:       uint8(255),
			expected:    "255",
			shouldPanic: false,
		},
		{
			name:        "uint32 zero",
			input:       uint32(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint32 max",
			input:       uint32(4294967295),
			expected:    "4294967295",
			shouldPanic: false,
		},
		{
			name:        "uint64 zero",
			input:       uint64(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "uint64 max",
			input:       uint64(18446744073709551615),
			expected:    "18446744073709551615",
			shouldPanic: false,
		},
		{
			name:        "invalid type int",
			input:       int(123),
			shouldPanic: true,
			errorMsg:    "invalid type: int",
		},
		{
			name:        "invalid type string",
			input:       "123",
			shouldPanic: true,
			errorMsg:    "invalid type: string",
		},
		{
			name:        "invalid type float64",
			input:       float64(3.14),
			shouldPanic: true,
			errorMsg:    "invalid type: unknown",
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

// TestFormatInt tests formatInt function with edge cases
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name        string
		input       any
		expected    string
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "int zero",
			input:       int(0),
			expected:    "0",
			shouldPanic: false,
		},
		{
			name:        "int positive",
			input:       int(123),
			expected:    "123",
			shouldPanic: false,
		},
		{
			name:        "int negative",
			input:       int(-123),
			expected:    "-123",
			shouldPanic: false,
		},
		{
			name:        "int32 min",
			input:       int32(-2147483648),
			expected:    "-2147483648",
			shouldPanic: false,
		},
		{
			name:        "int32 max",
			input:       int32(2147483647),
			expected:    "2147483647",
			shouldPanic: false,
		},
		{
			name:        "int64 min",
			input:       int64(-9223372036854775808),
			expected:    "-9223372036854775808",
			shouldPanic: false,
		},
		{
			name:        "int64 max",
			input:       int64(9223372036854775807),
			expected:    "9223372036854775807",
			shouldPanic: false,
		},
		{
			name:        "invalid type uint",
			input:       uint(123),
			shouldPanic: true,
			errorMsg:    "invalid type: uint",
		},
		{
			name:        "invalid type string",
			input:       "123",
			shouldPanic: true,
			errorMsg:    "invalid type: string",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					formatInt(tt.input)
				})
			} else {
				result := formatInt(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestFormatBool tests formatBool function
func TestFormatBool(t *testing.T) {
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
}

// TestMustParseInt64 tests mustParseInt64 function with edge cases
func TestMustParseInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    int64
		shouldPanic bool
	}{
		{
			name:        "zero",
			input:       "0",
			expected:    0,
			shouldPanic: false,
		},
		{
			name:        "positive number",
			input:       "12345",
			expected:    12345,
			shouldPanic: false,
		},
		{
			name:        "negative number",
			input:       "-12345",
			expected:    -12345,
			shouldPanic: false,
		},
		{
			name:        "max int64",
			input:       "9223372036854775807",
			expected:    9223372036854775807,
			shouldPanic: false,
		},
		{
			name:        "min int64",
			input:       "-9223372036854775808",
			expected:    -9223372036854775808,
			shouldPanic: false,
		},
		{
			name:        "invalid - empty string",
			input:       "",
			shouldPanic: true,
		},
		{
			name:        "invalid - non-numeric",
			input:       "abc",
			shouldPanic: true,
		},
		{
			name:        "invalid - overflow",
			input:       "9223372036854775808",
			shouldPanic: true,
		},
		{
			name:        "invalid - underflow",
			input:       "-9223372036854775809",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Error("Expected panic but got none")
					}
				}()
				mustParseInt64(tt.input)
			} else {
				result := mustParseInt64(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestSafeConvertToInt64 tests safeConvertToInt64 function with edge cases
func TestSafeConvertToInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       *u256.Uint
		expected    int64
		shouldPanic bool
		errorMsg    string
	}{
		{
			name:        "zero",
			input:       u256.Zero(),
			expected:    0,
			shouldPanic: false,
		},
		{
			name:        "one",
			input:       u256.One(),
			expected:    1,
			shouldPanic: false,
		},
		{
			name:        "max int64",
			input:       u256.MustFromDecimal("9223372036854775807"),
			expected:    9223372036854775807,
			shouldPanic: false,
		},
		{
			name:        "max int64 + 1 (overflow)",
			input:       u256.MustFromDecimal("9223372036854775808"),
			shouldPanic: true,
			errorMsg:    "amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:        "large value (overflow)",
			input:       u256.MustFromDecimal("18446744073709551615"),
			shouldPanic: true,
		},
		{
			name:        "very large value",
			input:       u256.MustFromDecimal("999999999999999999999999"),
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					r := recover()
					if r == nil {
						t.Error("Expected panic but got none")
					}
					if tt.errorMsg != "" {
						if str, ok := r.(string); ok {
							uassert.Equal(t, tt.errorMsg, str)
						}
					}
				}()
				safeConvertToInt64(tt.input)
			} else {
				result := safeConvertToInt64(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestIsSlippageExceeded tests isSlippageExceeded function
func TestIsSlippageExceeded(t *testing.T) {
	tests := []struct {
		name       string
		amount0    *u256.Uint
		amount1    *u256.Uint
		amount0Min *u256.Uint
		amount1Min *u256.Uint
		expected   bool
	}{
		{
			name:       "no slippage - exact match",
			amount0:    u256.NewUint(100),
			amount1:    u256.NewUint(200),
			amount0Min: u256.NewUint(100),
			amount1Min: u256.NewUint(200),
			expected:   false,
		},
		{
			name:       "no slippage - amounts exceed minimums",
			amount0:    u256.NewUint(150),
			amount1:    u256.NewUint(250),
			amount0Min: u256.NewUint(100),
			amount1Min: u256.NewUint(200),
			expected:   false,
		},
		{
			name:       "slippage - amount0 below minimum",
			amount0:    u256.NewUint(90),
			amount1:    u256.NewUint(200),
			amount0Min: u256.NewUint(100),
			amount1Min: u256.NewUint(200),
			expected:   true,
		},
		{
			name:       "slippage - amount1 below minimum",
			amount0:    u256.NewUint(100),
			amount1:    u256.NewUint(190),
			amount0Min: u256.NewUint(100),
			amount1Min: u256.NewUint(200),
			expected:   true,
		},
		{
			name:       "slippage - both below minimum",
			amount0:    u256.NewUint(90),
			amount1:    u256.NewUint(190),
			amount0Min: u256.NewUint(100),
			amount1Min: u256.NewUint(200),
			expected:   true,
		},
		{
			name:       "edge case - zero values",
			amount0:    u256.Zero(),
			amount1:    u256.Zero(),
			amount0Min: u256.Zero(),
			amount1Min: u256.Zero(),
			expected:   false,
		},
		{
			name:       "large numbers - no slippage",
			amount0:    u256.MustFromDecimal("1000000000000000000"),
			amount1:    u256.MustFromDecimal("2000000000000000000"),
			amount0Min: u256.MustFromDecimal("1000000000000000000"),
			amount1Min: u256.MustFromDecimal("2000000000000000000"),
			expected:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isSlippageExceeded(tt.amount0, tt.amount1, tt.amount0Min, tt.amount1Min)
			uassert.Equal(t, tt.expected, result)
		})
	}
}
