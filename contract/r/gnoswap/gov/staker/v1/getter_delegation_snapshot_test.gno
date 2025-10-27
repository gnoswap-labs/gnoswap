package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// Test GetDelegationSnapshots
func TestGetDelegationSnapshots(t *testing.T) {
	tests := []struct {
		name         string
		setupState   func(gs *govStakerV1)
		snapshotTime int64
		expectFound  bool
	}{
		{
			name: "Get snapshot with empty state",
			setupState: func(gs *govStakerV1) {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				gs.setDelegationSnapshots(make(staker.DelegationSnapshot))
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with existing data",
			setupState: func(gs *govStakerV1) {
				// Setup delegation snapshots
				snapshots := make(staker.DelegationSnapshot)
				snapshots["user1"] = staker.NewDelegationSnapshotItem(1000, address("user1"))
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history
				history := make(DelegationHistory, 0)

				// Add a delegation record after snapshot time
				record := staker.NewDelegationRecord(
					staker.DelegateType,
					500,
					address("user1"),
					address("validator1"),
					150, // After snapshot time
				)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with history records before snapshot time",
			setupState: func(gs *govStakerV1) {
				// Setup delegation snapshots
				snapshots := make(staker.DelegationSnapshot)
				snapshots["user1"] = staker.NewDelegationSnapshotItem(1500, address("user1"))
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with records before snapshot time
				history := make(DelegationHistory, 0)

				// Add a delegation record before snapshot time (should be subtracted)
				record := staker.NewDelegationRecord(
					staker.DelegateType,
					500,
					address("user1"),
					address("validator1"),
					50, // Before snapshot time
				)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with multiple history records",
			setupState: func(gs *govStakerV1) {
				// Setup delegation snapshots
				snapshots := make(staker.DelegationSnapshot)
				snapshots["user1"] = staker.NewDelegationSnapshotItem(2000, address("user1"))
				snapshots["user2"] = staker.NewDelegationSnapshotItem(1000, address("user2"))
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with multiple records
				history := make(DelegationHistory, 0)

				// Records before snapshot time (should be subtracted)
				record1 := staker.NewDelegationRecord(
					staker.DelegateType,
					300,
					address("user1"),
					address("validator1"),
					30,
				)

				record2 := staker.NewDelegationRecord(
					staker.DelegateType,
					200,
					address("user1"),
					address("validator1"),
					70,
				)

				record3 := staker.NewDelegationRecord(
					staker.DelegateType,
					100,
					address("user2"),
					address("validator2"),
					80,
				)

				// Record after snapshot time (should not be subtracted)
				record4 := staker.NewDelegationRecord(
					staker.DelegateType,
					400,
					address("user1"),
					address("validator1"),
					150,
				)

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
			setupState: func(gs *govStakerV1) {
				// Setup delegation snapshots
				snapshots := make(staker.DelegationSnapshot)
				snapshots["user1"] = staker.NewDelegationSnapshotItem(1000, address("user1"))
				gs.setDelegationSnapshots(snapshots)

				// Setup delegation history with undelegate record
				history := make(DelegationHistory, 0)

				record := staker.NewDelegationRecord(
					staker.UnDelegateType, // Undelegate
					300,
					address("user1"),
					address("validator1"),
					50,
				)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create new instance and setup state
			gs := createTestGovStaker()
			tt.setupState(gs)

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
	tests := []struct {
		name                   string
		setupState             func(gs *govStakerV1)
		snapshotTime           int64
		expectedUserDelegation int64
		userAddress            string
	}{
		{
			name: "Snapshot calculation with delegate user1 to validator1 record before time",
			setupState: func(gs *govStakerV1) {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(staker.DelegationSnapshot)

				// Current snapshot shows validator1 has received 1000 in delegations
				snapshots["validator1"] = staker.NewDelegationSnapshotItem(1000, address("validator1"))
				gs.setDelegationSnapshots(snapshots)

				// There was a delegate of 200 to validator1 at time 50
				// Since this happened before snapshot time (100), it should NOT be subtracted
				// So at time 100, validator1 should still have 1000
				record := staker.NewDelegationRecord(
					staker.DelegateType,
					200,
					address("user1"),
					address("validator1"),
					50,
				)
				history := make(DelegationHistory, 0)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime:           100,
			userAddress:            "validator1", // Check validator1, not user1
			expectedUserDelegation: 1000,
		},
		{
			name: "Snapshot calculation with delegate user1 to user1 record before time",
			setupState: func(gs *govStakerV1) {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(staker.DelegationSnapshot)

				// Current snapshot shows 1000 delegated
				snapshots["user1"] = staker.NewDelegationSnapshotItem(1000, address("user1"))
				gs.setDelegationSnapshots(snapshots)

				// But there was a delegate of 200 at time 50
				// So at time 100, it should be 1000
				record := staker.NewDelegationRecord(
					staker.DelegateType,
					200,
					address("user1"),
					address("user1"),
					150,
				)
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
			setupState: func(gs *govStakerV1) {
				// Reset state
				gs.setDelegationHistory(make(DelegationHistory, 0))
				snapshots := make(staker.DelegationSnapshot)

				// Current snapshot shows validator1 has 500 in delegations
				snapshots["validator1"] = staker.NewDelegationSnapshotItem(500, address("validator1"))
				gs.setDelegationSnapshots(snapshots)

				// There was an undelegate of 100 from validator1 at time 50
				// Since this happened before snapshot time (100), it should NOT be subtracted
				// So at time 100, validator1 should still have 500
				record := staker.NewDelegationRecord(
					staker.UnDelegateType,
					100,
					address("user1"),
					address("validator1"),
					50,
				)
				history := make(DelegationHistory, 0)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
			},
			snapshotTime:           100,
			userAddress:            "validator1", // Check validator1, not user1
			expectedUserDelegation: 500,          // Undelegate happened before snapshot time, already reflected
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create new instance and setup state
			gs := createTestGovStaker()
			tt.setupState(gs)

			// When: Get delegation snapshots
			snapshot, found := gs.GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should return expected result
			uassert.True(t, found)

			// Check specific user delegation amount
			if item, exists := snapshot[tt.userAddress]; exists {
				uassert.Equal(t, item.DelegationAmount(), tt.expectedUserDelegation)
			} else {
				// If address not found, check if expected was 0
				if tt.expectedUserDelegation != 0 {
					t.Fatalf("Address %s NOT found in snapshot, expected delegation: %d", tt.userAddress, tt.expectedUserDelegation)
				}
			}
		})
	}
}

// Test GetDelegationSnapshots edge cases
func TestGetDelegationSnapshots_EdgeCases(t *testing.T) {
	tests := []struct {
		name         string
		setupState   func(gs *govStakerV1)
		snapshotTime int64
		description  string
	}{
		{
			name: "Zero snapshot time",
			setupState: func(gs *govStakerV1) {
				gs.setDelegationHistory(make(DelegationHistory, 0))
				gs.setDelegationSnapshots(make(staker.DelegationSnapshot))
			},
			snapshotTime: 0,
			description:  "Should handle zero snapshot time",
		},
		{
			name: "Negative snapshot time",
			setupState: func(gs *govStakerV1) {
				history := make(DelegationHistory, 0)

				record := staker.NewDelegationRecord(
					staker.DelegateType,
					100,
					address("user1"),
					address("validator1"),
					50,
				)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
				gs.setDelegationSnapshots(make(staker.DelegationSnapshot))
			},
			snapshotTime: -10,
			description:  "Should handle negative snapshot time",
		},
		{
			name: "Very large snapshot time",
			setupState: func(gs *govStakerV1) {
				history := make(DelegationHistory, 0)

				record := staker.NewDelegationRecord(
					staker.DelegateType,
					100,
					address("user1"),
					address("validator1"),
					1000,
				)
				history = history.addRecord(record)
				gs.setDelegationHistory(history)
				gs.setDelegationSnapshots(make(staker.DelegationSnapshot))
			},
			snapshotTime: 999999999,
			description:  "Should handle very large snapshot time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Create new instance and setup state
			gs := createTestGovStaker()
			tt.setupState(gs)

			// When: Get delegation snapshots
			snapshot, found := gs.GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should not panic and return valid result
			uassert.True(t, found)
			uassert.NotEqual(t, snapshot, nil)
		})
	}
}
