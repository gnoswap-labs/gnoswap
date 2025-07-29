package position

import (
	"std"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/gnft"
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

func TestGetOrigPkgAddr(t *testing.T) {
	tests := []struct {
		name     string
		expected std.Address
	}{
		{
			name:     "getOrigPkgAddr is success",
			expected: positionAddr,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := GetOrigPkgAddr()
			uassert.Equal(t, got, tc.expected)
		})
	}
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
		addr       std.Address
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
			gnft.Mint(cross, adminAddr, positionIdFrom(tc.positionId))

			got := isOwner(tc.positionId, tc.addr)

			uassert.Equal(t, tc.expected, got)
		})
	}
}

func TestIsOperator(t *testing.T) {
	tests := []struct {
		name       string
		positionId uint64
		addr       std.Address
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
			// given
			initPositionTest(t)

			position := newDummyPosition(tc.positionId)
			position.operator = alice
			createNewPosition(tc.positionId, position)

			// given - nft owner is position realm then set as approved alice
			testing.SetRealm(posRealm)
			gnft.Mint(cross, stakerAddr, positionIdFrom(tc.positionId))

			testing.SetOriginCaller(stakerAddr)
			gnft.Approve(cross, alice, positionIdFrom(tc.positionId))

			// when
			got := isOperator(tc.positionId, tc.addr)

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
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:500",
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
			poolKey:       "gno.land/r/gnoswap:v1/gns:gno.land/r/demo/wugnot-500",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(gno.land/r/demo/wugnot-500)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by non-numeric fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:fee",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee(fee)",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by missing fee part",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid fee()",
			shouldPanic:   true,
		},
		{
			name:          "split of is failed by insufficient parts",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo",
			expectedError: "[GNOSWAP-POSITION-005] invalid input data || invalid poolKey(gno.land/r/gnoswap/v1/gns:gno.land/r/demo)",
			shouldPanic:   true,
		},
		{
			name:          "split of is success by valid poolKey",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:500",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
			expectedFee:   500,
			shouldPanic:   false,
		},
		{
			name:          "split of is success by poolKey with large fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:10000",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
			expectedFee:   10000,
			shouldPanic:   false,
		},
		{
			name:          "split of is success by poolKey with minimal fee",
			poolKey:       "gno.land/r/gnoswap/v1/gns:gno.land/r/demo/wugnot:1",
			expectedPath0: "gno.land/r/gnoswap/v1/gns",
			expectedPath1: "gno.land/r/demo/wugnot",
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
