package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/staker"
)

// TestDelegationSnapshotResolver_AddRecord tests adding records to delegation snapshot
func TestDelegationSnapshotResolver_AddRecord(t *testing.T) {
	tests := []struct {
		name            string
		initialSnapshot staker.DelegationSnapshot
		record          *staker.DelegationRecord
		expectedAmount  int64
		shouldExist     bool
	}{
		{
			name:            "Add delegate record to empty snapshot",
			initialSnapshot: make(staker.DelegationSnapshot),
			record: staker.NewDelegationRecord(
				staker.DelegateType,
				100,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 100,
			shouldExist:    true,
		},
		{
			name: "Add undelegate record to existing snapshot",
			initialSnapshot: staker.DelegationSnapshot{
				"g1to": staker.NewDelegationSnapshotItem(100, address("g1to")),
			},
			record: staker.NewDelegationRecord(
				staker.UnDelegateType,
				50,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 50,
			shouldExist:    true,
		},
		{
			name: "Add record that results in zero amount",
			initialSnapshot: staker.DelegationSnapshot{
				"g1to": staker.NewDelegationSnapshotItem(100, address("g1to")),
			},
			record: staker.NewDelegationRecord(
				staker.UnDelegateType,
				100,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 0,
			shouldExist:    false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationSnapshotResolver(tc.initialSnapshot)

			// when
			resolver.AddRecord(tc.record)

			// then
			snapshot := resolver.Get()
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

// TestDelegationSnapshotResolver_SubRecord tests subtracting records from delegation snapshot
func TestDelegationSnapshotResolver_SubRecord(t *testing.T) {
	tests := []struct {
		name            string
		initialSnapshot staker.DelegationSnapshot
		record          *staker.DelegationRecord
		expectedAmount  int64
	}{
		{
			name: "Subtract delegate record",
			initialSnapshot: staker.DelegationSnapshot{
				"g1to": staker.NewDelegationSnapshotItem(100, address("g1to")),
			},
			record: staker.NewDelegationRecord(
				staker.DelegateType,
				50,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 50,
		},
		{
			name: "Subtract undelegate record",
			initialSnapshot: staker.DelegationSnapshot{
				"g1to": staker.NewDelegationSnapshotItem(50, address("g1to")),
			},
			record: staker.NewDelegationRecord(
				staker.UnDelegateType,
				30,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 80,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationSnapshotResolver(tc.initialSnapshot)

			// when
			resolver.SubRecord(tc.record)

			// then
			snapshot := resolver.Get()
			item, exists := snapshot[tc.record.DelegateTo().String()]
			uassert.True(t, exists)
			uassert.Equal(t, item.DelegationAmount(), tc.expectedAmount)
		})
	}
}

// TestDelegationSnapshotItemResolver_AddRecord tests adding records to snapshot item
func TestDelegationSnapshotItemResolver_AddRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialAmount  int64
		record         *staker.DelegationRecord
		expectedAmount int64
	}{
		{
			name:          "Add delegate record",
			initialAmount: 100,
			record: staker.NewDelegationRecord(
				staker.DelegateType,
				50,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 150,
		},
		{
			name:          "Add undelegate record",
			initialAmount: 100,
			record: staker.NewDelegationRecord(
				staker.UnDelegateType,
				30,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 70,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := staker.NewDelegationSnapshotItem(tc.initialAmount, address("g1to"))
			resolver := NewDelegationSnapshotItemResolver(item)

			// when
			newItem := resolver.AddRecord(tc.record)

			// then
			uassert.Equal(t, newItem.DelegationAmount(), tc.expectedAmount)
		})
	}
}

// TestDelegationSnapshotItemResolver_SubRecord tests subtracting records from snapshot item
func TestDelegationSnapshotItemResolver_SubRecord(t *testing.T) {
	tests := []struct {
		name           string
		initialAmount  int64
		record         *staker.DelegationRecord
		expectedAmount int64
	}{
		{
			name:          "Subtract delegate record",
			initialAmount: 100,
			record: staker.NewDelegationRecord(
				staker.DelegateType,
				50,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 50,
		},
		{
			name:          "Subtract undelegate record",
			initialAmount: 50,
			record: staker.NewDelegationRecord(
				staker.UnDelegateType,
				30,
				address("g1from"),
				address("g1to"),
				1000,
			),
			expectedAmount: 80,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := staker.NewDelegationSnapshotItem(tc.initialAmount, address("g1to"))
			resolver := NewDelegationSnapshotItemResolver(item)

			// when
			newItem := resolver.SubRecord(tc.record)

			// then
			uassert.Equal(t, newItem.DelegationAmount(), tc.expectedAmount)
		})
	}
}

func TestDelegationSnapshotResolver_Clone(t *testing.T) {
	tests := []struct {
		name     string
		snapshot staker.DelegationSnapshot
	}{
		{
			name:     "Clone empty snapshot",
			snapshot: make(staker.DelegationSnapshot),
		},
		{
			name: "Clone snapshot with data",
			snapshot: staker.DelegationSnapshot{
				"g1to1": staker.NewDelegationSnapshotItem(100, address("g1to1")),
				"g1to2": staker.NewDelegationSnapshotItem(200, address("g1to2")),
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationSnapshotResolver(tc.snapshot)

			// when
			cloned := resolver.Clone()

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

// TestDelegationSnapshotItemResolver_Methods tests delegation snapshot item resolver methods
func TestDelegationSnapshotItemResolver_Methods(t *testing.T) {
	tests := []struct {
		name             string
		delegatorAddress address
		delegationAmount int64
		expectedEmpty    bool
	}{
		{
			name:             "Non-empty snapshot item",
			delegatorAddress: address("g1delegator"),
			delegationAmount: 100,
			expectedEmpty:    false,
		},
		{
			name:             "Empty snapshot item",
			delegatorAddress: address("g1delegator"),
			delegationAmount: 0,
			expectedEmpty:    true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := staker.NewDelegationSnapshotItem(tc.delegationAmount, tc.delegatorAddress)
			resolver := NewDelegationSnapshotItemResolver(item)

			// when & then
			uassert.Equal(t, item.DelegatorAddress(), tc.delegatorAddress)
			uassert.Equal(t, item.DelegationAmount(), tc.delegationAmount)
			uassert.Equal(t, resolver.IsEmpty(), tc.expectedEmpty)

			// Test clone
			cloned := resolver.Clone()
			uassert.Equal(t, cloned.DelegatorAddress(), tc.delegatorAddress)
			uassert.Equal(t, cloned.DelegationAmount(), tc.delegationAmount)
		})
	}
}
