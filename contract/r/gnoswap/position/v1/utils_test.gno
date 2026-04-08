package v1

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
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
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input is empty",
		},
		{
			name:                 "assertValidNumberString is failed by alphabet in string",
			input:                "12a45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input string : 12a45",
		},
		{
			name:                 "assertValidNumberString is failed by special characters",
			input:                "123@45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input string : 123@45",
		},
		{
			name:                 "assertValidNumberString is failed by leading plus sign",
			input:                "+12345",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input string : +12345",
		},
		{
			name:                 "assertValidNumberString is failed by multiple negative signs",
			input:                "--12345",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input string : --12345",
		},
		{
			name:                 "assertValidNumberString is failed by space in string",
			input:                "123 45",
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-POSITION-004] invalid input data || input string : 123 45",
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
		name     string
		input    uint64
		expected string
	}{
		{
			name:     "positionIdFrom preserves uint64 min",
			input:    uint64(0),
			expected: "0",
		},
		{
			name:     "positionIdFrom is success by uint64",
			input:    uint64(1),
			expected: "1",
		},
		{
			name:     "positionIdFrom preserves uint64 1<<63",
			input:    uint64(9223372036854775808),
			expected: "9223372036854775808",
		},
		{
			name:     "positionIdFrom preserves uint64 max",
			input:    uint64(18446744073709551615),
			expected: "18446744073709551615",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initPositionTest(t)

			got := positionIdFrom(tc.input)
			uassert.Equal(t, tc.expected, string(got))
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
			mockInstance.mustUpdatePosition(tc.positionId, position)

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
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid poolKey(gno.land/r/onbloc)",
			shouldPanic:   true,
		},
		{
			name:          "pool key divide is failed by empty poolKey",
			poolKey:       "",
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid poolKey()",
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
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid poolKey()",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by invalid delimiter",
			poolKey:       "gno.land/r/gnoswap:v1/gns:gno.land/r/gnoland/wugnot-500",
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid fee(gno.land/r/gnoland/wugnot-500)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by non-numeric fee",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:fee",
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid fee(fee)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by missing fee part",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/gnoland/wugnot:",
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid fee()",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by insufficient parts",
			poolKey:       "gno.land/r/gnoswap/gns:gno.land/r/demo",
			expectedError: "[GNOSWAP-POSITION-004] invalid input data || invalid poolKey(gno.land/r/gnoswap/gns:gno.land/r/demo)",
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

func legacySubUint256ForTest(x, y *u256.Uint) *u256.Uint {
	if x.Cmp(y) < 0 {
		diff := u256.Zero().Sub(u256.MustFromDecimal(MAX_UINT256), y)
		result := u256.Zero().Add(diff, x)
		return result.Add(result, u256.One())
	}

	return u256.Zero().Sub(x, y)
}

func TestSubUint256EquivalenceWithLegacyFormula(t *testing.T) {
	tests := []struct {
		name string
		x    string
		y    string
	}{
		{name: "zero_minus_zero", x: "0", y: "0"},
		{name: "zero_minus_one", x: "0", y: "1"},
		{name: "one_minus_zero", x: "1", y: "0"},
		{name: "one_minus_max", x: "1", y: MAX_UINT256},
		{name: "max_minus_zero", x: MAX_UINT256, y: "0"},
		{name: "max_minus_max", x: MAX_UINT256, y: MAX_UINT256},
		{name: "max_minus_one", x: MAX_UINT256, y: "1"},
		{name: "max_minus_prev", x: MAX_UINT256, y: "115792089237316195423570985008687907853269984665640564039457584007913129639934"},
		{name: "small_underflow", x: "50", y: "100"},
		{name: "small_normal", x: "100", y: "50"},
		{name: "int64_boundary_cross", x: "9223372036854775808", y: "9223372036854775807"},
		{name: "large_underflow", x: "500000000000000000000", y: "1000000000000000000000"},

		// additional boundary and domain cases
		{name: "zero_minus_two", x: "0", y: "2"},
		{name: "underflow_by_one", x: "100", y: "101"},
		{
			name: "underflow_by_one_at_uint128_boundary",
			x:    "340282366920938463463374607431768211455", // 2^128 - 1
			y:    "340282366920938463463374607431768211456", // 2^128
		},
		{
			name: "normal_sub_at_q128",
			x:    "680564733841876926926749214863536422912", // 2 * 2^128
			y:    "340282366920938463463374607431768211456", // 2^128
		},
		{name: "zero_minus_max", x: "0", y: MAX_UINT256},
		{
			name: "one_minus_max_minus_one",
			x:    "1",
			y:    "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX-1
		},
		{name: "equal_mid_range", x: "12345678901234567890", y: "12345678901234567890"},
		{
			name: "fee_growth_typical_underflow",
			// realistic fee growth accumulator: global < position snapshot means new epoch
			x: "1000000000000000000000000000000000000", // ~1e36 (small accumulator)
			y: "999999999999999999999999999999999999999",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			x := u256.MustFromDecimal(tc.x)
			y := u256.MustFromDecimal(tc.y)

			legacy := legacySubUint256ForTest(x, y)
			direct := u256.Zero().Sub(x, y)

			uassert.Equal(t, legacy.ToString(), direct.ToString(),
				"legacy formula and direct u256.Sub differ for x=%s, y=%s",
				tc.x, tc.y,
			)
		})
	}
}

// TestSubUint256DoubleUnderflow verifies that chained Sub calls each underflow (wrap around)
// correctly — mirroring the two consecutive subtractions in GetUnclaimedFee:
//
//	step1 = Sub(global, lower)   // may underflow
//	step2 = Sub(step1, upper)    // may underflow again
//
// Each case checks the intermediate and final results against both the expected
// value and the legacy formula.
func TestSubUint256DoubleUnderflow(t *testing.T) {
	tests := []struct {
		name          string
		a             string // first operand
		b             string // subtracted in step 1  (a < b  → underflow)
		c             string // subtracted in step 2  (step1 < c → underflow again)
		expectedStep1 string // result after first wrap
		expectedStep2 string // result after second wrap
	}{
		{
			// step1: 5 - 10 = 2^256 - 5  = MAX - 4
			// step2: (MAX-4) - (MAX-2) = -2 mod 2^256 = MAX - 1
			name:          "small_values_double_wrap",
			a:             "5",
			b:             "10",
			c:             "115792089237316195423570985008687907853269984665640564039457584007913129639933", // MAX-2
			expectedStep1: "115792089237316195423570985008687907853269984665640564039457584007913129639931", // MAX-4
			expectedStep2: "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX-1
		},
		{
			// step1: 1 - 3 = 2^256 - 2  = MAX - 1
			// step2: (MAX-1) - MAX = -1 mod 2^256 = MAX
			name:          "near_max_double_wrap",
			a:             "1",
			b:             "3",
			c:             MAX_UINT256,
			expectedStep1: "115792089237316195423570985008687907853269984665640564039457584007913129639934", // MAX-1
			expectedStep2: MAX_UINT256,                                                                      // MAX
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			a := u256.MustFromDecimal(tc.a)
			b := u256.MustFromDecimal(tc.b)
			c := u256.MustFromDecimal(tc.c)

			// step 1: first underflow
			step1 := u256.Zero().Sub(a, b)
			legacyStep1 := legacySubUint256ForTest(u256.MustFromDecimal(tc.a), u256.MustFromDecimal(tc.b))

			uassert.Equal(t, tc.expectedStep1, step1.ToString(),
				"step1 wrap incorrect: %s - %s", tc.a, tc.b)
			uassert.Equal(t, legacyStep1.ToString(), step1.ToString(),
				"step1 differs from legacy: %s - %s", tc.a, tc.b)

			// step 2: second underflow on the already-wrapped result
			step2 := u256.Zero().Sub(step1, c)
			legacyStep2 := legacySubUint256ForTest(u256.MustFromDecimal(tc.expectedStep1), u256.MustFromDecimal(tc.c))

			uassert.Equal(t, tc.expectedStep2, step2.ToString(),
				"step2 wrap incorrect: step1(%s) - %s", tc.expectedStep1, tc.c)
			uassert.Equal(t, legacyStep2.ToString(), step2.ToString(),
				"step2 differs from legacy: step1(%s) - %s", tc.expectedStep1, tc.c)
		})
	}
}
