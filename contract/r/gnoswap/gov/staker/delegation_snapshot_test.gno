package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestDelegationSnapshotItem_NewDelegationSnapshotItem tests the constructor
func TestDelegationSnapshotItem_NewDelegationSnapshotItem(t *testing.T) {
	tests := []struct {
		name             string
		amount           int64
		delegatorAddress address
	}{
		{
			name:             "Create with positive amount",
			amount:           100,
			delegatorAddress: address("g1delegator"),
		},
		{
			name:             "Create with zero amount",
			amount:           0,
			delegatorAddress: address("g1delegator"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			item := NewDelegationSnapshotItem(tc.amount, tc.delegatorAddress)

			// then
			uassert.NotNil(t, item)
			uassert.Equal(t, item.DelegationAmount(), tc.amount)
			uassert.Equal(t, item.DelegatorAddress(), tc.delegatorAddress)
		})
	}
}

// TestDelegationSnapshotItem_DelegatorAddress tests getting delegator address
func TestDelegationSnapshotItem_DelegatorAddress(t *testing.T) {
	tests := []struct {
		name             string
		delegatorAddress address
	}{
		{
			name:             "Get delegator address",
			delegatorAddress: address("g1delegator"),
		},
		{
			name:             "Get different delegator address",
			delegatorAddress: address("g1another"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := NewDelegationSnapshotItem(100, tc.delegatorAddress)

			// when
			result := item.DelegatorAddress()

			// then
			uassert.Equal(t, result, tc.delegatorAddress)
		})
	}
}

// TestDelegationSnapshotItem_DelegationAmount tests getting delegation amount
func TestDelegationSnapshotItem_DelegationAmount(t *testing.T) {
	tests := []struct {
		name   string
		amount int64
	}{
		{
			name:   "Get zero amount",
			amount: 0,
		},
		{
			name:   "Get positive amount",
			amount: 1000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := NewDelegationSnapshotItem(tc.amount, address("g1delegator"))

			// when
			result := item.DelegationAmount()

			// then
			uassert.Equal(t, result, tc.amount)
		})
	}
}

// TestDelegationSnapshotItem_SetDelegationAmount tests setting delegation amount
func TestDelegationSnapshotItem_SetDelegationAmount(t *testing.T) {
	tests := []struct {
		name      string
		initial   int64
		newAmount int64
	}{
		{
			name:      "Set to positive amount",
			initial:   100,
			newAmount: 200,
		},
		{
			name:      "Set to zero",
			initial:   100,
			newAmount: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := NewDelegationSnapshotItem(tc.initial, address("g1delegator"))

			// when
			item.SetDelegationAmount(tc.newAmount)

			// then
			uassert.Equal(t, item.DelegationAmount(), tc.newAmount)
		})
	}
}

// TestDelegationSnapshotItem_SetDelegatorAddress tests setting delegator address
func TestDelegationSnapshotItem_SetDelegatorAddress(t *testing.T) {
	tests := []struct {
		name       string
		initial    address
		newAddress address
	}{
		{
			name:       "Set to different address",
			initial:    address("g1delegator1"),
			newAddress: address("g1delegator2"),
		},
		{
			name:       "Set to same address",
			initial:    address("g1delegator"),
			newAddress: address("g1delegator"),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			item := NewDelegationSnapshotItem(100, tc.initial)

			// when
			item.SetDelegatorAddress(tc.newAddress)

			// then
			uassert.Equal(t, item.DelegatorAddress(), tc.newAddress)
		})
	}
}

// TestDelegationSnapshot_MapOperations tests map operations on DelegationSnapshot
func TestDelegationSnapshot_MapOperations(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Create and manipulate delegation snapshot map",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			snapshot := make(DelegationSnapshot)

			// when - add items
			snapshot["g1delegatee1"] = NewDelegationSnapshotItem(100, address("g1delegator1"))
			snapshot["g1delegatee2"] = NewDelegationSnapshotItem(200, address("g1delegator2"))

			// then
			uassert.Equal(t, len(snapshot), 2)
			uassert.NotNil(t, snapshot["g1delegatee1"])
			uassert.Equal(t, snapshot["g1delegatee1"].DelegationAmount(), int64(100))
			uassert.NotNil(t, snapshot["g1delegatee2"])
			uassert.Equal(t, snapshot["g1delegatee2"].DelegationAmount(), int64(200))

			// when - delete item
			delete(snapshot, "g1delegatee1")

			// then
			uassert.Equal(t, len(snapshot), 1)
			_, exists := snapshot["g1delegatee1"]
			uassert.False(t, exists)
		})
	}
}
