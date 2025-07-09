package staker2

import (
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
)

// TestStakerManager_Creation tests staker manager creation
func TestStakerManager_Creation(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()

	sm := NewStakerManager(em, vpm, rm)

	uassert.NotNil(t, sm)
	uassert.Equal(t, uint64(0), sm.GetTotalStaked())
}

// TestStakerManager_GetOrCreateStaker tests staker creation and retrieval
func TestStakerManager_GetOrCreateStaker(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")

	t.Run("should create new staker", func(t *testing.T) {
		staker := sm.GetOrCreateStaker(alice)
		uassert.NotNil(t, staker)
		uassert.Equal(t, alice, staker.Address)
		uassert.Equal(t, uint64(0), staker.TotalStaked)
	})

	t.Run("should retrieve existing staker", func(t *testing.T) {
		// Modify the staker
		staker := sm.GetOrCreateStaker(alice)
		staker.TotalStaked = 1000000
		sm.stakers.Set(alice.String(), staker)

		// Retrieve again
		retrieved := sm.GetOrCreateStaker(alice)
		uassert.Equal(t, uint64(1000000), retrieved.TotalStaked)
	})

	t.Run("GetStaker should return nil for non-existent", func(t *testing.T) {
		bob := testutils.TestAddress("bob")
		staker := sm.GetStaker(bob)
		uassert.True(t, staker == nil)
	})
}

// TestStakerManager_UpdateDelegation tests delegation updates
func TestStakerManager_UpdateDelegation(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	validator1 := testutils.TestAddress("validator1")
	validator2 := testutils.TestAddress("validator2")

	t.Run("should handle first delegation", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator1, 50_000_000, true)
		uassert.NoError(t, err)

		// Check staker state
		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(50_000_000), staker.TotalStaked)
		uassert.Equal(t, 1, len(staker.Delegations))
		uassert.Equal(t, uint64(50_000_000), staker.Delegations[validator1].Amount)

		// Check total staked
		uassert.Equal(t, uint64(50_000_000), sm.GetTotalStaked())

		// Check voting power was updated
		snapshot := vpm.GetLatestSnapshot(validator1)
		uassert.Equal(t, uint64(50_000_000), snapshot.TotalPower)
	})

	t.Run("should handle additional delegation to same validator", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator1, 30_000_000, true)
		uassert.NoError(t, err)

		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(80_000_000), staker.TotalStaked)
		uassert.Equal(t, uint64(80_000_000), staker.Delegations[validator1].Amount)
		uassert.Equal(t, uint64(80_000_000), sm.GetTotalStaked())
	})

	t.Run("should handle delegation to another validator", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator2, 20_000_000, true)
		uassert.NoError(t, err)

		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(100_000_000), staker.TotalStaked)
		uassert.Equal(t, 2, len(staker.Delegations))
		uassert.Equal(t, uint64(20_000_000), staker.Delegations[validator2].Amount)
	})

	t.Run("should reject insufficient increment", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator1, 500_000, true) // Less than MIN_INCREMENT
		uassert.ErrorIs(t, err, ErrInsufficientIncrement)

		// State should be unchanged
		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(100_000_000), staker.TotalStaked)
	})

	t.Run("should handle undelegation", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator1, 30_000_000, false)
		uassert.NoError(t, err)

		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(70_000_000), staker.TotalStaked)
		uassert.Equal(t, uint64(50_000_000), staker.Delegations[validator1].Amount)
		uassert.Equal(t, uint64(70_000_000), sm.GetTotalStaked())
	})

	t.Run("should remove delegation when undelegating all", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator2, 20_000_000, false)
		uassert.NoError(t, err)

		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(50_000_000), staker.TotalStaked)
		uassert.Equal(t, 1, len(staker.Delegations))
		_, exists := staker.Delegations[validator2]
		uassert.False(t, exists)
	})

	t.Run("should reject undelegation with insufficient balance", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator1, 60_000_000, false) // More than delegated
		uassert.ErrorIs(t, err, ErrInsufficientBalance)
	})

	t.Run("should reject undelegation from non-existent delegation", func(t *testing.T) {
		err := sm.UpdateStakerDelegation(alice, validator2, 10_000_000, false)
		uassert.ErrorIs(t, err, ErrDelegationNotFound)
	})
}

// TestStakerManager_ProcessRewards tests reward processing
func TestStakerManager_ProcessRewards(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	validator1 := testutils.TestAddress("validator1")

	t.Run("should process rewards for staker", func(t *testing.T) {
		// Setup delegation
		err := sm.UpdateStakerDelegation(alice, validator1, 100_000_000, true)
		uassert.NoError(t, err)

		// Add rewards to epoch
		rm.AddGNSReward(0, 100_000_000, 10_000_000) // 10% reward
		rm.AddProtocolFee(0, 100_000_000, "USDC", 5_000_000)

		// Process rewards
		gnsReward, protocolFees, err := sm.ProcessRewards(alice)
		uassert.NoError(t, err)
		uassert.True(t, gnsReward > 0)
		uassert.True(t, protocolFees["USDC"] > 0)

		// Second claim should yield zero
		gnsReward2, protocolFees2, err := sm.ProcessRewards(alice)
		uassert.NoError(t, err)
		uassert.Equal(t, uint64(0), gnsReward2)
		uassert.Equal(t, 0, len(protocolFees2))
	})

	t.Run("should error for non-existent staker", func(t *testing.T) {
		bob := testutils.TestAddress("bob")
		_, _, err := sm.ProcessRewards(bob)
		uassert.ErrorIs(t, err, ErrStakerNotFound)
	})
}

