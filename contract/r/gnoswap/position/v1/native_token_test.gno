package v1

import (
	"errors"
	"strconv"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestWrapInPosition(t *testing.T) {
	tests := []struct {
		name           string
		action         func(t *testing.T, from, to address) error
		verify         func(t *testing.T, addr address) int64
		from           address
		to             address
		expected       string
		shouldPanic    bool
		expectedErrMsg string
	}{
		{
			name: "wrap is failed by zero amount",
			action: func(t *testing.T, from, to address) error {
				return mockInstance.wrap(0, from)
			},
			verify:         nil,
			from:           alice,
			to:             bob,
			expectedErrMsg: "amount(0) is zero or negative",
			shouldPanic:    true,
		},
		{
			name: "wrap is failed by negative amount",
			action: func(t *testing.T, from, to address) error {
				return mockInstance.wrap(-1, from)
			},
			verify:         nil,
			from:           alice,
			to:             bob,
			expectedErrMsg: "amount(-1) is zero or negative",
			shouldPanic:    true,
		},
		{
			name: "wrap is success by valid amount",
			action: func(t *testing.T, from, to address) error {
				// Give the user wugnot and approve position
				ugnotFaucet(t, from, 1000)
				ugnotDeposit(t, from, 1000)
				TokenApprove(t, wugnotPath, from, positionAddr, 1000)

				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))
				return mockInstance.wrap(1000, from)
			},
			verify: func(t *testing.T, addr address) int64 {
				return TokenBalance(t, wugnotPath, positionAddr)
			},
			from:        alice,
			to:          bob,
			expected:    "1000",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if !tc.shouldPanic {
				err := tc.action(t, tc.from, tc.to)
				if err == nil && tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatInt(balance, 10))
				}
			} else {
				uassert.ErrorIs(t, tc.action(t, tc.from, tc.to), errors.New(tc.expectedErrMsg))
			}
		})
	}
}

func TestUnWrap(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to address) error
		verify      func(t *testing.T, to address) int64
		from        address
		to          address
		expected    string
		shouldPanic bool
	}{
		{
			name: "unwrap is failed by zero amount",
			action: func(t *testing.T, from, to address) error {
				return mockInstance.unwrap(0, to)
			},
			verify:      nil,
			from:        alice,
			to:          bob,
			expected:    "amount(0) is zero or negative",
			shouldPanic: true,
		},
		{
			name: "unwrap is success by valid amount",
			action: func(t *testing.T, from, to address) error {
				// Give position some wugnot first
				ugnotFaucet(t, positionAddr, 1000)
				ugnotDeposit(t, positionAddr, 1000)

				// unwrap sends wugnot from position to user
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))
				return mockInstance.unwrap(1000, to)
			},
			verify: func(t *testing.T, to address) int64 {
				return TokenBalance(t, wugnotPath, to)
			},
			from:        positionAddr,
			to:          bob,
			expected:    "1000",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if !tc.shouldPanic {
				err := tc.action(t, tc.from, tc.to)
				if err == nil && tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatInt(balance, 10))
				}
			} else {
				err := tc.action(t, tc.from, tc.to)
				if err != nil {
					uassert.Equal(t, tc.expected, err.Error())
				} else {
					t.Errorf(">>> %s: expected panic but got none", tc.name)
				}
			}
		})
	}
}

func TestIsNative(t *testing.T) {
	tests := []struct {
		name     string
		token    string
		expected bool
	}{
		{
			name:     "isNative is success by native token",
			token:    "ugnot",
			expected: true,
		},
		{
			name:     "isNative is failed by non-native token",
			token:    "usdt",
			expected: false,
		},
		{
			name:     "isNative is failed by empty token",
			token:    "",
			expected: false,
		},
		{
			name:     "isNative is failed by similar but different token",
			token:    "GNOT",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isNative(tt.token)
			uassert.Equal(t, tt.expected, result, "Unexpected result for token: "+tt.token)
		})
	}
}

func TestIsWrappedToken(t *testing.T) {
	tests := []struct {
		name      string
		tokenPath string
		expected  bool
	}{
		{
			name:      "isWrappedToken is success by wrapped UGNOT",
			tokenPath: WUGNOT_PATH,
			expected:  true,
		},
		{
			name:      "isWrappedToken is failed by non-wrapped UGNOT",
			tokenPath: "gno.land/r/demo/ugnot",
			expected:  false,
		},
		{
			name:      "isWrappedToken is failed by empty tokenPath",
			tokenPath: "",
			expected:  false,
		},
		{
			name:      "isWrappedToken is failed by similar but different tokenPath",
			tokenPath: "gno.land/r/gnolands/wugnot",
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isWrappedToken(tt.tokenPath)
			if result != tt.expected {
				t.Errorf(
					"expected %s but got %s",
					strconv.FormatBool(tt.expected),
					strconv.FormatBool(result),
				)
			}
		})
	}
}

func TestSafeWrapNativeToken(t *testing.T) {
	tests := []struct {
		name          string
		amount        int64
		fromAddress   address
		expectError   bool
		expectedWrap  int64
		expectedError string
	}{
		{
			name:         "safeWrapNativeToken succeeds with zero amount (noop)",
			amount:       0,
			fromAddress:  alice,
			expectError:  false,
			expectedWrap: 0,
		},
		{
			name:         "safeWrapNativeToken succeeds with valid amount",
			amount:       1050,
			fromAddress:  alice,
			expectError:  false,
			expectedWrap: 1050,
		},
		{
			name:         "safeWrapNativeToken succeeds with exact minimum",
			amount:       1000,
			fromAddress:  alice,
			expectError:  false,
			expectedWrap: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.amount > 0 {
				// Give user wugnot and approve position
				ugnotFaucet(t, tt.fromAddress, tt.amount)
				ugnotDeposit(t, tt.fromAddress, tt.amount)
				TokenApprove(t, wugnotPath, tt.fromAddress, positionAddr, tt.amount)
			}

			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/position"))
			wrappedAmount, err := mockInstance.safeWrapNativeToken(tt.amount, tt.fromAddress)
			if tt.expectError {
				uassert.ErrorIs(t, err, errors.New(tt.expectedError))
			} else {
				uassert.Nil(t, err)
				uassert.Equal(t, tt.expectedWrap, wrappedAmount)
			}
		})
	}
}
