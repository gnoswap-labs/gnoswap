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
			uassert.Equal(t, resolver.Get().Withdraws().Size(), 0)
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
		name                string
		initialAmount       int64
		unDelegateAmount    int64
		currentTime         int64
		lockupPeriod        int64
		expectedUnDelegated int64
	}{
		{
			name:                "Undelegate with standard lockup",
			initialAmount:       1000,
			unDelegateAmount:    300,
			currentTime:         200,
			lockupPeriod:        7 * 24 * 60 * 60, // 7 days
			expectedUnDelegated: 300,
		},
		{
			name:                "Undelegate with zero lockup",
			initialAmount:       1000,
			unDelegateAmount:    500,
			currentTime:         300,
			lockupPeriod:        0,
			expectedUnDelegated: 500,
		},
		{
			name:                "Multiple undelegations",
			initialAmount:       1000,
			unDelegateAmount:    200,
			currentTime:         400,
			lockupPeriod:        3 * 24 * 60 * 60, // 3 days
			expectedUnDelegated: 200,              // First undelegation
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

			// Verify withdraw record created with correct collectableTime
			expectedCollectableTime := tt.currentTime + tt.lockupPeriod
			withdrawsAtTime, exists := resolver.Get().Withdraws().Get(expectedCollectableTime)
			uassert.True(t, exists)

			withdraws, ok := withdrawsAtTime.([]*staker.DelegationWithdraw)
			uassert.True(t, ok)
			uassert.Equal(t, len(withdraws), 1)

			withdraw := withdraws[0]
			uassert.Equal(t, withdraw.DelegationID(), delegation.ID())
			uassert.Equal(t, withdraw.UnDelegateAmount(), tt.unDelegateAmount)
			uassert.Equal(t, withdraw.UnDelegatedAt(), tt.currentTime)
			uassert.Equal(t, withdraw.CollectableTime(), expectedCollectableTime)
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

			// Verify withdraw record created with immediate collectableTime (currentTime)
			withdrawsAtTime, exists := resolver.Get().Withdraws().Get(tt.currentTime)
			uassert.True(t, exists)

			withdraws, ok := withdrawsAtTime.([]*staker.DelegationWithdraw)
			uassert.True(t, ok)
			uassert.Equal(t, len(withdraws), 1)

			withdraw := withdraws[0]
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
				uassert.Equal(t, d.Get().Withdraws().Size(), 1) // One time bucket

				// Second undelegation with 3 day lockup
				d.UnDelegate(150, 200, 200, 3*24*60*60)
				uassert.Equal(t, d.Get().UnDelegatedAmount(), int64(350))
				uassert.Equal(t, d.Get().Withdraws().Size(), 2) // Two time buckets

				// Third undelegation without lockup
				d.UnDelegateWithoutLockup(100, 300, 300)
				uassert.Equal(t, d.Get().UnDelegatedAmount(), int64(450))
				uassert.Equal(t, d.Get().CollectedAmount(), int64(100)) // Immediate collection
				uassert.Equal(t, d.Get().Withdraws().Size(), 3)         // Three time buckets
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

// TestDelegation_WithdrawDeletion tests that fully collected withdraws are removed from the list
func TestDelegation_WithdrawDeletion(t *testing.T) {
	tests := []struct {
		name                    string
		setupDelegation         func() (*staker.Delegation, *DelegationResolver)
		collectAmount           int64
		collectTime             int64
		expectedCollectedAmount int64
		validateRemaining       func(*staker.UintTree)
	}{
		{
			name: "Single withdraw - full collection removes it",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(500, 100, 100, 100)
				return delegation, resolver
			},
			collectAmount:           500,
			collectTime:             300,
			expectedCollectedAmount: 500,
			validateRemaining: func(tree *staker.UintTree) {
				// No withdraws should remain
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "Single withdraw - partial collection keeps it",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(500, 100, 100, 100)
				return delegation, resolver
			},
			collectAmount:           300,
			collectTime:             300,
			expectedCollectedAmount: 300,
			validateRemaining: func(tree *staker.UintTree) {
				// One withdraw should remain
				uassert.Equal(t, tree.Size(), 1)

				// Verify the remaining withdraw state
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 1)
				uassert.Equal(t, allWithdraws[0].UnDelegateAmount(), int64(500))
				uassert.Equal(t, allWithdraws[0].CollectedAmount(), int64(300))
				uassert.False(t, allWithdraws[0].IsCollected())
			},
		},
		{
			name: "Multiple withdraws - full collection removes all",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 100, 100, 100)
				resolver.UnDelegate(200, 150, 150, 100)
				resolver.UnDelegate(100, 200, 200, 100)
				return delegation, resolver
			},
			collectAmount:           600,
			collectTime:             400,
			expectedCollectedAmount: 600,
			validateRemaining: func(tree *staker.UintTree) {
				// No withdraws should remain
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "Multiple withdraws - partial collection removes only fully collected ones",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 100, 100, 100)
				resolver.UnDelegate(200, 150, 150, 100)
				resolver.UnDelegate(100, 200, 200, 100)
				return delegation, resolver
			},
			collectAmount:           550,
			collectTime:             400,
			expectedCollectedAmount: 550,
			validateRemaining: func(tree *staker.UintTree) {
				// One time bucket should remain
				uassert.Equal(t, tree.Size(), 1)

				// Verify the remaining withdraw state
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 1)
				uassert.Equal(t, allWithdraws[0].UnDelegateAmount(), int64(100))
				uassert.Equal(t, allWithdraws[0].CollectedAmount(), int64(50))
				uassert.False(t, allWithdraws[0].IsCollected())
			},
		},
		{
			name: "Withdraw deletion with UnDelegateWithoutLockup",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegateWithoutLockup(500, 100, 100)
				return delegation, resolver
			},
			collectAmount:           0,
			collectTime:             200,
			expectedCollectedAmount: 500,
			validateRemaining: func(tree *staker.UintTree) {
				// Already collected withdraw gets cleaned up
				uassert.Equal(t, tree.Size(), 0)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation
			delegation, resolver := tt.setupDelegation()

			// When: Collect
			err := resolver.Collect(tt.collectAmount, tt.collectTime)

			// Then: Verify results
			uassert.NoError(t, err)
			uassert.Equal(t, resolver.Get().CollectedAmount(), tt.expectedCollectedAmount)

			// Validate remaining withdraw state
			tt.validateRemaining(delegation.Withdraws())
		})
	}
}

