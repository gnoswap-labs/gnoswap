package staker2

import (
	"std"
	"testing"

	"gno.land/p/demo/ufmt"

	"gno.land/p/demo/uassert"
)

// TestValidateDelegation tests delegation validation logic
func TestValidateDelegation(t *testing.T) {
	alice := std.Address("alice")
	bob := std.Address("bob")

	t.Run("new delegation validation", func(t *testing.T) {
		staker := NewStakerState(alice)

		// Should fail with amount below minimum per address
		err := validateDelegation(staker, bob, MIN_DELEGATION_PER_ADDRESS-1)
		uassert.ErrorIs(t, err, ErrInsufficientDelegation)

		// Should succeed with exact minimum
		err = validateDelegation(staker, bob, MIN_DELEGATION_PER_ADDRESS)
		uassert.NoError(t, err)

		// Should succeed with amount above minimum
		err = validateDelegation(staker, bob, MIN_DELEGATION_PER_ADDRESS*2)
		uassert.NoError(t, err)
	})

	t.Run("existing delegation increment", func(t *testing.T) {
		staker := NewStakerState(alice)
		// Simulate existing delegation
		staker.Delegations[bob] = DelegationInfo{
			Amount:     MIN_DELEGATION_PER_ADDRESS,
			StartEpoch: 0,
		}

		// Should fail with increment below minimum
		err := validateDelegation(staker, bob, MIN_DELEGATION_INCREMENT-1)
		uassert.ErrorIs(t, err, ErrInsufficientIncrement)

		// Should succeed with exact minimum increment
		err = validateDelegation(staker, bob, MIN_DELEGATION_INCREMENT)
		uassert.NoError(t, err)
	})

	t.Run("max delegations limit", func(t *testing.T) {
		staker := NewStakerState(alice)

		// Fill up to max delegations
		for i := 0; i < MAX_DELEGATIONS_PER_USER; i++ {
			addr := std.Address(ufmt.Sprintf("delegate%d", i))
			staker.Delegations[addr] = DelegationInfo{
				Amount:     MIN_DELEGATION_PER_ADDRESS,
				StartEpoch: 0,
			}
		}

		// Should fail when trying to add one more
		newAddr := std.Address("newdelegate")
		err := validateDelegation(staker, newAddr, MIN_DELEGATION_PER_ADDRESS)
		uassert.ErrorIs(t, err, ErrTooManyDelegations)

		// Should succeed when adding to existing delegation
		existingAddr := std.Address("delegate0")
		err = validateDelegation(staker, existingAddr, MIN_DELEGATION_INCREMENT)
		uassert.NoError(t, err)
	})

	t.Run("self delegation check", func(t *testing.T) {
		staker := NewStakerState(alice)

		// Should fail when delegating to self
		err := validateDelegation(staker, alice, MIN_DELEGATION_PER_ADDRESS)
		uassert.ErrorIs(t, err, ErrSelfDelegation)
	})
}

// TestAddDelegation tests adding delegation to staker state
func TestAddDelegation(t *testing.T) {
	alice := std.Address("alice")
	bob := std.Address("bob")

	t.Run("add new delegation", func(t *testing.T) {
		staker := NewStakerState(alice)
		amount := uint64(50_000_000) // 50 GNS
		epoch := uint64(5)

		err := addDelegation(staker, bob, amount, epoch)
		uassert.NoError(t, err)

		// Check delegation was added
		delegation, exists := staker.Delegations[bob]
		uassert.True(t, exists)
		uassert.Equal(t, amount, delegation.Amount)
		uassert.Equal(t, epoch, delegation.StartEpoch)

		// Check total staked increased
		uassert.Equal(t, amount, staker.TotalStaked)
	})

	t.Run("add to existing delegation", func(t *testing.T) {
		staker := NewStakerState(alice)
		initialAmount := uint64(50_000_000)
		additionalAmount := uint64(30_000_000)

		// Add initial delegation
		err := addDelegation(staker, bob, initialAmount, 5)
		uassert.NoError(t, err)

		// Add more to same delegation
		err = addDelegation(staker, bob, additionalAmount, 10)
		uassert.NoError(t, err)

		// Check amounts were combined
		delegation := staker.Delegations[bob]
		uassert.Equal(t, initialAmount+additionalAmount, delegation.Amount)
		uassert.Equal(t, uint64(5), delegation.StartEpoch) // Keeps original epoch

		// Check total staked
		uassert.Equal(t, initialAmount+additionalAmount, staker.TotalStaked)
	})
}

