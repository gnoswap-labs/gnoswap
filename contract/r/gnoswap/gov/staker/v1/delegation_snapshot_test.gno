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

// TestNewDelegationSnapshotResolver tests the constructor
func TestNewDelegationSnapshotResolver(t *testing.T) {
	tests := []struct {
		name     string
		snapshot staker.DelegationSnapshot
	}{
		{
			name:     "Create with empty snapshot",
			snapshot: make(staker.DelegationSnapshot),
		},
		{
			name: "Create with existing data",
			snapshot: staker.DelegationSnapshot{
				"g1to1": staker.NewDelegationSnapshotItem(100, address("g1to1")),
				"g1to2": staker.NewDelegationSnapshotItem(200, address("g1to2")),
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			resolver := NewDelegationSnapshotResolver(tc.snapshot)

			// then
			uassert.NotNil(t, resolver)
			uassert.Equal(t, len(resolver.Get()), len(tc.snapshot))
		})
	}
}

// TestDelegationSnapshotResolver_Get tests getting snapshot
func TestDelegationSnapshotResolver_Get(t *testing.T) {
	tests := []struct {
		name          string
		snapshot      staker.DelegationSnapshot
		expectedCount int
	}{
		{
			name:          "Get empty snapshot",
			snapshot:      make(staker.DelegationSnapshot),
			expectedCount: 0,
		},
		{
			name: "Get snapshot with data",
			snapshot: staker.DelegationSnapshot{
				"g1to1": staker.NewDelegationSnapshotItem(100, address("g1to1")),
				"g1to2": staker.NewDelegationSnapshotItem(200, address("g1to2")),
			},
			expectedCount: 2,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			resolver := NewDelegationSnapshotResolver(tc.snapshot)

			// when
			result := resolver.Get()

			// then
			uassert.Equal(t, len(result), tc.expectedCount)
		})
	}
}

// TestNewDelegationSnapshotItemResolver tests the item constructor
func TestNewDelegationSnapshotItemResolver(t *testing.T) {
	tests := []struct {
		name             string
		delegationAmount int64
		delegatorAddress address
	}{
		{
			name:             "Create with positive amount",
			delegationAmount: 100,
			delegatorAddress: address("g1delegator"),
		},
		{
			name:             "Create with zero amount",
			delegationAmount: 0,
			delegatorAddress: address("g1delegator"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := staker.NewDelegationSnapshotItem(tc.delegationAmount, tc.delegatorAddress)

			// when
			resolver := NewDelegationSnapshotItemResolver(item)

			// then
			uassert.NotNil(t, resolver)
			result := resolver.Get()
			uassert.Equal(t, result.DelegationAmount(), tc.delegationAmount)
		})
	}
}

// TestDelegationSnapshotItemResolver_Get tests getting snapshot item
func TestDelegationSnapshotItemResolver_Get(t *testing.T) {
	tests := []struct {
		name             string
		delegationAmount int64
		delegatorAddress address
	}{
		{
			name:             "Get item with positive amount",
			delegationAmount: 100,
			delegatorAddress: address("g1delegator"),
		},
		{
			name:             "Get item with zero amount",
			delegationAmount: 0,
			delegatorAddress: address("g1delegator"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := staker.NewDelegationSnapshotItem(tc.delegationAmount, tc.delegatorAddress)
			resolver := NewDelegationSnapshotItemResolver(item)

			// when
			result := resolver.Get()

			// then
			uassert.Equal(t, result.DelegationAmount(), tc.delegationAmount)
			uassert.Equal(t, result.DelegatorAddress(), tc.delegatorAddress)
		})
	}
}

