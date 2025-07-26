package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// Test DelegationType
func TestDelegationType(t *testing.T) {
	tests := []struct {
		name                 string
		delegationType       DelegationType
		expectedString       string
		expectedIsDelegate   bool
		expectedIsUnDelegate bool
	}{
		{
			name:                 "DelegateType functionality",
			delegationType:       DelegateType,
			expectedString:       "DELEGATE",
			expectedIsDelegate:   true,
			expectedIsUnDelegate: false,
		},
		{
			name:                 "UnDelegateType functionality",
			delegationType:       UnDelegateType,
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
		delegateFrom   std.Address
		delegateTo     std.Address
		delegateAmount int64
		createdAt      int64
	}{
		{
			name:           "Create new delegation",
			id:             1,
			delegateFrom:   std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
			delegateTo:     std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
			delegateAmount: 1000,
			createdAt:      100,
		},
		{
			name:           "Create delegation with zero amount",
			id:             2,
			delegateFrom:   std.Address("g1w8m4s75k9l6n8vc6fmpcprgey4ck233kfhx5tz"),
			delegateTo:     std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
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
				tt.createdAt,
			)

			// Then: Should initialize correctly
			uassert.NotEqual(t, delegation, nil)
			uassert.Equal(t, delegation.ID(), tt.id)
			uassert.Equal(t, delegation.DelegateFrom(), tt.delegateFrom)
			uassert.Equal(t, delegation.DelegateTo(), tt.delegateTo)
			uassert.Equal(t, delegation.TotalDelegatedAmount(), tt.delegateAmount)
			uassert.Equal(t, delegation.DelegatedAmount(), tt.delegateAmount)
			uassert.Equal(t, delegation.LockedAmount(), tt.delegateAmount)
			uassert.Equal(t, delegation.UnDelegatedAmount(), int64(0))
			uassert.Equal(t, delegation.CollectedAmount(), int64(0))
			uassert.Equal(t, delegation.CreatedAt(), tt.createdAt)
			uassert.Equal(t, delegation.CollectableAmount(tt.createdAt), int64(0))
			uassert.Equal(t, delegation.IsEmpty(), tt.delegateAmount == 0)
			uassert.Equal(t, len(delegation.withdraws), 0)
		})
	}
}

// Test delegation getter methods
func TestDelegationGetters(t *testing.T) {
	tests := []struct {
		name                   string
		setupDelegation        func() *Delegation
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
			setupDelegation: func() *Delegation {
				return NewDelegation(
					1,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
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
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					2,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)
				delegation.unDelegate(300, 200, 7*24*60*60) // 7 days lockup
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
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					3,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)
				delegation.unDelegateWithoutLockup(200, 150)
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
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					4,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					500,
					100,
				)
				delegation.unDelegateWithoutLockup(500, 150) // Undelegate all without lockup
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
			uassert.Equal(t, delegation.TotalDelegatedAmount(), tt.expectedTotalDelegated)
			uassert.Equal(t, delegation.DelegatedAmount(), tt.expectedDelegated)
			uassert.Equal(t, delegation.LockedAmount(), tt.expectedLocked)
			uassert.Equal(t, delegation.UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, delegation.CollectedAmount(), tt.expectedCollected)
			uassert.Equal(t, delegation.CollectableAmount(tt.currentTime), tt.expectedCollectable)
			uassert.Equal(t, delegation.IsEmpty(), tt.expectedIsEmpty)
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
				std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				tt.initialAmount,
				100,
			)

			// When: Undelegate
			delegation.unDelegate(tt.unDelegateAmount, tt.currentTime, tt.lockupPeriod)

			// Then: Should update state correctly
			uassert.Equal(t, delegation.UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, len(delegation.withdraws), tt.expectedWithdrawCount)

			// Verify withdraw record
			if len(delegation.withdraws) > 0 {
				withdraw := delegation.withdraws[0]
				uassert.Equal(t, withdraw.delegationID, delegation.ID())
				uassert.Equal(t, withdraw.unDelegateAmount, tt.unDelegateAmount)
				uassert.Equal(t, withdraw.unDelegatedAt, tt.currentTime)
			}
		})
	}
}

// Test unDelegateWithoutLockup
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
				std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				tt.initialAmount,
				100,
			)

			// When: Undelegate without lockup
			delegation.unDelegateWithoutLockup(tt.unDelegateAmount, tt.currentTime)

			// Then: Should update state correctly
			uassert.Equal(t, delegation.UnDelegatedAmount(), tt.expectedUnDelegated)
			uassert.Equal(t, delegation.CollectedAmount(), tt.expectedCollected)
			uassert.Equal(t, len(delegation.withdraws), 1)

			// Verify withdraw record is immediately collectable
			withdraw := delegation.withdraws[0]
			uassert.False(t, withdraw.IsCollectable(tt.currentTime))
			uassert.Equal(t, withdraw.CollectableAmount(tt.currentTime), int64(0)) // Already collected
		})
	}
}

