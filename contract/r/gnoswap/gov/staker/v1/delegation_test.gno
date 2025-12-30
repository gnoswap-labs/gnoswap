package v1

import (
    "math"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// Test DelegationType
func TestDelegationType(t *testing.T) {
	tests := []struct {
		name                 string
		delegationType       staker.DelegationType
		expectedString       string
		expectedIsDelegate   bool
		expectedIsUnDelegate bool
	}{
		{
			name:                 "DelegateType functionality",
			delegationType:       staker.DelegateType,
			expectedString:       "DELEGATE",
			expectedIsDelegate:   true,
			expectedIsUnDelegate: false,
		},
		{
			name:                 "UnDelegateType functionality",
			delegationType:       staker.UnDelegateType,
			expectedString:       "UNDELEGATE",
			expectedIsDelegate:   false,
			expectedIsUnDelegate: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Check delegation type methods
			resultString := tt.delegationType.String()
			resultIsDelegate := tt.delegationType.IsDelegate()
			resultIsUnDelegate := tt.delegationType.IsUnDelegate()

			// Then: Should return expected values
			uassert.Equal(t, resultString, tt.expectedString)
			uassert.Equal(t, resultIsDelegate, tt.expectedIsDelegate)
			uassert.Equal(t, resultIsUnDelegate, tt.expectedIsUnDelegate)
		})
	}
}

// Test Delegation creation
func TestNewDelegation(t *testing.T) {
	tests := []struct {
		name           string
		id             int64
		delegateFrom   address
		delegateTo     address
		delegateAmount int64
		createdAt      int64
	}{
		{
			name:           "Create new delegation",
			id:             1,
			delegateFrom:   address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
			delegateTo:     address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
			delegateAmount: 1000,
			createdAt:      100,
		},
		{
			name:           "Create delegation with zero amount",
			id:             2,
			delegateFrom:   address("g1w8m4s75k9l6n8vc6fmpcprgey4ck233kfhx5tz"),
			delegateTo:     address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
			delegateAmount: 0,
			createdAt:      200,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new delegation
			delegation := NewDelegation(
				tt.id,
				tt.delegateFrom,
				tt.delegateTo,
				tt.delegateAmount,
				tt.createdAt, // no need to set createdHeight
				tt.createdAt,
			)

			// Then: Should initialize correctly
			uassert.NotEqual(t, delegation, nil)
			uassert.Equal(t, delegation.ID(), tt.id)
			uassert.Equal(t, delegation.DelegateFrom(), tt.delegateFrom)
			uassert.Equal(t, delegation.DelegateTo(), tt.delegateTo)
			uassert.Equal(t, delegation.TotalDelegatedAmount(), tt.delegateAmount)

			resolver := NewDelegationResolver(delegation)
			uassert.Equal(t, resolver.DelegatedAmount(), tt.delegateAmount)
			uassert.Equal(t, resolver.LockedAmount(), tt.delegateAmount)
			uassert.Equal(t, resolver.CollectableAmount(tt.createdAt), int64(0))
			uassert.Equal(t, resolver.IsEmpty(), tt.delegateAmount == 0)

			uassert.Equal(t, resolver.Get().UnDelegatedAmount(), int64(0))
			uassert.Equal(t, resolver.Get().CollectedAmount(), int64(0))
			uassert.Equal(t, resolver.Get().CreatedAt(), tt.createdAt)
			uassert.Equal(t, len(resolver.Get().Withdraws()), 0)
		})
	}
}

