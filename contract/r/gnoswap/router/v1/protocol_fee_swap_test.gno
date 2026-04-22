package v1

import (
	"testing"

	"gno.land/r/onbloc/bar"
)

func TestHandleSwapFee(t *testing.T) {
	tests := []struct {
		name           string
		amount         int64
		swapFeeValue   uint64
		expectedAmount int64
	}{
		{
			name:           "zero swap fee",
			amount:         1000,
			swapFeeValue:   0,
			expectedAmount: 1000,
		},
		{
			name:           "normal swap fee calculation (0.15%)",
			amount:         10000,
			swapFeeValue:   15,
			expectedAmount: 9985, // 10000 - (10000 * 0.15%)
		},
		{
			name:           "Dry Run test",
			amount:         10000,
			swapFeeValue:   15,
			expectedAmount: 9985,
		},
		{
			name:           "large amount swap fee calculation",
			amount:         1000000,
			swapFeeValue:   15,
			expectedAmount: 998500, // 1000000 - (1000000 * 0.15%)
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()

			testing.SetRealm(adminRealm)
			func(cur realm) {
				router.SetSwapFee(tt.swapFeeValue)
			}(cross)

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			bar.Transfer(cross, routerAddr, tt.amount)

			func(cur realm) {
				testing.SetRealm(routerRealm)
				result := router.handleSwapFee(barPath, tt.amount)

				if result != tt.expectedAmount {
					t.Errorf("handleSwapFee() = %d, want %d", result, tt.expectedAmount)
				}
			}(cross)
		})
	}
}

func TestSetSwapFee_Success(t *testing.T) {
	router := mockRouter()

	tests := []struct {
		name string
		fee  uint64
	}{
		{"zero fee", 0},
		{"minimum fee", 1},
		{"normal fee (0.15%)", 15},
		{"near max fee", 999},
		{"max fee (10%)", 1000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Set realm to admin
			testing.SetRealm(adminRealm)

			// Execute
			func(cur realm) {
				router.SetSwapFee(tt.fee)
			}(cross)

			// Verify
			actualFee := router.GetSwapFee()
			if actualFee != tt.fee {
				t.Errorf("GetSwapFee() = %d, want %d", actualFee, tt.fee)
			}
		})
	}
}

// NOTE: Tests for invalid fees and unauthorized access are skipped due to test environment limitations
// with realm frame handling. These scenarios are covered by:
// - Integration tests
// - Access module tests (for authorization)
// - SetSwapFee input validation in the router implementation

func TestProtocolFeeSwap_GetSwapFee(t *testing.T) {
	router := mockRouter()

	// Set initial fee
	testing.SetRealm(adminRealm)
	func(cur realm) {
		router.SetSwapFee(15)
	}(cross)

	// Get fee (no special realm needed)
	fee := router.GetSwapFee()

	// Verify
	if fee != 15 {
		t.Errorf("GetSwapFee() = %d, want 15", fee)
	}
}

func TestSetSwapFee_MultipleChanges(t *testing.T) {
	router := mockRouter()

	fees := []uint64{0, 15, 100, 500, 1000, 250}

	testing.SetRealm(adminRealm)

	for _, expectedFee := range fees {
		func(cur realm) {
			router.SetSwapFee(expectedFee)
		}(cross)

		actualFee := router.GetSwapFee()
		if actualFee != expectedFee {
			t.Errorf("After setting fee to %d, GetSwapFee() = %d", expectedFee, actualFee)
		}
	}
}

func TestCalculateRouterFee_WithSetSwapFee(t *testing.T) {
	router := mockRouter()

	tests := []struct {
		name           string
		swapFee        uint64
		amount         int64
		expectedFee    int64
		expectedRemain int64
	}{
		{
			name:           "0.15% fee on 1000000",
			swapFee:        15,
			amount:         1000000,
			expectedFee:    1500,
			expectedRemain: 998500,
		},
		{
			name:           "1% fee on 1000000",
			swapFee:        100,
			amount:         1000000,
			expectedFee:    10000,
			expectedRemain: 990000,
		},
		{
			name:           "10% fee (max) on 1000000",
			swapFee:        1000,
			amount:         1000000,
			expectedFee:    100000,
			expectedRemain: 900000,
		},
		{
			name:           "zero fee",
			swapFee:        0,
			amount:         1000000,
			expectedFee:    0,
			expectedRemain: 1000000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)

			// Set swap fee
			func(cur realm) {
				router.SetSwapFee(tt.swapFee)
			}(cross)

			// Calculate fee
			feeAmount := calculateRouterFee(tt.amount, tt.swapFee)
			if feeAmount != tt.expectedFee {
				t.Errorf("calculateRouterFee() = %d, want %d", feeAmount, tt.expectedFee)
			}

			// Verify remaining amount
			remaining := tt.amount - feeAmount
			if remaining != tt.expectedRemain {
				t.Errorf("remaining = %d, want %d", remaining, tt.expectedRemain)
			}
		})
	}
}
