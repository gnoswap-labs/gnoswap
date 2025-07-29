package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestDelegationSnapshot_AddRecord tests adding records to delegation snapshot
func TestDelegationSnapshot_AddRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialSnapshot DelegationSnapshot
		record         *DelegationRecord
		expectedAmount int64
		shouldExist    bool
	}{
		{
			name:            "Add delegate record to empty snapshot",
			initialSnapshot: make(DelegationSnapshot),
			record: &DelegationRecord{
				delegationType:   DelegateType,
				delegateAmount:   100,
				unDelegateAmount: 0,
				delegateTo:       std.Address("g1to"),
			},
			expectedAmount: 100,
			shouldExist:    true,
		},
		{
			name: "Add undelegate record to existing snapshot",
			initialSnapshot: DelegationSnapshot{
				"g1to": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to"),
					delegationAmount: 100,
				},
			},
			record: &DelegationRecord{
				delegationType:   UnDelegateType,
				delegateAmount:   0,
				unDelegateAmount: 50,
				delegateTo:       std.Address("g1to"),
			},
			expectedAmount: 50,
			shouldExist:    true,
		},
		{
			name: "Add record that results in zero amount",
			initialSnapshot: DelegationSnapshot{
				"g1to": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to"),
					delegationAmount: 100,
				},
			},
			record: &DelegationRecord{
				delegationType:   UnDelegateType,
				delegateAmount:   0,
				unDelegateAmount: 100,
				delegateTo:       std.Address("g1to"),
			},
			expectedAmount: 0,
			shouldExist:    false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			snapshot := tc.initialSnapshot

			// when
			snapshot.addRecord(tc.record)

			// then
			item, exists := snapshot[tc.record.DelegateTo().String()]
			if tc.shouldExist {
				uassert.True(t, exists)
				uassert.Equal(t, item.DelegationAmount(), tc.expectedAmount)
			} else {
				uassert.False(t, exists)
			}
		})
	}
}

// TestDelegationSnapshot_SubRecord tests subtracting records from delegation snapshot
func TestDelegationSnapshot_SubRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialSnapshot DelegationSnapshot
		record         *DelegationRecord
		expectedAmount int64
	}{
		{
			name: "Subtract delegate record",
			initialSnapshot: DelegationSnapshot{
				"g1to": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to"),
					delegationAmount: 100,
				},
			},
			record: &DelegationRecord{
				delegationType:   DelegateType,
				delegateAmount:   50,
				unDelegateAmount: 0,
				delegateTo:       std.Address("g1to"),
			},
			expectedAmount: 50,
		},
		{
			name: "Subtract undelegate record",
			initialSnapshot: DelegationSnapshot{
				"g1to": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to"),
					delegationAmount: 50,
				},
			},
			record: &DelegationRecord{
				delegationType:   UnDelegateType,
				delegateAmount:   0,
				unDelegateAmount: 30,
				delegateTo:       std.Address("g1to"),
			},
			expectedAmount: 80,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			snapshot := tc.initialSnapshot

			// when
			snapshot.subRecord(tc.record)

			// then
			item, exists := snapshot[tc.record.DelegateTo().String()]
			uassert.True(t, exists)
			uassert.Equal(t, item.DelegationAmount(), tc.expectedAmount)
		})
	}
}

// TestDelegationSnapshot_Clone tests cloning delegation snapshot
func TestDelegationSnapshot_Clone(t *testing.T) {
	tests := []struct {
		name     string
		snapshot DelegationSnapshot
	}{
		{
			name:     "Clone empty snapshot",
			snapshot: make(DelegationSnapshot),
		},
		{
			name: "Clone snapshot with data",
			snapshot: DelegationSnapshot{
				"g1to1": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to1"),
					delegationAmount: 100,
				},
				"g1to2": &DelegationSnapshotItem{
					delegatorAddress: std.Address("g1to2"),
					delegationAmount: 200,
				},
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			cloned := tc.snapshot.clone()

			// then
			uassert.Equal(t, len(cloned), len(tc.snapshot))
			for key, item := range tc.snapshot {
				clonedItem, exists := cloned[key]
				uassert.True(t, exists)
				uassert.Equal(t, clonedItem.DelegationAmount(), item.DelegationAmount())
				uassert.Equal(t, clonedItem.DelegatorAddress(), item.DelegatorAddress())
			}
		})
	}
}

// TestDelegationSnapshotItem_Methods tests delegation snapshot item methods
func TestDelegationSnapshotItem_Methods(t *testing.T) {
	tests := []struct {
		name             string
		delegatorAddress std.Address
		delegationAmount int64
		expectedEmpty    bool
	}{
		{
			name:             "Non-empty snapshot item",
			delegatorAddress: std.Address("g1delegator"),
			delegationAmount: 100,
			expectedEmpty:    false,
		},
		{
			name:             "Empty snapshot item",
			delegatorAddress: std.Address("g1delegator"),
			delegationAmount: 0,
			expectedEmpty:    true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := &DelegationSnapshotItem{
				delegatorAddress: tc.delegatorAddress,
				delegationAmount: tc.delegationAmount,
			}

			// when & then
			uassert.Equal(t, item.DelegatorAddress(), tc.delegatorAddress)
			uassert.Equal(t, item.DelegationAmount(), tc.delegationAmount)
			uassert.Equal(t, item.IsEmpty(), tc.expectedEmpty)

			// Test clone
			cloned := item.clone()
			uassert.Equal(t, cloned.DelegatorAddress(), tc.delegatorAddress)
			uassert.Equal(t, cloned.DelegationAmount(), tc.delegationAmount)
		})
	}
} 