// Test delegation getter methods
func TestDelegationGetters(t *testing.T) {
	tests := []struct {
		name                   string
		setupDelegation        func() *staker.Delegation
		currentTime            int64
		expectedTotalDelegated int64
		expectedDelegated      int64
		expectedLocked         int64
		expectedUnDelegated    int64
		expectedCollected      int64
		expectedCollectable    int64
		expectedIsEmpty        bool
	}{
		{
			name: "Fresh delegation with no operations",
			setupDelegation: func() *staker.Delegation {
				return NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
			},
			currentTime:            100,
			expectedTotalDelegated: 1000,
			expectedDelegated:      1000,
			expectedLocked:         1000,
			expectedUnDelegated:    0,
			expectedCollected:      0,
			expectedCollectable:    0,
			expectedIsEmpty:        false,
		},
		{
			name: "Delegation with undelegation",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					2,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 7*24*60*60) // 7 days lockup
				return delegation
			},
			currentTime:            200,
			expectedTotalDelegated: 1000,
			expectedDelegated:      700,  // 1000 - 300
			expectedLocked:         1000, // Still locked until collected
			expectedUnDelegated:    300,
			expectedCollected:      0,
			expectedCollectable:    0, // Locked, so not collectable yet
			expectedIsEmpty:        false,
		},
		{
			name: "Delegation with undelegation without lockup",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					3,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegateWithoutLockup(200, 150, 150)
				return delegation
			},
			currentTime:            150,
			expectedTotalDelegated: 1000,
			expectedDelegated:      800, // 1000 - 200
			expectedLocked:         800, // 1000 - 200 (collected immediately)
			expectedUnDelegated:    200,
			expectedCollected:      200, // Collected immediately
			expectedCollectable:    0,   // Already collected
			expectedIsEmpty:        false,
		},
		{
			name: "Empty delegation (fully collected)",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					4,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					500,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegateWithoutLockup(500, 150, 150) // Undelegate all without lockup
				return delegation
			},
			currentTime:            150,
			expectedTotalDelegated: 500,
			expectedDelegated:      0, // 500 - 500
			expectedLocked:         0, // 500 - 500 (all collected)
			expectedUnDelegated:    500,
			expectedCollected:      500,
			expectedCollectable:    0,
			expectedIsEmpty:        true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation
			delegation := tt.setupDelegation()

			// When: Call getter methods
			// Then: Should return expected values
			resolver := NewDelegationResolver(delegation)
			uassert.Equal(t, resolver.Get().TotalDelegatedAmount(), tt.expectedTotalDelegated)
			uassert.Equal(t, resolver.DelegatedAmount(), tt.expectedDelegated)
			uassert.Equal(t, resolver.LockedAmount(), tt.expectedLocked)
			uassert.Equal(t, resolver.Get().UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, resolver.Get().CollectedAmount(), tt.expectedCollected)
			uassert.Equal(t, resolver.CollectableAmount(tt.currentTime), tt.expectedCollectable)
			uassert.Equal(t, resolver.IsEmpty(), tt.expectedIsEmpty)
		})
	}
}

// Test unDelegate
func TestDelegation_unDelegate(t *testing.T) {
	tests := []struct {
		name                  string
		initialAmount         int64
		unDelegateAmount      int64
		currentTime           int64
		lockupPeriod          int64
		expectedUnDelegated   int64
		expectedWithdrawCount int
	}{
		{
			name:                  "Undelegate with standard lockup",
			initialAmount:         1000,
			unDelegateAmount:      300,
			currentTime:           200,
			lockupPeriod:          7 * 24 * 60 * 60, // 7 days
			expectedUnDelegated:   300,
			expectedWithdrawCount: 1,
		},
		{
			name:                  "Undelegate with zero lockup",
			initialAmount:         1000,
			unDelegateAmount:      500,
			currentTime:           300,
			lockupPeriod:          0,
			expectedUnDelegated:   500,
			expectedWithdrawCount: 1,
		},
		{
			name:                  "Multiple undelegations",
			initialAmount:         1000,
			unDelegateAmount:      200,
			currentTime:           400,
			lockupPeriod:          3 * 24 * 60 * 60, // 3 days
			expectedUnDelegated:   200,              // First undelegation
			expectedWithdrawCount: 1,                // First withdraw record
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh delegation
			delegation := NewDelegation(
				1,
				address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				tt.initialAmount,
				100,
				100,
			)

			resolver := NewDelegationResolver(delegation)

			// When: Undelegate
			resolver.UnDelegate(tt.unDelegateAmount, tt.currentTime, tt.currentTime, tt.lockupPeriod)

			// Then: Should update state correctly
			uassert.Equal(t, resolver.Get().UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, len(resolver.Get().Withdraws()), tt.expectedWithdrawCount)

			// Verify withdraw record
			if len(resolver.Get().Withdraws()) > 0 {
				withdraw := resolver.Get().Withdraws()[0]
				uassert.Equal(t, withdraw.DelegationID(), delegation.ID())
				uassert.Equal(t, withdraw.UnDelegateAmount(), tt.unDelegateAmount)
				uassert.Equal(t, withdraw.UnDelegatedAt(), tt.currentTime)
			}
		})
	}
}

