package staker

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

// TestNewLaunchpadProjectDeposits tests creating a new launchpad project deposits
func TestNewLaunchpadProjectDeposits(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Create new launchpad project deposits",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			lpd := NewLaunchpadProjectDeposits()

			// then
			uassert.NotNil(t, lpd)
			uassert.NotNil(t, lpd.GetDeposits())
			uassert.Equal(t, lpd.GetDeposits().Size(), 0)
		})
	}
}

// TestLaunchpadProjectDeposits_SetAndGetDeposits tests setter and getter
func TestLaunchpadProjectDeposits_SetAndGetDeposits(t *testing.T) {
	tests := []struct {
		name              string
		depositsToSet     map[string]int64
		expectedSize      int
	}{
		{
			name:          "Set empty deposits tree",
			depositsToSet: map[string]int64{},
			expectedSize:  0,
		},
		{
			name: "Set deposits with single owner",
			depositsToSet: map[string]int64{
				"owner1": 1000,
			},
			expectedSize: 1,
		},
		{
			name: "Set deposits with multiple owners",
			depositsToSet: map[string]int64{
				"owner1": 1000,
				"owner2": 2000,
				"owner3": 3000,
			},
			expectedSize: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			lpd := NewLaunchpadProjectDeposits()
			newTree := avl.NewTree()
			for owner, amount := range tc.depositsToSet {
				newTree.Set(owner, amount)
			}

			// when
			lpd.SetDeposits(newTree)

			// then
			result := lpd.GetDeposits()
			uassert.NotNil(t, result)
			uassert.Equal(t, result.Size(), tc.expectedSize)

			// Verify each deposit
			for owner, expectedAmount := range tc.depositsToSet {
				value, exists := result.Get(owner)
				uassert.True(t, exists)
				uassert.Equal(t, value.(int64), expectedAmount)
			}
		})
	}
}

// TestLaunchpadProjectDeposits_Operations tests tree operations
func TestLaunchpadProjectDeposits_Operations(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Add and remove deposits",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			lpd := NewLaunchpadProjectDeposits()
			deposits := lpd.GetDeposits()

			// when - add deposits
			deposits.Set("owner1", int64(1000))
			deposits.Set("owner2", int64(2000))

			// then
			uassert.Equal(t, deposits.Size(), 2)
			value1, exists1 := deposits.Get("owner1")
			uassert.True(t, exists1)
			uassert.Equal(t, value1.(int64), int64(1000))

			// when - remove a deposit
			deposits.Remove("owner1")

			// then
			uassert.Equal(t, deposits.Size(), 1)
			_, exists := deposits.Get("owner1")
			uassert.False(t, exists)
		})
	}
}