// TestDelegation_IsEmptyAfterCleanup tests that IsEmpty() works correctly after withdraw cleanup
func TestDelegation_IsEmptyAfterCleanup(t *testing.T) {
	tests := []struct {
		name            string
		initialAmount   int64
		operations      func(*DelegationResolver)
		expectedIsEmpty bool
		expectedLocked  int64
		expectedSize    int // Expected number of time buckets in withdraw tree
	}{
		{
			name:          "IsEmpty after full collection and cleanup",
			initialAmount: 1000,
			operations: func(r *DelegationResolver) {
				r.UnDelegate(1000, 100, 100, 100)
				err := r.Collect(1000, 300)
				uassert.NoError(t, err)
			},
			expectedIsEmpty: true,
			expectedLocked:  0,
			expectedSize:    0,
		},
		{
			name:          "Not empty after partial collection",
			initialAmount: 1000,
			operations: func(r *DelegationResolver) {
				r.UnDelegate(1000, 100, 100, 100)
				err := r.Collect(500, 300)
				uassert.NoError(t, err)
			},
			expectedIsEmpty: false,
			expectedLocked:  500,
			expectedSize:    1,
		},
		{
			name:          "IsEmpty progression through multiple operations",
			initialAmount: 600,
			operations: func(r *DelegationResolver) {
				r.UnDelegate(200, 100, 100, 100)
				r.UnDelegate(400, 150, 150, 100)
				uassert.False(t, r.IsEmpty())
				uassert.Equal(t, r.LockedAmount(), int64(600))

				err1 := r.Collect(200, 300)
				uassert.NoError(t, err1)
				uassert.False(t, r.IsEmpty())
				uassert.Equal(t, r.LockedAmount(), int64(400))
				uassert.Equal(t, r.Get().Withdraws().Size(), 1)

				err2 := r.Collect(400, 300)
				uassert.NoError(t, err2)
			},
			expectedIsEmpty: true,
			expectedLocked:  0,
			expectedSize:    0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh delegation with specified initial amount
			delegation := NewDelegation(
				1,
				address("g1delegator"),
				address("g1validator"),
				tt.initialAmount,
				100,
				100,
			)
			resolver := NewDelegationResolver(delegation)

			// When: Execute operations
			tt.operations(resolver)

			// Then: Verify final state
			uassert.Equal(t, resolver.IsEmpty(), tt.expectedIsEmpty)
			uassert.Equal(t, resolver.LockedAmount(), tt.expectedLocked)
			uassert.Equal(t, resolver.Get().Withdraws().Size(), tt.expectedSize)
		})
	}
}

