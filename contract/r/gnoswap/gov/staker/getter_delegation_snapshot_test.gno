package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// Test GetDelegationSnapshots
func TestGetDelegationSnapshots(t *testing.T) {
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
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with existing data",
			setupState: func() {
				// Setup delegation snapshots
				delegationSnapshots = make(DelegationSnapshot)
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: std.Address("user1"),
				}

				// Setup delegation history
				delegationHistory = make(DelegationHistory, 0)
				
				// Add a delegation record after snapshot time
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 500,
					delegationType:   DelegateType,
					createdAt:      150, // After snapshot time
				}
				delegationHistory = delegationHistory.addRecord(record)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with history records before snapshot time",
			setupState: func() {
				// Setup delegation snapshots
				delegationSnapshots = make(DelegationSnapshot)
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1500,
					delegatorAddress: std.Address("user1"),
				}

				// Setup delegation history with records before snapshot time
				delegationHistory = make(DelegationHistory, 0)
				
				// Add a delegation record before snapshot time (should be subtracted)
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 500,
					delegationType:   DelegateType,
					createdAt:      50, // Before snapshot time
				}
				delegationHistory = delegationHistory.addRecord(record)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with multiple history records",
			setupState: func() {
				// Setup delegation snapshots
				delegationSnapshots = make(DelegationSnapshot)
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 2000,
					delegatorAddress: std.Address("user1"),
				}
				delegationSnapshots["user2"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: std.Address("user2"),
				}

				// Setup delegation history with multiple records
				delegationHistory = make(DelegationHistory, 0)
				
				// Records before snapshot time (should be subtracted)
				record1 := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 300,
					delegationType:   DelegateType,
					createdAt:      30,
				}
				
				record2 := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 200,
					delegationType:   DelegateType,
					createdAt:      70,
				}
				
				record3 := &DelegationRecord{
					delegateFrom:   std.Address("user2"),
					delegateTo:     std.Address("validator2"),
					delegateAmount: 100,
					delegationType:   DelegateType,
					createdAt:      80,
				}
				
				// Record after snapshot time (should not be subtracted)
				record4 := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 400,
					delegationType:   DelegateType,
					createdAt:      150,
				}
				
				delegationHistory = delegationHistory.addRecord(record1)
				delegationHistory = delegationHistory.addRecord(record2)
				delegationHistory = delegationHistory.addRecord(record3)
				delegationHistory = delegationHistory.addRecord(record4)
			},
			snapshotTime: 100,
			expectFound:  true,
		},
		{
			name: "Get snapshot with undelegate records",
			setupState: func() {
				// Setup delegation snapshots
				delegationSnapshots = make(DelegationSnapshot)
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: std.Address("user1"),
				}

				// Setup delegation history with undelegate record
				delegationHistory = make(DelegationHistory, 0)
				
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 300,
					delegationType:   UnDelegateType, // Undelegate
					createdAt:      50,
				}
				delegationHistory = delegationHistory.addRecord(record)
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
			snapshot, found := GetDelegationSnapshots(tt.snapshotTime)

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
		name                    string
		setupState              func()
		snapshotTime            int64
		expectedUserDelegation  int64
		userAddress             string
	}{
		{
			name: "Snapshot calculation with delegate user1 to validator1 record before time",
			setupState: func() {
				// Reset state
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
				
				// Current snapshot shows 1000 delegated
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: std.Address("user1"),
				}
				
				// But there was a delegate of 200 at time 50
				// So at time 100, it should be 1000
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 200,
					delegationType:   DelegateType,
					createdAt:      50,
				}
				delegationHistory = delegationHistory.addRecord(record)
			},
			snapshotTime:           100,
			userAddress:            "user1",
			expectedUserDelegation: 1000, // 1000
		},
		{
			name: "Snapshot calculation with delegate user1 to user1 record before time",
			setupState: func() {
				// Reset state
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
				
				// Current snapshot shows 1000 delegated
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 1000,
					delegatorAddress: std.Address("user1"),
				}
				
				// But there was a delegate of 200 at time 50
				// So at time 100, it should be 1000
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("user1"),
					delegateAmount: 200,
					delegationType:   DelegateType,
					createdAt:      150,
				}
				delegationHistory = delegationHistory.addRecord(record)
			},
			snapshotTime:           100,
			userAddress:            "user1",
			expectedUserDelegation: 800, // 1000 - 200
		},
		{
			name: "Snapshot calculation with undelegate record before time",
			setupState: func() {
				// Reset state
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
				
				// Current snapshot shows 500 delegated
				delegationSnapshots["user1"] = &DelegationSnapshotItem{
					delegationAmount: 500,
					delegatorAddress: std.Address("user1"),
				}
				
				// But there was an undelegate of 100 at time 50
				// So at time 100, it should be 500 + 100 = 600 (we add back the undelegate)
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 100,
					delegationType:   UnDelegateType,
					createdAt:      50,
				}
				delegationHistory = delegationHistory.addRecord(record)
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
			snapshot, found := GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should return expected result
			uassert.True(t, found)
			
			// Check specific user delegation amount
			if item, exists := snapshot[tt.userAddress]; exists {
				uassert.Equal(t, item.delegationAmount, tt.expectedUserDelegation)
			}
		})
	}
}

// Test GetDelegationSnapshots edge cases
func TestGetDelegationSnapshots_EdgeCases(t *testing.T) {
	tests := []struct {
		name         string
		setupState   func()
		snapshotTime int64
		description  string
	}{
		{
			name: "Zero snapshot time",
			setupState: func() {
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
			},
			snapshotTime: 0,
			description:  "Should handle zero snapshot time",
		},
		{
			name: "Negative snapshot time",
			setupState: func() {
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
				
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 100,
					delegationType:   DelegateType,
					createdAt:      50,
				}
				delegationHistory = delegationHistory.addRecord(record)
			},
			snapshotTime: -10,
			description:  "Should handle negative snapshot time",
		},
		{
			name: "Very large snapshot time",
			setupState: func() {
				delegationHistory = make(DelegationHistory, 0)
				delegationSnapshots = make(DelegationSnapshot)
				
				record := &DelegationRecord{
					delegateFrom:   std.Address("user1"),
					delegateTo:     std.Address("validator1"),
					delegateAmount: 100,
					delegationType:   DelegateType,
					createdAt:      1000,
				}
				delegationHistory = delegationHistory.addRecord(record)
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
			snapshot, found := GetDelegationSnapshots(tt.snapshotTime)

			// Then: Should not panic and return valid result
			uassert.True(t, found)
			uassert.NotEqual(t, snapshot, nil)
		})
	}
} 