// Test UnDelegateWithoutLockup
func TestDelegation_unDelegateWithoutLockup(t *testing.T) {
	tests := []struct {
		name                string
		initialAmount       int64
		unDelegateAmount    int64
		currentTime         int64
		expectedUnDelegated int64
		expectedCollected   int64
	}{
		{
			name:                "Undelegate without lockup",
			initialAmount:       1000,
			unDelegateAmount:    400,
			currentTime:         200,
			expectedUnDelegated: 400,
			expectedCollected:   400, // Immediately collected
		},
		{
			name:                "Undelegate all without lockup",
			initialAmount:       500,
			unDelegateAmount:    500,
			currentTime:         300,
			expectedUnDelegated: 500,
			expectedCollected:   500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh delegation
			delegation := NewDelegation(
				1,
				address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				tt.initialAmount,
				100,
				100,
			)

			resolver := NewDelegationResolver(delegation)

			// When: Undelegate without lockup
			resolver.UnDelegateWithoutLockup(tt.unDelegateAmount, tt.currentTime, tt.currentTime)

			// Then: Should update state correctly
			uassert.Equal(t, resolver.Get().UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, resolver.Get().CollectedAmount(), tt.expectedCollected)
			uassert.Equal(t, len(resolver.Get().Withdraws()), 1)

			// Verify withdraw record is immediately collectable
			withdraw := resolver.Get().Withdraws()[0]
			withdrawResolver := NewDelegationWithdrawResolver(withdraw)
			uassert.Equal(t, withdrawResolver.IsCollectable(tt.currentTime), false)
			uassert.Equal(t, withdrawResolver.CollectableAmount(tt.currentTime), int64(0)) // Already collected
		})
	}
}

// Test collect
func TestDelegation_collect(t *testing.T) {
	tests := []struct {
		name              string
		setupDelegation   func() *staker.Delegation
		collectAmount     int64
		currentTime       int64
		expectError       bool
		expectedCollected int64
	}{
		{
			name: "Collect from delegation with collectable amount",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				// Undelegate with lockup that has passed
				resolver.UnDelegate(300, 200, 200, 100) // Short lockup for testing
				return delegation
			},
			collectAmount:     300,
			currentTime:       400, // After lockup period
			expectError:       false,
			expectedCollected: 300,
		},
		{
			name: "Collect more than collectable amount",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					2,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)

				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(200, 200, 200, 100)
				return delegation
			},
			collectAmount: 500, // More than available
			currentTime:   400,
			expectError:   true,
		},
		{
			name: "Collect partial amount",
			setupDelegation: func() *staker.Delegation {
				delegation := NewDelegation(
					3,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(500, 200, 200, 100)
				return delegation
			},
			collectAmount:     300, // Partial collection
			currentTime:       400,
			expectError:       false,
			expectedCollected: 300,
		},
		{
			name: "Collect large amount without overflow",
			setupDelegation: func() *staker.Delegation {
				// Start with large delegation
				delegation := NewDelegation(
					4,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1_000_000_000_000, // 1 trillion units
					100,
					100,
				)
				// Undelegate half
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(500_000_000_000, 200, 200, 100)
				return delegation
			},
			collectAmount:     500_000_000_000, // Collect large amount
			currentTime:       400,             // After lockup
			expectError:       false,
			expectedCollected: 500_000_000_000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation
			delegation := tt.setupDelegation()
			resolver := NewDelegationResolver(delegation)
			initialCollected := resolver.Get().CollectedAmount()

			// When: Collect
			err := resolver.Collect(tt.collectAmount, tt.currentTime)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, resolver.Get().CollectedAmount(), initialCollected+tt.expectedCollected)
			}
		})
	}
}

