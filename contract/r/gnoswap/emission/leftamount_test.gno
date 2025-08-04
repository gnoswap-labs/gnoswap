package emission

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"

	"gno.land/r/gnoswap/v1/gns"
)

func TestLeftAmountFix(t *testing.T) {
	resetObject(t)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, emissionAddr, 10000000) // 10M GNS tokens

	tests := []struct {
		name               string
		initialLeftAmount  int64
		distributionAmount int64
		distributions      map[string]int64 // target -> bps
		expectedTotalSent  int64
		expectedLeftAmount int64
		setupFunc          func()
		verifyFunc         func(t *testing.T, actualLeft int64)
		shouldError        bool
		errorMessage       string
	}{
		{
			name:               "Verify leftAmount is correctly tracked when rounding occurs",
			initialLeftAmount:  0,
			distributionAmount: 10001,
			distributions: map[string]int64{
				"1": 3333, // 33.33%
				"2": 3333, // 33.33%
				"3": 3333, // 33.33%
				"4": 0,    // 0%
			},
			expectedTotalSent:  9999, // 3333 * 3
			expectedLeftAmount: 2,    // 10001 - 9999
			shouldError:        false,
			errorMessage:       "",
			setupFunc: func() {
				leftGNSAmount = 0
				distributionBpsPct = avl.NewTree()
			},
		},
		{
			name:               "Verify fix works with zero initial leftGNSAmount",
			initialLeftAmount:  0,
			distributionAmount: 10001,
			distributions: map[string]int64{
				"1": 3333,
				"2": 3333,
				"3": 3333,
				"4": 0,
			},
			expectedTotalSent:  9999,
			expectedLeftAmount: 2,
			shouldError:        false,
			errorMessage:       "",
			setupFunc: func() {
				leftGNSAmount = 0
				distributionBpsPct = avl.NewTree()
			},
		},
		{
			name:               "Integration test with different percentages",
			initialLeftAmount:  0,
			distributionAmount: 123456,
			distributions: map[string]int64{
				"1": 3333, // 33.33%, 123456 * 3333 / 10000 = 41147
				"2": 3333, // 33.33%, 123456 * 3333 / 10000 = 41147
				"3": 3333, // 33.33%, 123456 * 3333 / 10000 = 41147
				"4": 1,    // 0.01% to make total 9999 bps, 123456 * 1 / 10000 = 12
			},
			expectedTotalSent:  123453, // 41147 +  41147 +  41147 +  12
			expectedLeftAmount: 3,      // 123456 - 123453
			shouldError:        false,
			errorMessage:       "",
			setupFunc: func() {
				leftGNSAmount = 0
				lastExecutedHeight = 0
				distributionBpsPct = avl.NewTree()
			},
			verifyFunc: func(t *testing.T, actualLeft int64) {
				// Custom verification for integration test
				uassert.True(t, actualLeft >= 0)
			},
		},
		{
			name:               "Test with exact division (no remainder)",
			initialLeftAmount:  0,
			distributionAmount: 10000,
			distributions: map[string]int64{
				"1": 5000, // 50%
				"2": 5000, // 50%
			},
			expectedTotalSent:  10000, // 5000 + 5000
			expectedLeftAmount: 0,     // No remainder
			setupFunc: func() {
				leftGNSAmount = 0
				distributionBpsPct = avl.NewTree()
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			if tt.setupFunc != nil {
				tt.setupFunc()
			}

			// Set distribution percentages
			for target, bps := range tt.distributions {
				distributionBpsPct.Set(target, bps)
			}

			// Execute distribution
			totalSent, err := distributeToTarget(tt.distributionAmount)

			if tt.shouldError {
				uassert.Equal(t, tt.errorMessage, err.Error())
			} else {
				// Get leftGNSAmount after distribution
				leftAmount := tt.distributionAmount - totalSent

				if tt.expectedTotalSent > 0 {
					uassert.Equal(t, tt.expectedTotalSent, totalSent)
				}

				if tt.verifyFunc != nil {
					tt.verifyFunc(t, leftAmount)
				}

				uassert.Equal(t, tt.expectedLeftAmount, leftAmount)
			}
		})
	}
}
