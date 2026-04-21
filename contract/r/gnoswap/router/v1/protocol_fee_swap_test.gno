package v1

import (
	"math"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
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
			protocolFeeAddr, _ := access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())

			testing.SetRealm(adminRealm)
			func(cur realm) {
				router.SetSwapFee(tt.swapFeeValue)
			}(cross)

			testing.SetRealm(testing.NewUserRealm(adminAddr))
			bar.Transfer(cross, routerAddr, tt.amount)
			testing.SetRealm(routerRealm)
			bar.Approve(cross, protocolFeeAddr, tt.amount)

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

// TestExactOutRoundTrip verifies that for ExactOut swaps, the gross-up and
// fee-deduction round-trip delivers exactly the user-requested amount.
//
// Flow: userAmount → calculateExactOutWithRouterFee → poolAmount
//
//	poolAmount → calculateRouterFee → feeAmount
//	poolAmount - feeAmount == userAmount (must hold)
func TestExactOutRoundTrip(t *testing.T) {
	tests := []struct {
		name       string
		userAmount int64
		swapFee    uint64
	}{
		{"0.15% fee, 1M tokens", 1000000, 15},
		{"0.15% fee, 100 tokens", 100, 15},
		{"0.15% fee, 1 token", 1, 15},
		{"1% fee, 1M tokens", 1000000, 100},
		{"1% fee, 100 tokens", 100, 100},
		{"1% fee, 1 token", 1, 100},
		{"10% fee (max), 1M tokens", 1000000, 1000},
		{"10% fee (max), 1 token", 1, 1000},
		{"0.01% fee, 1M tokens", 1000000, 1},
		{"0.15% fee, large amount (1B)", 1000000000, 15},
		{"0.15% fee, near-int64-max safe", 4611686018427387903, 15}, // ~int64max/2
		{"0.15% fee, int64-max safe", 9209536978799493643, 15},      // int64max - 0.15% fee
		{"0.15% fee, int64-max safe", math.MaxInt64, 0},             // int64max with no fee
		{"zero fee", 1000000, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolAmount := calculateExactOutWithRouterFee(tt.userAmount, tt.swapFee)
			feeAmount := calculateRouterFee(poolAmount, tt.swapFee)
			userReceives := poolAmount - feeAmount

			if userReceives != tt.userAmount {
				t.Errorf("round-trip mismatch: user requested %d, pool fetched %d, fee %d, user receives %d",
					tt.userAmount, poolAmount, feeAmount, userReceives)
			}
		})
	}
}

// TestExactOutFeeAccounting verifies that:
// 1. poolAmount > userAmount (pool provides more than user gets)
// 2. feeAmount == poolAmount - userAmount (fee is the exact difference)
// 3. protocolFee == poolAmount * feeRate / 10000 (fee formula is correct)
func TestExactOutFeeAccounting(t *testing.T) {
	tests := []struct {
		name         string
		userAmount   int64
		swapFee      uint64
		expectedPool int64
		expectedFee  int64
	}{
		{
			name:         "0.15% fee on 1M",
			userAmount:   1000000,
			swapFee:      15,
			expectedPool: 1001502, // 1000000 * 10000 / 9985
			expectedFee:  1502,    // 1001502 * 15 / 10000
		},
		{
			name:         "1% fee on 1M",
			userAmount:   1000000,
			swapFee:      100,
			expectedPool: 1010101, // 1000000 * 10000 / 9900
			expectedFee:  10101,   // 1010101 * 100 / 10000
		},
		{
			name:         "0.15% fee on 10",
			userAmount:   10,
			swapFee:      15,
			expectedPool: 10, // 10 * 10000 / 9985 = 10.015 → truncated to 10
			expectedFee:  0,  // 10 * 15 / 10000 = 0.015 → truncated to 0
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolAmount := calculateExactOutWithRouterFee(tt.userAmount, tt.swapFee)
			feeAmount := calculateRouterFee(poolAmount, tt.swapFee)

			if poolAmount != tt.expectedPool {
				t.Errorf("poolAmount = %d, want %d", poolAmount, tt.expectedPool)
			}
			if feeAmount != tt.expectedFee {
				t.Errorf("feeAmount = %d, want %d", feeAmount, tt.expectedFee)
			}
		})
	}
}

// TestExactOutSmallAmountRounding verifies rounding behavior at boundaries
// where the fee truncates to zero, meaning user gets the same amount as pool.
func TestExactOutSmallAmountRounding(t *testing.T) {
	tests := []struct {
		name       string
		userAmount int64
		swapFee    uint64
		expectLoss bool // true if user receives less than requested due to rounding
	}{
		{"1 token, 0.15% fee", 1, 15, false},
		{"2 tokens, 0.15% fee", 2, 15, false},
		{"10 tokens, 0.15% fee", 10, 15, false},
		{"100 tokens, 0.15% fee", 100, 15, false},
		{"666 tokens, 0.15% fee", 666, 15, false},
		{"667 tokens, 0.15% fee", 667, 15, false},
		{"1 token, 1% fee", 1, 100, false},
		{"99 tokens, 1% fee", 99, 100, false},
		{"100 tokens, 1% fee", 100, 100, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolAmount := calculateExactOutWithRouterFee(tt.userAmount, tt.swapFee)
			feeAmount := calculateRouterFee(poolAmount, tt.swapFee)
			userReceives := poolAmount - feeAmount

			if tt.expectLoss {
				if userReceives >= tt.userAmount {
					t.Errorf("expected rounding loss but user receives %d >= requested %d", userReceives, tt.userAmount)
				}
			} else {
				if userReceives != tt.userAmount {
					t.Errorf("user receives %d != requested %d (pool=%d, fee=%d)", userReceives, tt.userAmount, poolAmount, feeAmount)
				}
			}
		})
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
