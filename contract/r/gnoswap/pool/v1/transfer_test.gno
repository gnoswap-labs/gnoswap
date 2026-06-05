package v1

import (
	"testing"
)

func TestValidatePoolBalance(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		token0        int64
		token1        int64
		amount        int64
		isToken0      bool
		expectedError bool
	}{
		{
			name:          "successful token0 transfer",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedError: false,
		},
		{
			name:          "successful token1 transfer",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      false,
			expectedError: false,
		},
		{
			name:          "insufficient token0 balance",
			token0:        100,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedError: true,
		},
		{
			name:          "insufficient token1 balance",
			token0:        1000,
			token1:        100,
			amount:        500,
			isToken0:      false,
			expectedError: true,
		},
		{
			name:          "negative amount",
			token0:        1000,
			token1:        1000,
			amount:        -1,
			isToken0:      true,
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := validatePoolBalance(tt.token0, tt.token1, tt.amount, tt.isToken0)
			if tt.expectedError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}
		})
	}
}

func TestUpdatePoolBalance(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		token0        int64
		token1        int64
		amount        int64
		isToken0      bool
		expectedBal   int64
		expectedError bool
	}{
		{
			name:          "successful token0 decrease",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedBal:   500,
			expectedError: false,
		},
		{
			name:          "successful token1 decrease",
			token0:        1000,
			token1:        1000,
			amount:        500,
			isToken0:      false,
			expectedBal:   500,
			expectedError: false,
		},
		{
			name:          "insufficient token0 balance",
			token0:        100,
			token1:        1000,
			amount:        500,
			isToken0:      true,
			expectedBal:   0,
			expectedError: true,
		},
		{
			name:          "insufficient token1 balance",
			token0:        1000,
			token1:        100,
			amount:        500,
			isToken0:      false,
			expectedBal:   0,
			expectedError: true,
		},
		{
			name:          "zero amount",
			token0:        1000,
			token1:        1000,
			amount:        0,
			isToken0:      true,
			expectedBal:   1000,
			expectedError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			newBal, err := updatePoolBalance(tt.token0, tt.token1, tt.amount, tt.isToken0)
			if tt.expectedError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
				return
			}
			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}
			if newBal != tt.expectedBal {
				t.Errorf("balance mismatch: expected %d, got %d", tt.expectedBal, newBal)
			}
		})
	}
}
