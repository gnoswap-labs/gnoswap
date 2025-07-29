package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Test validateDelegateAmount function
func TestStakerDelegate_validateDelegateAmount(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		expectError bool
		expectedMsg string
	}{
		{
			name:        "Valid minimum amount",
			amount:      minimumAmount,
			expectError: false,
		},
		{
			name:        "Valid multiple of minimum amount",
			amount:      minimumAmount * 2,
			expectError: false,
		},
		{
			name:        "Amount less than minimum",
			amount:      minimumAmount - 1,
			expectError: true,
			expectedMsg: "[GNOSWAP-GOV_STAKER-011] can not delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:999999)",
		},
		{
			name:        "Amount not multiple of minimum",
			amount:      minimumAmount + 1,
			expectError: true,
			expectedMsg: "[GNOSWAP-GOV_STAKER-004] invalid amount || amount must be multiple of 1000000",
		},
		{
			name:        "Zero amount",
			amount:      0,
			expectError: true,
			expectedMsg: "[GNOSWAP-GOV_STAKER-011] can not delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:0)",
		},
		{
			name:        "Negative amount",
			amount:      -100,
			expectError: true,
			expectedMsg: "[GNOSWAP-GOV_STAKER-011] can not delegate less than minimum amount || minimum amount to delegate is 1000000 (requested:-100)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Then: Check result
			if tt.expectError {
				uassert.PanicsWithMessage(t, tt.expectedMsg, func() {
					assertIsValidDelegateAmount(tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidDelegateAmount(tt.amount)
				})
			}
		})
	}
}