// TestRemoveDelegation tests removing delegation from staker state
func TestRemoveDelegation(t *testing.T) {
	alice := std.Address("alice")
	bob := std.Address("bob")
	charlie := std.Address("charlie")

	t.Run("remove full delegation", func(t *testing.T) {
		staker := NewStakerState(alice)
		amount := uint64(50_000_000)

		// Add delegation
		err := addDelegation(staker, bob, amount, 5)
		uassert.NoError(t, err)

		// Remove full amount
		removed, err := removeDelegation(staker, bob, amount)
		uassert.NoError(t, err)
		uassert.Equal(t, amount, removed)

		// Check delegation was removed
		_, exists := staker.Delegations[bob]
		uassert.False(t, exists)

		// Check total staked
		uassert.Equal(t, uint64(0), staker.TotalStaked)
	})

	t.Run("remove partial delegation", func(t *testing.T) {
		staker := NewStakerState(alice)
		initialAmount := uint64(100_000_000)
		removeAmount := uint64(30_000_000)

		// Add delegation
		err := addDelegation(staker, bob, initialAmount, 5)
		uassert.NoError(t, err)

		// Remove partial amount
		removed, err := removeDelegation(staker, bob, removeAmount)
		uassert.NoError(t, err)
		uassert.Equal(t, removeAmount, removed)

		// Check remaining delegation
		delegation := staker.Delegations[bob]
		uassert.Equal(t, initialAmount-removeAmount, delegation.Amount)

		// Check total staked
		uassert.Equal(t, initialAmount-removeAmount, staker.TotalStaked)
	})

	t.Run("remove more than delegated", func(t *testing.T) {
		staker := NewStakerState(alice)
		amount := uint64(50_000_000)

		// Add delegation
		err := addDelegation(staker, bob, amount, 5)
		uassert.NoError(t, err)

		// Try to remove more than delegated
		removed, err := removeDelegation(staker, bob, amount+1)
		uassert.NoError(t, err)
		uassert.Equal(t, amount, removed) // Only removes what's available

		// Check delegation was removed
		_, exists := staker.Delegations[bob]
		uassert.False(t, exists)
	})

	t.Run("remove from non-existent delegation", func(t *testing.T) {
		staker := NewStakerState(alice)

		// Try to remove from non-existent delegation
		removed, err := removeDelegation(staker, bob, 100)
		uassert.ErrorIs(t, err, ErrNoDelegation)
		uassert.Equal(t, uint64(0), removed)
	})

	t.Run("multiple delegations", func(t *testing.T) {
		staker := NewStakerState(alice)

		// Add multiple delegations
		err := addDelegation(staker, bob, 50_000_000, 5)
		uassert.NoError(t, err)
		err = addDelegation(staker, charlie, 30_000_000, 5)
		uassert.NoError(t, err)

		// Remove from one delegation
		removed, err := removeDelegation(staker, bob, 50_000_000)
		println("removed", removed)
		uassert.NoError(t, err)

		// Check only bob's delegation was removed
		_, bobExists := staker.Delegations[bob]
		uassert.False(t, bobExists)

		charlieDeleg, charlieExists := staker.Delegations[charlie]
		uassert.True(t, charlieExists)
		uassert.Equal(t, uint64(30_000_000), charlieDeleg.Amount)

		// Check total staked
		uassert.Equal(t, uint64(30_000_000), staker.TotalStaked)
	})
}