// TestDelegation_WithdrawCleanupEdgeCases tests edge cases for withdraw cleanup
func TestDelegation_WithdrawCleanupEdgeCases(t *testing.T) {
	tests := []struct {
		name                    string
		setupDelegation         func() (*staker.Delegation, *DelegationResolver)
		collectAmount           int64
		collectTime             int64
		expectedCollectedAmount int64
		validateRemaining       func(*staker.UintTree)
	}{
		{
			name: "No withdraws - cleanup is no-op",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				return delegation, resolver
			},
			collectAmount:           0,
			collectTime:             200,
			expectedCollectedAmount: 0,
			validateRemaining: func(tree *staker.UintTree) {
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "All withdraws already collected - get cleaned up",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegateWithoutLockup(500, 100, 100)
				return delegation, resolver
			},
			collectAmount:           0,
			collectTime:             200,
			expectedCollectedAmount: 500,
			validateRemaining: func(tree *staker.UintTree) {
				// Already collected withdraw gets cleaned up
				uassert.Equal(t, tree.Size(), 0)
			},
		},
		{
			name: "Mixed lockup periods - cleanup respects collectability",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				resolver.UnDelegate(300, 100, 100, 100)
				resolver.UnDelegate(200, 150, 150, 10000)
				return delegation, resolver
			},
			collectAmount:           300,
			collectTime:             300,
			expectedCollectedAmount: 300,
			validateRemaining: func(tree *staker.UintTree) {
				uassert.Equal(t, tree.Size(), 1)

				// Verify remaining withdraw state
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 1)
				uassert.Equal(t, allWithdraws[0].UnDelegateAmount(), int64(200))
				uassert.Equal(t, allWithdraws[0].CollectedAmount(), int64(0))
			},
		},
		{
			name: "Large number of withdraws - all get cleaned up",
			setupDelegation: func() (*staker.Delegation, *DelegationResolver) {
				delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 10000, 100, 100)
				resolver := NewDelegationResolver(delegation)
				for i := 0; i < 10; i++ {
					resolver.UnDelegate(100, 100+int64(i*10), 100+int64(i*10), 100)
				}
				return delegation, resolver
			},
			collectAmount:           1000,
			collectTime:             400,
			expectedCollectedAmount: 1000,
			validateRemaining: func(tree *staker.UintTree) {
				// All withdraws should be cleaned up
				uassert.Equal(t, tree.Size(), 0)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation
			delegation, resolver := tt.setupDelegation()

			// When: Collect
			err := resolver.Collect(tt.collectAmount, tt.collectTime)

			// Then: Verify results
			uassert.NoError(t, err)
			uassert.Equal(t, resolver.Get().CollectedAmount(), tt.expectedCollectedAmount)

			// Validate remaining withdraw state
			tt.validateRemaining(delegation.Withdraws())
		})
	}
}

