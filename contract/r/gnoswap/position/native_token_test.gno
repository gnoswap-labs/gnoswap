package position

import (
	"errors"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
)

func TestTransferUGNOT(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to std.Address)
		verify      func(t *testing.T, to std.Address) int64
		from        std.Address
		to          std.Address
		expected    string
		shouldPanic bool
	}{
		{
			name: "Success - Zero amount",
			action: func(t *testing.T, from, to std.Address) {
				transferUGNOT(from, to, 0)
			},
			verify: func(t *testing.T, to std.Address) int64 {
				return ugnotBalanceOf(t, to)
			},
			from:        alice,
			to:          bob,
			expected:    "0",
			shouldPanic: false,
		},
		{
			name: "Success - Valid transfer",
			action: func(t *testing.T, from, to std.Address) {
				ugnotFaucet(t, from, 100)
				testing.SetRealm(std.NewUserRealm(from))
				transferUGNOT(from, to, 100)
			},
			verify: func(t *testing.T, to std.Address) int64 {
				return ugnotBalanceOf(t, to)
			},
			from:        positionAddr,
			to:          bob,
			expected:    "100",
			shouldPanic: false,
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if !tc.shouldPanic {
				tc.action(t, tc.from, tc.to)
				if tc.verify != nil {
					balance := tc.verify(t, tc.to)
					uassert.Equal(t, tc.expected, strconv.FormatInt(balance, 10))
				}
			} else {
				uassert.PanicsWithMessage(t, tc.expected, func() {
					tc.action(t, tc.from, tc.to)
				})
			}
		})
	}
}

func TestWrapInPosition(t *testing.T) {
	tests := []struct {
		name           string
		action         func(t *testing.T, from, to std.Address) error
		verify         func(t *testing.T, to std.Address) int64
		from           std.Address
		to             std.Address
		expected       string
		shouldPanic    bool
		expectedErrMsg string
	}{
		{
			name: "Failure - Amount less than minimum",
			action: func(t *testing.T, from, to std.Address) error {
				return wrap(999, to)
			},
			verify:         nil,
			from:           alice,
			to:             bob,
			expectedErrMsg: "amount(999) < minimum(1000)",
			shouldPanic:    true,
		},
		{
			name: "Failure - Zero amount",
			action: func(t *testing.T, from, to std.Address) error {
				return wrap(0, to)
			},
			verify:         nil,
			from:           alice,
			to:             bob,
			expectedErrMsg: "amount(0) < minimum(1000)",
			shouldPanic:    true,
		},
		{
			name: "Success - Valid amount",
			action: func(t *testing.T, from, to std.Address) error {
				ugnotFaucet(t, from, 1000)
				testing.SetRealm(std.NewUserRealm(from))
				return wrap(1000, to)
			},
			verify: func(t *testing.T, to std.Address) int64 {
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
				uassert.ErrorIs(t, tc.action(t, tc.from, tc.to), errors.New(tc.expectedErrMsg))
			}
		})
	}
}

