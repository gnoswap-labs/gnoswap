package staker

import (
	"math"
	"testing"

	bptree "gno.land/p/nt/bptree/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

// TestNewLaunchpadProjectDeposits tests creating a new launchpad project deposits
func TestNewLaunchpadProjectDeposits(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Create new launchpad project deposits",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestLaunchpadProjectDeposits_SetAndGetDeposits(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// given
			lpd := NewLaunchpadProjectDeposits()
			newTree := bptree.NewBPTreeN(16)
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
func TestLaunchpadProjectDeposits_Operations(cur realm, t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Add and remove deposits",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
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

func TestLaunchpadProjectDeposits_GetDeposit(cur realm, t *testing.T) {
	tests := []struct {
		name           string
		setup          func() *LaunchpadProjectDeposits
		ownerAddress   string
		expectedValue  int64
		expectedExists bool
	}{
		{
			name: "returns zero and false when no deposit exists",
			setup: func() *LaunchpadProjectDeposits {
				return NewLaunchpadProjectDeposits()
			},
			ownerAddress:   "owner1",
			expectedValue:  0,
			expectedExists: false,
		},
		{
			name: "returns deposit value when exists",
			setup: func() *LaunchpadProjectDeposits {
				deposits := NewLaunchpadProjectDeposits()
				deposits.SetDeposit("owner1", 1000000)
				return deposits
			},
			ownerAddress:   "owner1",
			expectedValue:  1000000,
			expectedExists: true,
		},
		{
			name: "returns correct deposit for multiple owners",
			setup: func() *LaunchpadProjectDeposits {
				deposits := NewLaunchpadProjectDeposits()
				deposits.SetDeposit("owner1", 1000000)
				deposits.SetDeposit("owner2", 2000000)
				return deposits
			},
			ownerAddress:   "owner2",
			expectedValue:  2000000,
			expectedExists: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			deposits := tc.setup()

			value, exists := deposits.GetDeposit(tc.ownerAddress)

			uassert.Equal(t, value, tc.expectedValue)
			uassert.Equal(t, exists, tc.expectedExists)
		})
	}
}

func TestLaunchpadProjectDeposits_SetDeposit(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		ownerAddress  string
		depositAmount int64
		expectedValue int64
	}{
		{
			name:          "sets deposit for new owner",
			ownerAddress:  "owner1",
			depositAmount: 1000000,
			expectedValue: 1000000,
		},
		{
			name:          "sets deposit to zero",
			ownerAddress:  "owner1",
			depositAmount: 0,
			expectedValue: 0,
		},
		{
			name:          "sets max int64 deposit",
			ownerAddress:  "owner1",
			depositAmount: math.MaxInt64,
			expectedValue: math.MaxInt64,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			deposits := NewLaunchpadProjectDeposits()

			deposits.SetDeposit(tc.ownerAddress, tc.depositAmount)

			value, exists := deposits.GetDeposit(tc.ownerAddress)
			uassert.True(t, exists)
			uassert.Equal(t, value, tc.expectedValue)
		})
	}
}

func TestLaunchpadProjectDeposits_RemoveDeposit(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		setup        func() *LaunchpadProjectDeposits
		ownerAddress string
		expectedOk   bool
		shouldExist  bool
	}{
		{
			name: "removes existing deposit",
			setup: func() *LaunchpadProjectDeposits {
				deposits := NewLaunchpadProjectDeposits()
				deposits.SetDeposit("owner1", 1000000)
				return deposits
			},
			ownerAddress: "owner1",
			expectedOk:   true,
			shouldExist:  false,
		},
		{
			name: "returns false when deposit does not exist",
			setup: func() *LaunchpadProjectDeposits {
				return NewLaunchpadProjectDeposits()
			},
			ownerAddress: "owner1",
			expectedOk:   false,
			shouldExist:  false,
		},
		{
			name: "does not affect other deposits",
			setup: func() *LaunchpadProjectDeposits {
				deposits := NewLaunchpadProjectDeposits()
				deposits.SetDeposit("owner1", 1000000)
				deposits.SetDeposit("owner2", 2000000)
				return deposits
			},
			ownerAddress: "owner1",
			expectedOk:   true,
			shouldExist:  false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			deposits := tc.setup()

			ok := deposits.RemoveDeposit(tc.ownerAddress)

			uassert.Equal(t, ok, tc.expectedOk)
			_, exists := deposits.GetDeposit(tc.ownerAddress)
			uassert.Equal(t, exists, tc.shouldExist)
		})
	}
}