// TestDelegation_TimeBasedGrouping tests that withdraws are correctly grouped by collectableTime
func TestDelegation_TimeBasedGrouping(t *testing.T) {
	tests := []struct {
		name              string
		setupWithdraws    func(*staker.Delegation, *DelegationResolver)
		expectedTimeCount int // Number of distinct time buckets
		validateGrouping  func(*staker.UintTree)
	}{
		{
			name: "Multiple withdraws with same collectableTime - grouped together",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				// All undelegations at same time with same lockup = same collectableTime
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(200, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(300, 100, 100, 100) // collectableTime = 200
			},
			expectedTimeCount: 1, // All in one time bucket
			validateGrouping: func(tree *staker.UintTree) {
				// Collect all withdraws from tree
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 3)
				// All should have same collectableTime
				uassert.Equal(t, allWithdraws[0].CollectableTime(), int64(200))
				uassert.Equal(t, allWithdraws[1].CollectableTime(), int64(200))
				uassert.Equal(t, allWithdraws[2].CollectableTime(), int64(200))
			},
		},
		{
			name: "Withdraws with different collectableTimes - separate buckets",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
				resolver.UnDelegate(100, 200, 200, 200) // collectableTime = 400
			},
			expectedTimeCount: 3, // Three distinct time buckets
			validateGrouping: func(tree *staker.UintTree) {
				// Collect all withdraws from tree
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 3)
				uassert.Equal(t, allWithdraws[0].CollectableTime(), int64(200))
				uassert.Equal(t, allWithdraws[1].CollectableTime(), int64(300))
				uassert.Equal(t, allWithdraws[2].CollectableTime(), int64(400))
			},
		},
		{
			name: "Mixed - some same, some different collectableTimes",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(200, 100, 100, 100) // collectableTime = 200 (same as first)
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
				resolver.UnDelegate(50, 150, 150, 150)  // collectableTime = 300 (same as third)
			},
			expectedTimeCount: 2, // Two time buckets: 200 and 300
			validateGrouping: func(tree *staker.UintTree) {
				// Collect all withdraws from tree
				allWithdraws := make([]*staker.DelegationWithdraw, 0)
				tree.Iterate(0, math.MaxInt64, func(time int64, value any) bool {
					if ws, ok := value.([]*staker.DelegationWithdraw); ok {
						allWithdraws = append(allWithdraws, ws...)
					}
					return false
				})
				uassert.Equal(t, len(allWithdraws), 4)
				// First two should be collectableTime=200
				uassert.Equal(t, allWithdraws[0].CollectableTime(), int64(200))
				uassert.Equal(t, allWithdraws[1].CollectableTime(), int64(200))
				// Last two should be collectableTime=300
				uassert.Equal(t, allWithdraws[2].CollectableTime(), int64(300))
				uassert.Equal(t, allWithdraws[3].CollectableTime(), int64(300))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create delegation and setup withdraws
			delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
			resolver := NewDelegationResolver(delegation)
			tt.setupWithdraws(delegation, resolver)

			// When: Get all withdraws
			withdraws := delegation.Withdraws()

			// Then: Validate grouping
			tt.validateGrouping(withdraws)

			// Verify time bucket count by iterating
			timeCount := 0
			delegation.Withdraws().Iterate(0, math.MaxInt64, func(time int64, value any) bool {
				timeCount++
				return false
			})
			uassert.Equal(t, timeCount, tt.expectedTimeCount)
		})
	}
}

// TestDelegation_RangeIterationBoundary tests that range iteration correctly filters by time
func TestDelegation_RangeIterationBoundary(t *testing.T) {
	tests := []struct {
		name                 string
		setupWithdraws       func(*staker.Delegation, *DelegationResolver)
		iterateEndTime       int64
		expectedIterateCount int // Number of withdraws that should be iterated
	}{
		{
			name: "End time exclusive - collectableTime == endTime not included",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
				resolver.UnDelegate(100, 200, 200, 200) // collectableTime = 400
			},
			iterateEndTime:       300, // Should NOT include collectableTime=300
			expectedIterateCount: 1,   // Only collectableTime=200
		},
		{
			name: "End time larger - includes all before",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
				resolver.UnDelegate(100, 200, 200, 200) // collectableTime = 400
			},
			iterateEndTime:       500, // Should include all three
			expectedIterateCount: 3,
		},
		{
			name: "End time before all - no iteration",
			setupWithdraws: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
			},
			iterateEndTime:       200, // Before all collectableTimes
			expectedIterateCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create delegation and setup withdraws
			delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
			resolver := NewDelegationResolver(delegation)
			tt.setupWithdraws(delegation, resolver)

			// When: Iterate with end time
			actualCount := 0
			delegation.Withdraws().Iterate(0, tt.iterateEndTime, func(time int64, value any) bool {
				if ws, ok := value.([]*staker.DelegationWithdraw); ok {
					actualCount += len(ws)
				}
				return false
			})

			// Then: Verify count matches expected
			uassert.Equal(t, actualCount, tt.expectedIterateCount)
		})
	}
}