// Test complex delegation scenarios
func TestDelegation_ComplexScenarios(t *testing.T) {
	tests := []struct {
		name        string
		operations  func(*DelegationResolver)
		description string
	}{
		{
			name: "Multiple undelegations with different lockup periods",
			operations: func(d *DelegationResolver) {
				// First undelegation with 7 day lockup
				d.UnDelegate(200, 100, 100, 7*24*60*60)
				uassert.Equal(t, d.Get().UnDelegatedAmount(), int64(200))
				uassert.Equal(t, len(d.Get().Withdraws()), 1)

				// Second undelegation with 3 day lockup
				d.UnDelegate(150, 200, 200, 3*24*60*60)
				uassert.Equal(t, d.Get().UnDelegatedAmount(), int64(350))
				uassert.Equal(t, len(d.Get().Withdraws()), 2)

				// Third undelegation without lockup
				d.UnDelegateWithoutLockup(100, 300, 300)
				uassert.Equal(t, d.Get().UnDelegatedAmount(), int64(450))
				uassert.Equal(t, d.Get().CollectedAmount(), int64(100)) // Immediate collection
				uassert.Equal(t, len(d.Get().Withdraws()), 3)
			},
			description: "Should handle multiple undelegations with different lockup periods",
		},
		{
			name: "Partial collections from multiple withdraws",
			operations: func(d *DelegationResolver) {
				// Setup multiple undelegations
				d.UnDelegate(300, 100, 100, 100) // Short lockup
				d.UnDelegate(200, 150, 150, 50)  // Very short lockup

				// After sufficient time, both should be collectable
				currentTime := int64(400)

				// Collect partially
				err := d.Collect(250, currentTime)
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(250))

				// Collect remaining
				err = d.Collect(250, currentTime+100)
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(500))
			},
			description: "Should handle partial collections from multiple withdrawals",
		},
		{
			name: "Full delegation lifecycle",
			operations: func(d *DelegationResolver) {
				initialAmount := d.Get().TotalDelegatedAmount()

				// Undelegate some with lockup
				d.UnDelegate(300, 100, 100, 200)
				uassert.Equal(t, d.DelegatedAmount(), initialAmount-300)

				// Undelegate some without lockup
				d.UnDelegateWithoutLockup(200, 150, 150)
				uassert.Equal(t, d.DelegatedAmount(), initialAmount-500)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(200))

				// Collect locked amount after lockup period
				err := d.Collect(300, 400) // After lockup
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(500))

				// Undelegate and collect remaining
				d.UnDelegateWithoutLockup(500, 500, 500) // Remaining amount
				uassert.Equal(t, d.Get().CollectedAmount(), initialAmount)
				uassert.True(t, d.IsEmpty())
			},
			description: "Should handle complete delegation lifecycle",
		},
		{
			name: "Multiple collections accumulating collected amount",
			operations: func(d *DelegationResolver) {
				// Setup multiple large undelegations
				d.UnDelegate(300_000_000, 100, 100, 100) // 300M
				d.UnDelegate(400_000_000, 150, 150, 100) // 400M
				d.UnDelegate(200_000_000, 200, 200, 100) // 200M

				// After lockup, collect all in sequence
				currentTime := int64(400)

				// First collection
				err := d.Collect(300_000_000, currentTime)
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(300_000_000))

				// Second collection - tests accumulation
				err = d.Collect(400_000_000, currentTime)
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(700_000_000))

				// Third collection - total 900M
				err = d.Collect(200_000_000, currentTime)
				uassert.NoError(t, err)
				uassert.Equal(t, d.Get().CollectedAmount(), int64(900_000_000))
			},
			description: "Should handle large accumulated collections without overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh delegation with sufficient amount
			delegation := NewDelegation(
				1,
				address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				1000,
				50,
				50,
			)

			resolver := NewDelegationResolver(delegation)

			// When: Execute operations
			tt.operations(resolver)

			// Then: Operations should complete successfully
			// Assertions are done within the operations function
		})
	}
}