// Test collect
func TestDelegation_collect(t *testing.T) {
	tests := []struct {
		name              string
		setupDelegation   func() *Delegation
		collectAmount     int64
		currentTime       int64
		expectError       bool
		expectedCollected int64
	}{
		{
			name: "Collect from delegation with collectable amount",
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					1,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)
				// Undelegate with lockup that has passed
				delegation.unDelegate(300, 200, 100) // Short lockup for testing
				return delegation
			},
			collectAmount:     300,
			currentTime:       400, // After lockup period
			expectError:       false,
			expectedCollected: 300,
		},
		{
			name: "Collect more than collectable amount",
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					2,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)
				delegation.unDelegate(200, 200, 100)
				return delegation
			},
			collectAmount: 500, // More than available
			currentTime:   400,
			expectError:   true,
		},
		{
			name: "Collect partial amount",
			setupDelegation: func() *Delegation {
				delegation := NewDelegation(
					3,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)
				delegation.unDelegate(500, 200, 100)
				return delegation
			},
			collectAmount:     300, // Partial collection
			currentTime:       400,
			expectError:       false,
			expectedCollected: 300,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup delegation
			delegation := tt.setupDelegation()
			initialCollected := delegation.CollectedAmount()

			// When: Collect
			err := delegation.collect(tt.collectAmount, tt.currentTime)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, delegation.CollectedAmount(), initialCollected+tt.expectedCollected)
			}
		})
	}
}

// Test complex delegation scenarios
func TestDelegation_ComplexScenarios(t *testing.T) {
	tests := []struct {
		name        string
		operations  func(*Delegation)
		description string
	}{
		{
			name: "Multiple undelegations with different lockup periods",
			operations: func(d *Delegation) {
				// First undelegation with 7 day lockup
				d.unDelegate(200, 100, 7*24*60*60)
				uassert.Equal(t, d.UnDelegatedAmount(), int64(200))
				uassert.Equal(t, len(d.withdraws), 1)

				// Second undelegation with 3 day lockup
				d.unDelegate(150, 200, 3*24*60*60)
				uassert.Equal(t, d.UnDelegatedAmount(), int64(350))
				uassert.Equal(t, len(d.withdraws), 2)

				// Third undelegation without lockup
				d.unDelegateWithoutLockup(100, 300)
				uassert.Equal(t, d.UnDelegatedAmount(), int64(450))
				uassert.Equal(t, d.CollectedAmount(), int64(100)) // Immediate collection
				uassert.Equal(t, len(d.withdraws), 3)
			},
			description: "Should handle multiple undelegations with different lockup periods",
		},
		{
			name: "Partial collections from multiple withdraws",
			operations: func(d *Delegation) {
				// Setup multiple undelegations
				d.unDelegate(300, 100, 100) // Short lockup
				d.unDelegate(200, 150, 50)  // Very short lockup

				// After sufficient time, both should be collectable
				currentTime := int64(400)

				// Collect partially
				err := d.collect(250, currentTime)
				uassert.NoError(t, err)
				uassert.Equal(t, d.CollectedAmount(), int64(250))

				// Collect remaining
				err = d.collect(250, currentTime+100)
				uassert.NoError(t, err)
				uassert.Equal(t, d.CollectedAmount(), int64(500))
			},
			description: "Should handle partial collections from multiple withdrawals",
		},
		{
			name: "Full delegation lifecycle",
			operations: func(d *Delegation) {
				initialAmount := d.TotalDelegatedAmount()

				// Undelegate some with lockup
				d.unDelegate(300, 100, 200)
				uassert.Equal(t, d.DelegatedAmount(), initialAmount-300)

				// Undelegate some without lockup
				d.unDelegateWithoutLockup(200, 150)
				uassert.Equal(t, d.DelegatedAmount(), initialAmount-500)
				uassert.Equal(t, d.CollectedAmount(), int64(200))

				// Collect locked amount after lockup period
				err := d.collect(300, 400) // After lockup
				uassert.NoError(t, err)
				uassert.Equal(t, d.CollectedAmount(), int64(500))

				// Undelegate and collect remaining
				d.unDelegateWithoutLockup(500, 500) // Remaining amount
				uassert.Equal(t, d.CollectedAmount(), initialAmount)
				uassert.True(t, d.IsEmpty())
			},
			description: "Should handle complete delegation lifecycle",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh delegation with sufficient amount
			delegation := NewDelegation(
				1,
				std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
				std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
				1000,
				50,
			)

			// When: Execute operations
			tt.operations(delegation)

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
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)

				err := delegation.collect(100, 200)
				uassert.Error(t, err) // Should fail - nothing to collect
			},
			description: "Should fail when trying to collect with no undelegations",
		},
		{
			name: "Zero amount operations",
			testFunc: func() {
				delegation := NewDelegation(
					1,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)

				// Zero undelegation
				delegation.unDelegate(0, 200, 100)
				uassert.Equal(t, delegation.UnDelegatedAmount(), int64(0))

				// Zero collection should succeed but do nothing
				err := delegation.collect(0, 300)
				uassert.NoError(t, err)
				uassert.Equal(t, delegation.CollectedAmount(), int64(0))
			},
			description: "Should handle zero amount operations correctly",
		},
		{
			name: "Collection before lockup expiry",
			testFunc: func() {
				delegation := NewDelegation(
					1,
					std.Address("g1u7y667z64x2h7vc6fmpcprgey4ck233jaww9zq"),
					std.Address("g1v7n2w36m8q5p9vc6fmpcprgey4ck233jdgw3kl"),
					1000,
					100,
				)

				// Undelegate with long lockup
				delegation.unDelegate(300, 200, 1000000) // Very long lockup

				// Try to collect immediately - should fail or collect nothing
				err := delegation.collect(300, 250)
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