// TestDelegation_TimeBucketManagement tests that time buckets are correctly managed during operations
func TestDelegation_TimeBucketManagement(t *testing.T) {
	tests := []struct {
		name                    string
		setupAndCollect         func(*staker.Delegation, *DelegationResolver)
		expectedRemainingBucket int // Number of time buckets remaining
	}{
		{
			name: "Partial collection - bucket remains with remaining withdraws",
			setupAndCollect: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				// Create 3 withdraws with same collectableTime
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200

				// Partially collect - only 2 out of 3
				resolver.Collect(200, 300)
			},
			expectedRemainingBucket: 1, // Bucket still exists with 1 remaining withdraw
		},
		{
			name: "Full collection of one bucket - bucket removed",
			setupAndCollect: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200

				// Fully collect this time bucket
				resolver.Collect(200, 300)
			},
			expectedRemainingBucket: 0, // Bucket fully collected and removed
		},
		{
			name: "Collect from multiple buckets - only collected ones removed",
			setupAndCollect: func(delegation *staker.Delegation, resolver *DelegationResolver) {
				resolver.UnDelegate(100, 100, 100, 100) // collectableTime = 200
				resolver.UnDelegate(100, 150, 150, 150) // collectableTime = 300
				resolver.UnDelegate(100, 200, 200, 200) // collectableTime = 400

				// Collect only from first two buckets (time 200 and 300)
				resolver.Collect(200, 350) // currentTime=350 includes 200,300 but not 400
			},
			expectedRemainingBucket: 1, // Only bucket at time=400 remains
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given & When: Setup and collect
			delegation := NewDelegation(1, address("g1delegator"), address("g1validator"), 1000, 100, 100)
			resolver := NewDelegationResolver(delegation)
			tt.setupAndCollect(delegation, resolver)

			// Then: Count remaining buckets
			bucketCount := 0
			delegation.Withdraws().Iterate(0, math.MaxInt64, func(time int64, value any) bool {
				bucketCount++
				return false
			})

			uassert.Equal(t, bucketCount, tt.expectedRemainingBucket)
		})
	}
}

// TestDelegation_CollectableAmountIterationRange tests that CollectableAmount only iterates
// up to currentTime and excludes future withdraws
func TestDelegation_CollectableAmountIterationRange(t *testing.T) {
	tests := []struct {
		name                     string
		setupWithdraws           func(*DelegationResolver)
		currentTime              int64
		expectedCollectableTotal int64
		description              string
	}{
		{
			name: "Future withdraws excluded - collectableTime > currentTime",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 100 + 50 = 150
				resolver.UnDelegate(100, 100, 100, 50)
				// collectableTime = 200 + 100 = 300
				resolver.UnDelegate(200, 200, 200, 100)
				// collectableTime = 300 + 200 = 500
				resolver.UnDelegate(300, 300, 300, 200)
			},
			currentTime:              250, // Only first should be collectable (150 <= 250 < 300)
			expectedCollectableTotal: 100, // Only first withdraw
			description:              "Should exclude withdraws with collectableTime > currentTime (300, 500)",
		},
		{
			name: "Exact currentTime included - collectableTime == currentTime",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 100 + 100 = 200
				resolver.UnDelegate(100, 100, 100, 100)
				// collectableTime = 150 + 50 = 200 (same as first)
				resolver.UnDelegate(150, 150, 150, 50)
				// collectableTime = 200 + 100 = 300
				resolver.UnDelegate(200, 200, 200, 100)
			},
			currentTime:              200, // First two are collectable (time=200), third is not (time=300)
			expectedCollectableTotal: 250, // 100 + 150
			description:              "Should include withdraws with collectableTime == currentTime",
		},
		{
			name: "All past - all withdraws collectable",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 100 + 50 = 150
				resolver.UnDelegate(100, 100, 100, 50)
				// collectableTime = 120 + 30 = 150
				resolver.UnDelegate(200, 120, 120, 30)
				// collectableTime = 140 + 10 = 150
				resolver.UnDelegate(300, 140, 140, 10)
			},
			currentTime:              1000, // All are in the past
			expectedCollectableTotal: 600,  // 100 + 200 + 300
			description:              "Should include all withdraws when currentTime is far in future",
		},
		{
			name: "All future - no withdraws collectable",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 500 + 100 = 600
				resolver.UnDelegate(100, 500, 500, 100)
				// collectableTime = 600 + 200 = 800
				resolver.UnDelegate(200, 600, 600, 200)
			},
			currentTime:              100, // All are in the future
			expectedCollectableTotal: 0,
			description:              "Should return 0 when all withdraws are in future",
		},
		{
			name: "Mixed with zero lockup - immediate collectability",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 100 + 0 = 100 (no lockup)
				resolver.UnDelegate(100, 100, 100, 0)
				// collectableTime = 150 + 100 = 250
				resolver.UnDelegate(200, 150, 150, 100)
				// collectableTime = 200 + 200 = 400
				resolver.UnDelegate(300, 200, 200, 200)
			},
			currentTime:              250,
			expectedCollectableTotal: 300, // First two: 100 (time=100) + 200 (time=250)
			description:              "Should handle mix of zero and non-zero lockup periods",
		},
		{
			name: "Boundary - currentTime exactly between two withdraws",
			setupWithdraws: func(resolver *DelegationResolver) {
				// collectableTime = 100 + 99 = 199
				resolver.UnDelegate(100, 100, 100, 99)
				// collectableTime = 100 + 100 = 200
				resolver.UnDelegate(200, 100, 100, 100)
				// collectableTime = 100 + 101 = 201
				resolver.UnDelegate(300, 100, 100, 101)
			},
			currentTime:              200, // Exactly at second withdraw time
			expectedCollectableTotal: 300, // First two: 100 (time=199) + 200 (time=200)
			description:              "Should include withdraw at exact currentTime boundary",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create delegation with large initial amount
			delegation := NewDelegation(
				1,
				address("g1delegator"),
				address("g1validator"),
				10000, // Large enough for all test cases
				50,
				50,
			)
			resolver := NewDelegationResolver(delegation)

			// When: Setup withdraws
			tt.setupWithdraws(resolver)

			// Then: CollectableAmount should only count withdraws up to currentTime
			collectableAmount := resolver.CollectableAmount(tt.currentTime)
			uassert.Equal(t, collectableAmount, tt.expectedCollectableTotal)

			// Verify: Manually count withdraws that should be included
			// This verifies the iteration range is correct
			manualTotal := int64(0)
			delegation.Withdraws().Iterate(0, tt.currentTime+1, func(time int64, value any) bool {
				if withdraws, ok := value.([]*staker.DelegationWithdraw); ok {
					for _, w := range withdraws {
						wResolver := NewDelegationWithdrawResolver(w)
						manualTotal = safeAddInt64(manualTotal, wResolver.CollectableAmount(tt.currentTime))
					}
				}
				return false
			})
			uassert.Equal(t, manualTotal, tt.expectedCollectableTotal)
		})
	}
}