// Test edge cases and error conditions
func TestDelegation_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		testFunc    func()
		description string
	}{
		{
			name: "Collect with no undelegations should fail",
			testFunc: func() {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)

				resolver := NewDelegationResolver(delegation)
				err := resolver.Collect(100, 200)
				uassert.Error(t, err) // Should fail - nothing to collect
			},
			description: "Should fail when trying to collect with no undelegations",
		},
		{
			name: "Zero amount operations",
			testFunc: func() {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)

				// Zero undelegation
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(0, 200, 200, 100)
				uassert.Equal(t, resolver.Get().UnDelegatedAmount(), int64(0))

				// Zero collection should succeed but do nothing
				err := resolver.Collect(0, 300)
				uassert.NoError(t, err)
				uassert.Equal(t, resolver.Get().CollectedAmount(), int64(0))
			},
			description: "Should handle zero amount operations correctly",
		},
		{
			name: "Collection before lockup expiry",
			testFunc: func() {
				delegation := NewDelegation(
					1,
					address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
					100,
				)

				// Undelegate with long lockup
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 200, 200, 1000000) // Very long lockup

				// Try to collect immediately - should fail or collect nothing
				err := resolver.Collect(300, 250)
				uassert.Error(t, err) // Should fail - lockup not expired
			},
			description: "Should handle collection attempts before lockup expiry",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Execute test function
			tt.testFunc()

			// Then: Test should complete without panicking
			// Assertions are done within the test function
		})
	}
}

// TestDelegation_addToCollectedAmount tests the private addToCollectedAmount function
func TestDelegation_addToCollectedAmount(t *testing.T) {
	tests := []struct {
		name                 string
		collectedAmount      int64
		amount               int64
		expectedResult       int64
		expectedHasError     bool
		expectedHasPanic     bool
		expectedErrorMessage string
	}{
		{
			name:             "add positive amount",
			collectedAmount:  100,
			amount:           50,
			expectedResult:   150,
			expectedHasError: false,
		},
		{
			name:             "add zero amount",
			collectedAmount:  100,
			amount:           0,
			expectedResult:   100,
			expectedHasError: false,
		},
		{
			name:             "add negative amount",
			collectedAmount:  100,
			amount:           -30,
			expectedResult:   0,
			expectedHasError: true,
		},
		{
			name:             "both zero",
			collectedAmount:  0,
			amount:           0,
			expectedResult:   0,
			expectedHasError: false,
		},
		{
			name:             "large values",
			collectedAmount:  9223372036854775000,
			amount:           100,
			expectedResult:   9223372036854775100,
			expectedHasError: false,
		},
		{
			name:                "overflow",
			collectedAmount:      math.MaxInt64, // MaxInt64
			amount:               1,
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedErrorMessage: "int64 addition overflow",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when/then
			if tc.expectedHasPanic {
    			uassert.PanicsWithMessage(t, tc.expectedErrorMessage, func() {
       				addToCollectedAmount(tc.collectedAmount, tc.amount)
    			})
            } else if tc.expectedHasError {
                _, err := addToCollectedAmount(tc.collectedAmount, tc.amount)
				uassert.NotNil(t, err)
			} else {
			    result, err := addToCollectedAmount(tc.collectedAmount, tc.amount)
				uassert.NoError(t, err)
				uassert.Equal(t, result, tc.expectedResult)
			}
		})
	}
}

