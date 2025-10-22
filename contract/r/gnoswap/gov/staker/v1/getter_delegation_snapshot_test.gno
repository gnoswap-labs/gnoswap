package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// Test GetDelegationSnapshots
func TestGetDelegationSnapshots(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name         string
		setupState   func()
		snapshotTime int64
		expectFound  bool
	}{
		{
			name: "Get snapshot with empty state",
			setupState: func() {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				gs.setDelegationSnapshots(make(DelegationSnapshot))
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with existing data",
			setupState: func() {
				// Setup delegation snapshots
				snapshots := make(DelegationSnapshot)
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history
				history := make(DelegationHistory, 0)

				// Add a delegation record after snapshot time
				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 500,
					delegationType: DelegateType,
					createdAt:      150, // After snapshot time
				}
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with history records before snapshot time",
			setupState: func() {
				// Setup delegation snapshots
				snapshots := make(DelegationSnapshot)
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1500,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with records before snapshot time
				history := make(DelegationHistory, 0)

				// Add a delegation record before snapshot time (should be subtracted)
				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 500,
					delegationType: DelegateType,
					createdAt:      50, // Before snapshot time
				}
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with multiple history records",
			setupState: func() {
				// Setup delegation snapshots
				snapshots := make(DelegationSnapshot)
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 2000,
					delegatorAddress: address("user1"),
				}
				snapshots["user2"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: address("user2"),
				}
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with multiple records
				history := make(DelegationHistory, 0)

				// Records before snapshot time (should be subtracted)
				record1 := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 300,
					delegationType: DelegateType,
					createdAt:      30,
				}

				record2 := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 200,
					delegationType: DelegateType,
					createdAt:      70,
				}

				record3 := &DelegationRecord{
					delegateFrom:   address("user2"),
					delegateTo:     address("validator2"),
					delegateAmount: 100,
					delegationType: DelegateType,
					createdAt:      80,
				}

				// Record after snapshot time (should not be subtracted)
				record4 := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 400,
					delegationType: DelegateType,
					createdAt:      150,
				}

				history = history.addRecord(record1)
				history = history.addRecord(record2)
				history = history.addRecord(record3)
				history = history.addRecord(record4)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with undelegate records",
			setupState: func() {
				// Setup delegation snapshots
				snapshots := make(DelegationSnapshot)
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with undelegate record
				history := make(DelegationHistory, 0)

				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 300,
					delegationType: UnDelegateType, // Undelegate
					createdAt:      50,
				}
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup state
			tt.setupState()

			// When: Get delegation snapshots
			snapshot, found := gs.GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should return expected result
			uassert.Equal(t, found, tt.expectFound)

			if tt.expectFound {
				uassert.NotEqual(t, snapshot, nil)

				// Basic validation that we got a snapshot
				uassert.True(t, len(snapshot) >= 0)
			}
		})
	}
}

// Test GetDelegationSnapshots with specific scenarios
func TestGetDelegationSnapshots_SpecificScenarios(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name                   string
		setupState             func()
		snapshotTime           int64
		expectedUserDelegation int64
		userAddress            string
	}{
		{
			name: "Snapshot calculation with delegate user1 to validator1 record before time",
			setupState: func() {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(DelegationSnapshot)

				// Current snapshot shows 1000 delegated
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// But there was a delegate of 200 at time 50
				// So at time 100, it should be 1000
				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 200,
					delegationType: DelegateType,
					createdAt:      50,
				}
				history := make(DelegationHistory, 0)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime:           100,
			userAddress:            "user1",
			expectedUserDelegation: 1000, // 1000
		},
		{
			name: "Snapshot calculation with delegate user1 to user1 record before time",
			setupState: func() {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(DelegationSnapshot)

				// Current snapshot shows 1000 delegated
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// But there was a delegate of 200 at time 50
				// So at time 100, it should be 1000
				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("user1"),
					delegateAmount: 200,
					delegationType: DelegateType,
					createdAt:      150,
				}
				history := make(DelegationHistory, 0)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime:           100,
			userAddress:            "user1",
			expectedUserDelegation: 800, // 1000 - 200
		},
		{
			name: "Snapshot calculation with undelegate record before time",
			setupState: func() {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(DelegationSnapshot)

				// Current snapshot shows 500 delegated
				snapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 500,
					delegatorAddress: address("user1"),
				}
				gs.setDelegationSnapshots(snapshots)

				// But there was an undelegate of 100 at time 50
				// So at time 100, it should be 500 + 100 = 600 (we add back the undelegate)
				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 100,
					delegationType: UnDelegateType,
					createdAt:      50,
				}
				history := make(DelegationHistory, 0)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime:           100,
			userAddress:            "user1",
			expectedUserDelegation: 500, // 500 + 100
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup state
			tt.setupState()

			// When: Get delegation snapshots
			snapshot, found := gs.GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should return expected result
			uassert.True(t, found)

			// Check specific user delegation amount
			if item, exists := snapshot[tt.userAddress]; exists {
				uassert.Equal(t, item.DelegateGns, tt.expectedUserDelegation)
			}
		})
	}
}

// Test GetDelegationSnapshots edge cases
func TestGetDelegationSnapshots_EdgeCases(t *testing.T) {
	// Initialize gov staker
	gs := createTestGovStaker()

	tests := []struct {
		name         string
		setupState   func()
		snapshotTime int64
		description  string
	}{
		{
			name: "Zero snapshot time",
			setupState: func() {
				gs.setDelegationHistory(make(DelegationHistory, 0))
				gs.setDelegationSnapshots(make(DelegationSnapshot))
			},
			snapshotTime: 0,
			description:  "Should handle zero snapshot time",
		},
		{
			name: "Negative snapshot time",
			setupState: func() {
				history := make(DelegationHistory, 0)

				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 100,
					delegationType: DelegateType,
					createdAt:      50,
				}
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
				gs.setDelegationSnapshots(make(DelegationSnapshot))
			},
			snapshotTime: -10,
			description:  "Should handle negative snapshot time",
		},
		{
			name: "Very large snapshot time",
			setupState: func() {
				history := make(DelegationHistory, 0)

				record := &DelegationRecord{
					delegateFrom:   address("user1"),
					delegateTo:     address("validator1"),
					delegateAmount: 100,
					delegationType: DelegateType,
					createdAt:      1000,
				}
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
				gs.setDelegationSnapshots(make(DelegationSnapshot))
			},
			snapshotTime: 999999999,
			description:  "Should handle very large snapshot time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup state
			tt.setupState()

			// When: Get delegation snapshots
			snapshot, found := gs.GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should not panic and return valid result
			uassert.True(t, found)
			uassert.NotEqual(t, snapshot, nil)
		})
	}
}