// TestDelegation_CollectableAmountDoesNotIterateFuture verifies that CollectableAmount
// does not waste gas iterating over future withdraws
func TestDelegation_CollectableAmountDoesNotIterateFuture(t *testing.T) {
	t.Run("Many future withdraws do not affect CollectableAmount", func(t *testing.T) {
		// Given: Delegation with one past withdraw and many future withdraws
		delegation := NewDelegation(
			1,
			address("g1delegator"),
			address("g1validator"),
			100000,
			100,
			100,
		)
		resolver := NewDelegationResolver(delegation)

		// Add one withdraw that is collectable
		resolver.UnDelegate(100, 100, 100, 50) // collectableTime = 150

		// Add many future withdraws (these should NOT be iterated)
		for i := 0; i < 100; i++ {
			// collectableTime = 1000 + (i * 100) + lockup
			resolver.UnDelegate(100, 1000+int64(i*100), 1000+int64(i*100), 1000)
		}

		// When: Check collectable amount at time 200
		currentTime := int64(200)
		collectableAmount := resolver.CollectableAmount(currentTime)

		// Then: Should only include the first withdraw (100)
		// The 100 future withdraws should be skipped entirely
		uassert.Equal(t, collectableAmount, int64(100))

		// Verify: Count actual withdraws to ensure we created them
		totalWithdrawCount := 0
		delegation.Withdraws().Iterate(0, math.MaxInt64, func(time int64, value any) bool {
			if withdraws, ok := value.([]*staker.DelegationWithdraw); ok {
				totalWithdrawCount += len(withdraws)
			}
			return false
		})
		uassert.Equal(t, totalWithdrawCount, 101) // 1 past + 100 future

		// Verify: Only 1 withdraw should be checked (not all 101)
		iteratedCount := 0
		delegation.Withdraws().Iterate(0, currentTime+1, func(time int64, value any) bool {
			if withdraws, ok := value.([]*staker.DelegationWithdraw); ok {
				iteratedCount += len(withdraws)
			}
			return false
		})
		uassert.Equal(t, iteratedCount, 1) // Only the past withdraw
	})
}