// TestDelegationSnapshot_ErrorCases tests error and boundary cases
func TestDelegationSnapshot_ErrorCases(t *testing.T) {
	t.Run("AddRecord with negative delegation amount", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(100, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)
		record := staker.NewDelegationRecord(
			staker.DelegateType,
			-50,
			address("g1from"),
			address("g1to"),
			1000,
		)

		// when
		newItem := resolver.AddRecord(record)

		// then - should handle negative as subtraction
		uassert.Equal(t, newItem.DelegationAmount(), int64(50))
	})

	t.Run("SubRecord with negative delegation amount", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(100, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)
		record := staker.NewDelegationRecord(
			staker.UnDelegateType,
			-50,
			address("g1from"),
			address("g1to"),
			1000,
		)

		// when
		newItem := resolver.SubRecord(record)

		// then - negative amount is added as-is
		uassert.Equal(t, newItem.DelegationAmount(), int64(50))
	})

	t.Run("Clone independence - modifying original doesn't affect clone", func(t *testing.T) {
		// given
		snapshot := staker.DelegationSnapshot{
			"g1to1": staker.NewDelegationSnapshotItem(100, address("g1to1")),
		}
		resolver := NewDelegationSnapshotResolver(snapshot)
		cloned := resolver.Clone()

		// when - modify original
		snapshot["g1to1"] = staker.NewDelegationSnapshotItem(999, address("g1to1"))

		// then - clone should be unchanged
		uassert.Equal(t, cloned["g1to1"].DelegationAmount(), int64(100))
	})

	t.Run("Clone independence - modifying clone doesn't affect original", func(t *testing.T) {
		// given
		snapshot := staker.DelegationSnapshot{
			"g1to1": staker.NewDelegationSnapshotItem(100, address("g1to1")),
		}
		resolver := NewDelegationSnapshotResolver(snapshot)
		cloned := resolver.Clone()

		// when - modify clone
		cloned["g1to1"] = staker.NewDelegationSnapshotItem(999, address("g1to1"))

		// then - original should be unchanged
		uassert.Equal(t, snapshot["g1to1"].DelegationAmount(), int64(100))
	})

	t.Run("Multiple AddRecord to same delegatee", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(100, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)

		// when - add multiple times
		record1 := staker.NewDelegationRecord(staker.DelegateType, 50, address("g1from"), address("g1to"), 1000)
		item = resolver.AddRecord(record1)
		resolver = NewDelegationSnapshotItemResolver(item)

		record2 := staker.NewDelegationRecord(staker.DelegateType, 30, address("g1from"), address("g1to"), 2000)
		item = resolver.AddRecord(record2)

		// then - should accumulate
		uassert.Equal(t, item.DelegationAmount(), int64(180))
	})

	t.Run("Multiple SubRecord from same delegatee", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(200, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)

		// when - subtract multiple times
		record1 := staker.NewDelegationRecord(staker.UnDelegateType, 50, address("g1from"), address("g1to"), 1000)
		item = resolver.SubRecord(record1)
		resolver = NewDelegationSnapshotItemResolver(item)

		record2 := staker.NewDelegationRecord(staker.UnDelegateType, 30, address("g1from"), address("g1to"), 2000)
		item = resolver.SubRecord(record2)

		// then - should accumulate
		uassert.Equal(t, item.DelegationAmount(), int64(280))
	})

	t.Run("Item clone independence", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(100, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)

		// when
		cloned := resolver.Clone()
		record := staker.NewDelegationRecord(staker.DelegateType, 50, address("g1from"), address("g1to"), 1000)
		newItem := resolver.AddRecord(record)

		// then - cloned should be unchanged
		uassert.Equal(t, cloned.DelegationAmount(), int64(100))
		uassert.Equal(t, newItem.DelegationAmount(), int64(150))
	})

	t.Run("IsEmpty with very large amounts", func(t *testing.T) {
		// given
		maxInt64 := int64(9223372036854775807)
		item := staker.NewDelegationSnapshotItem(maxInt64, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)

		// when & then
		uassert.False(t, resolver.IsEmpty())
	})

	t.Run("AddRecord and SubRecord with zero delegation", func(t *testing.T) {
		// given
		item := staker.NewDelegationSnapshotItem(100, address("g1to"))
		resolver := NewDelegationSnapshotItemResolver(item)

		// when - add zero
		record1 := staker.NewDelegationRecord(staker.DelegateType, 0, address("g1from"), address("g1to"), 1000)
		newItem := resolver.AddRecord(record1)

		// then - should remain unchanged
		uassert.Equal(t, newItem.DelegationAmount(), int64(100))

		// when - subtract zero
		resolver = NewDelegationSnapshotItemResolver(newItem)
		record2 := staker.NewDelegationRecord(staker.UnDelegateType, 0, address("g1from"), address("g1to"), 2000)
		newItem = resolver.SubRecord(record2)

		// then - should remain unchanged
		uassert.Equal(t, newItem.DelegationAmount(), int64(100))
	})
}