func TestUnWrap(t *testing.T) {
	tests := []struct {
		name        string
		action      func(t *testing.T, from, to std.Address) error
		verify      func(t *testing.T, to std.Address) int64
		from        std.Address
		to          std.Address
		expected    string
		shouldPanic bool
	}{
		{
			name: "Failure - Zero amount",
			action: func(t *testing.T, from, to std.Address) error {
				return unwrap(0, to)
			},
			verify:      nil,
			from:        alice,
			to:          bob,
			expected:    "amount(0) is zero or negative",
			shouldPanic: true,
		},
		{
			name: "Success - Valid amount",
			action: func(t *testing.T, from, to std.Address) error {
				ugnotFaucet(t, from, 1000)

				testing.SetRealm(std.NewUserRealm(from))
				err := wrap(1000, to)
				uassert.Nil(t, err, "wrap should not return error")

				TokenApprove(t, wugnotPath, to, from, 1000)
				return unwrap(1000, to)
			},
			verify: func(t *testing.T, to std.Address) int64 {
				return ugnotBalanceOf(t, to)
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
			name:     "Native Token - GNOT",
			token:    "gnot",
			expected: true,
		},
		{
			name:     "Non-Native Token",
			token:    "usdt",
			expected: false,
		},
		{
			name:     "Empty Token",
			token:    "",
			expected: false,
		},
		{
			name:     "Similar but Different Token",
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
			name:      "Success - Token is Wrapped WUGNOT",
			tokenPath: consts.WRAPPED_WUGNOT,
			expected:  true,
		},
		{
			name:      "Fail - Token is not Wrapped WUGNOT",
			tokenPath: "gno.land/r/demo/ugnot",
			expected:  false,
		},
		{
			name:      "Fail - Empty tokenPath",
			tokenPath: "",
			expected:  false,
		},
		{
			name:      "Fail - Similar but Different Token Path",
			tokenPath: "gno.land/r/demo/Wugnot",
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
		amountDesired string
		userAddress   std.Address
		sentAmount    int64
		expectPanic   bool
		expectedWrap  int64
		expectedError string
	}{
		{
			name:          "Panic - Zero UGNOT",
			amountDesired: "50",
			userAddress:   alice,
			sentAmount:    0,
			expectPanic:   true,
			expectedError: "[GNOSWAP-POSITION-008] can not wrap less than minimum amount || amount(50) < minimum(1000)",
		},
		{
			name:          "Panic - Insufficient UGNOT",
			amountDesired: "150",
			userAddress:   alice,
			sentAmount:    100,
			expectPanic:   true,
			expectedError: "[GNOSWAP-POSITION-008] can not wrap less than minimum amount || amount(150) < minimum(1000)",
		},
		{
			name:          "Panic - Invalid Desired Amount",
			amountDesired: "invalid",
			userAddress:   alice,
			sentAmount:    200,
			expectPanic:   true,
			expectedError: "[GNOSWAP-POSITION-003] wrap, unwrap failed || strconv.ParseInt: parsing \"invalid\": invalid syntax",
		},
		{
			name:          "Successful wrap - Exact Amount",
			amountDesired: "1050",
			userAddress:   alice,
			sentAmount:    1050,
			expectPanic:   false,
			expectedWrap:  1050,
		},
		{
			name:          "Excess Refund",
			amountDesired: "1000",
			userAddress:   alice,
			sentAmount:    1500,
			expectPanic:   false,
			expectedWrap:  1000,
		},
		{
			name:          "Boundary Test - Exact Match",
			amountDesired: "1000",
			userAddress:   alice,
			sentAmount:    1000,
			expectPanic:   false,
			expectedWrap:  1000,
		},
		{
			name:          "Zero Desired Amount", // unable to catch this panic
			amountDesired: "0",
			userAddress:   alice,
			sentAmount:    100,
			expectPanic:   true,
			expectedError: "[GNOSWAP-POSITION-004] zero wrapped amount || amount requested to wrap is zero",
		},
		{
			name:          "Wrap Error Test",
			amountDesired: "100",
			userAddress:   alice,
			sentAmount:    100,
			expectPanic:   true, // Simulate wrap error internally
			expectedError: "[GNOSWAP-POSITION-008] can not wrap less than minimum amount || amount(100) < minimum(1000)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// we ignore the error here because we need to test
			// the invalid amount case
			amount, _ := strconv.ParseInt(tt.amountDesired, 10, 64)
			if amount > 0 {
				ugnotFaucet(t, positionAddr, amount)
			}
			testing.SetRealm(std.NewUserRealm(positionAddr))

			transferUGNOT(positionAddr, positionAddr, amount)

			// Verify wrapped amount
			if !tt.expectPanic {
				wrappedAmount := safeWrapNativeToken(tt.amountDesired, tt.userAddress)
				uassert.Equal(t, tt.expectedWrap, wrappedAmount)
			} else {
				uassert.PanicsWithMessage(t, tt.expectedError, func() {
					safeWrapNativeToken(tt.amountDesired, tt.userAddress)
				})
			}
		})
	}
}