// TestDelegation_CollectErrors tests error cases for Collect function
func TestDelegation_CollectErrors(t *testing.T) {
	t.Run("Collect amount exceeds collectable", func(t *testing.T) {
		// given
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			1000,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Undelegate and wait for lockup
		resolver.UnDelegate(500, 100, 100, 86400) // 1 day lockup

		// when - try to collect more than collectable (0 at currentTime=100)
		err := resolver.Collect(100, 100) // lockup not passed

		// then
		uassert.NotNil(t, err)
		uassert.Equal(t, err.Error(), "amount to collect is greater than collectable amount")
	})

	t.Run("Collect with negative amount", func(t *testing.T) {
		// given
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			1000,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Undelegate with lockup
		resolver.UnDelegate(500, 100, 100, 86400)

		// when - try to collect negative amount after lockup (treated as no-op)
		currentTime := int64(100 + 86400 + 1)
		collectableBefore := resolver.CollectableAmount(currentTime)
		err := resolver.Collect(-100, currentTime)

		// then - should succeed (negative amount is treated as zero)
		uassert.Nil(t, err)
		uassert.Equal(t, resolver.CollectableAmount(currentTime), collectableBefore) // nothing was collected
	})

	t.Run("Collect exact collectable amount", func(t *testing.T) {
		// given
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			1000,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Undelegate with lockup
		resolver.UnDelegate(500, 100, 100, 86400)

		// when - collect exact collectable amount after lockup passes
		currentTime := int64(100 + 86400 + 1)
		collectableAmount := resolver.CollectableAmount(currentTime)
		err := resolver.Collect(collectableAmount, currentTime)

		// then - should succeed
		uassert.Nil(t, err)
		uassert.Equal(t, resolver.CollectableAmount(currentTime), int64(0))
	})

	t.Run("Collect zero amount", func(t *testing.T) {
		// given
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			1000,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Undelegate without lockup
		resolver.UnDelegateWithoutLockup(500, 100, 100)

		// when - collect zero amount
		err := resolver.Collect(0, 200)

		// then - should succeed (no-op)
		uassert.Nil(t, err)
	})
}

// Test boundary conditions for safe arithmetic in delegation operations
func TestDelegation_BoundaryConditions(t *testing.T) {
	t.Run("DelegatedAmount with large total near max", func(t *testing.T) {
		// given: delegation with very large amount
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			math.MaxInt64/2,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// when: get delegated amount (safeSubInt64 used internally)
		delegatedAmount := resolver.DelegatedAmount()

		// then: should handle large amount correctly
		uassert.Equal(t, delegatedAmount, int64(math.MaxInt64/2))
	})

	t.Run("UnDelegate accumulation causing overflow", func(t *testing.T) {
		// given: delegation with very large total delegated amount
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			math.MaxInt64, // Maximum possible total delegated
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// First undelegate to set UnDelegatedAmount to near max
		resolver.UnDelegate(math.MaxInt64-1000, 100, 100, 500)
		// Now: UnDelegatedAmount = MaxInt64-1000
		//      DelegatedAmount = MaxInt64 - (MaxInt64-1000) = 1000 (valid)

		// when: try to undelegate more causing overflow in safeAddInt64
		didPanic := false
		func() {
			defer func() {
				if r := recover(); r != nil {
					didPanic = true
				}
			}()
			// This should panic in safeAddInt64(UnDelegatedAmount, amount)
			// (MaxInt64-1000) + 1001 would be MaxInt64+1 (overflow!)
			resolver.UnDelegate(1001, 100, 100, 500)
		}()

		// then: should panic on overflow
		uassert.True(t, didPanic)
	})

	t.Run("Collect with amount accumulation near boundary", func(t *testing.T) {
		// given: delegation with large amounts
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			math.MaxInt64/2,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Undelegate large amount with lockup (not immediately collected)
		resolver.UnDelegate(math.MaxInt64/4, 100, 100, 0) // 0 lockup period

		// when: collect large amount (uses safeAddInt64 internally)
		err := resolver.Collect(math.MaxInt64/4, 200)

		// then: should succeed
		uassert.NoError(t, err)
	})
}