// TestStakerManager_LockedGNS tests locked GNS management
func TestStakerManager_LockedGNS(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	validator1 := testutils.TestAddress("validator1")

	// Setup staker
	err := sm.UpdateStakerDelegation(alice, validator1, 100_000_000, true)
	uassert.NoError(t, err)

	t.Run("should add locked GNS", func(t *testing.T) {
		unlockTime := int64(1000)
		err := sm.AddLocked(alice, 50_000_000, unlockTime)
		uassert.NoError(t, err)

		staker := sm.GetStaker(alice)
		uassert.Equal(t, 1, len(staker.LockedGNS))
		uassert.Equal(t, uint64(50_000_000), staker.LockedGNS[0].Amount)
		uassert.Equal(t, unlockTime, staker.LockedGNS[0].UnlockTime)
	})

	t.Run("should collect unlocked GNS", func(t *testing.T) {
		// Add more locked GNS with different unlock times
		err := sm.AddLocked(alice, 30_000_000, 500) // Already unlockable
		uassert.NoError(t, err)
		err = sm.AddLocked(alice, 20_000_000, 2000) // Future unlock
		uassert.NoError(t, err)

		// Collect at time 1200
		collected, err := sm.CollectUnlocked(alice, 1200)
		uassert.NoError(t, err)
		uassert.Equal(t, uint64(80_000_000), collected) // 50M + 30M

		// Check remaining locked
		staker := sm.GetStaker(alice)
		uassert.Equal(t, 1, len(staker.LockedGNS))
		uassert.Equal(t, uint64(20_000_000), staker.LockedGNS[0].Amount)
	})

	t.Run("should handle no unlockable amounts", func(t *testing.T) {
		collected, err := sm.CollectUnlocked(alice, 1500) // Before unlock time
		uassert.NoError(t, err)
		uassert.Equal(t, uint64(0), collected)

		// Locked GNS should remain
		staker := sm.GetStaker(alice)
		uassert.Equal(t, 1, len(staker.LockedGNS))
	})
}

// TestStakerManager_GetStakerInfo tests staker info retrieval
func TestStakerManager_GetStakerInfo(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	validator1 := testutils.TestAddress("validator1")
	validator2 := testutils.TestAddress("validator2")

	t.Run("should return nil for non-existent staker", func(t *testing.T) {
		info := sm.GetStakerInfo(alice)
		uassert.True(t, info == nil)
	})

	t.Run("should return complete staker info", func(t *testing.T) {
		// Setup delegations
		err := sm.UpdateStakerDelegation(alice, validator1, 60_000_000, true)
		uassert.NoError(t, err)
		err = sm.UpdateStakerDelegation(alice, validator2, 40_000_000, true)
		uassert.NoError(t, err)

		// Add locked GNS
		err = sm.AddLocked(alice, 25_000_000, 1000)
		uassert.NoError(t, err)
		err = sm.AddLocked(alice, 15_000_000, 2000)
		uassert.NoError(t, err)

		// Add rewards
		rm.AddGNSReward(0, 100_000_000, 10_000_000)
		rm.AddProtocolFee(0, 100_000_000, "USDC", 5_000_000)

		// Get info
		info := sm.GetStakerInfo(alice)
		uassert.NotNil(t, info)
		uassert.Equal(t, alice, info.Address)
		uassert.Equal(t, uint64(100_000_000), info.TotalStaked)
		uassert.Equal(t, uint64(40_000_000), info.TotalLocked) // 25M + 15M
		uassert.Equal(t, 2, len(info.Delegations))
		uassert.True(t, info.PendingGNS > 0)
		uassert.True(t, info.PendingFees["USDC"] > 0)
	})
}

// TestStakerManager_TransitionEpoch tests epoch transition handling
func TestStakerManager_TransitionEpoch(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	bob := testutils.TestAddress("bob")
	validator1 := testutils.TestAddress("validator1")

	// Setup delegations
	err := sm.UpdateStakerDelegation(alice, validator1, 60_000_000, true)
	uassert.NoError(t, err)
	err = sm.UpdateStakerDelegation(bob, validator1, 40_000_000, true)
	uassert.NoError(t, err)

	// Transition epoch
	sm.TransitionEpoch(1)

	// Check that total staked was updated in reward manager
	epochState := rm.GetOrCreateEpoch(1)
	uassert.Equal(t, uint64(100_000_000), epochState.TotalStaked)
}

// TestStakerManager_AtomicOperations tests atomic operation guarantees
func TestStakerManager_AtomicOperations(t *testing.T) {
	em := NewEpochManager(100)
	vpm := NewVotingPowerManager()
	rm := NewRewardManager()
	sm := NewStakerManager(em, vpm, rm)

	alice := testutils.TestAddress("alice")
	validator1 := testutils.TestAddress("validator1")

	t.Run("should rollback on voting power error", func(t *testing.T) {
		// First delegation
		err := sm.UpdateStakerDelegation(alice, validator1, 50_000_000, true)
		uassert.NoError(t, err)

		// Create a situation where voting power update would fail
		// (trying to undelegate more than delegated through direct voting power update)
		vpm.UpdateVotingPower(validator1, alice, -100_000_000, 1)

		// This should fail and rollback
		err = sm.UpdateStakerDelegation(alice, validator1, 60_000_000, false)
		uassert.Error(t, err)

		// Check state was not changed
		staker := sm.GetStaker(alice)
		uassert.Equal(t, uint64(50_000_000), staker.TotalStaked)
		uassert.Equal(t, uint64(50_000_000), staker.Delegations[validator1].Amount)
		uassert.Equal(t, uint64(50_000_000), sm.GetTotalStaked())
	})
}
