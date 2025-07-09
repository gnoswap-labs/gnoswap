package staker2

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestVotingPowerSnapshot_Creation tests voting power snapshot creation
func TestVotingPowerSnapshot_Creation(t *testing.T) {
	t.Run("should create new voting power snapshot", func(t *testing.T) {
		snapshot := NewVotingPowerSnapshot(5)

		uassert.Equal(t, uint64(5), snapshot.Epoch)
		uassert.Equal(t, uint64(0), snapshot.TotalPower)
		uassert.Equal(t, 0, len(snapshot.DelegatorPowers))
	})

	t.Run("should create from existing snapshot", func(t *testing.T) {
		existing := &VotingPowerSnapshot{
			Epoch:      3,
			TotalPower: 100_000_000,
			DelegatorPowers: map[std.Address]uint64{
				std.Address("alice"): 60_000_000,
				std.Address("bob"):   40_000_000,
			},
		}

		newSnapshot := CopyVotingPowerSnapshot(existing, 4)

		uassert.Equal(t, uint64(4), newSnapshot.Epoch)
		uassert.Equal(t, existing.TotalPower, newSnapshot.TotalPower)
		uassert.Equal(t, len(existing.DelegatorPowers), len(newSnapshot.DelegatorPowers))

		// Verify deep copy
		newSnapshot.DelegatorPowers[std.Address("alice")] = 70_000_000
		uassert.Equal(t, uint64(60_000_000), existing.DelegatorPowers[std.Address("alice")])
	})
}

// TestUpdateVotingPower tests voting power update logic (fixes Audit #2)
func TestUpdateVotingPower(t *testing.T) {
	delegatee := std.Address("validator1")
	alice := std.Address("alice")
	bob := std.Address("bob")

	// Initialize voting power manager
	vpm := NewVotingPowerManager()

	t.Run("should handle first delegation", func(t *testing.T) {
		err := vpm.UpdateVotingPower(delegatee, alice, 50_000_000, 1)
		uassert.NoError(t, err)

		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(50_000_000), snapshot.TotalPower)
		uassert.Equal(t, uint64(50_000_000), snapshot.DelegatorPowers[alice])
		uassert.Equal(t, uint64(1), snapshot.Epoch)
	})

	t.Run("should handle additional delegation from same user", func(t *testing.T) {
		// Alice delegates more
		err := vpm.UpdateVotingPower(delegatee, alice, 30_000_000, 2)
		uassert.NoError(t, err)

		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(80_000_000), snapshot.TotalPower) // 50M + 30M
		uassert.Equal(t, uint64(80_000_000), snapshot.DelegatorPowers[alice])
		uassert.Equal(t, uint64(2), snapshot.Epoch)
	})

	t.Run("should handle delegation from another user", func(t *testing.T) {
		// Bob delegates
		err := vpm.UpdateVotingPower(delegatee, bob, 40_000_000, 3)
		uassert.NoError(t, err)

		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(120_000_000), snapshot.TotalPower) // 80M + 40M
		uassert.Equal(t, uint64(80_000_000), snapshot.DelegatorPowers[alice])
		uassert.Equal(t, uint64(40_000_000), snapshot.DelegatorPowers[bob])
		uassert.Equal(t, uint64(3), snapshot.Epoch)
	})

	t.Run("should handle undelegation correctly", func(t *testing.T) {
		// Alice undelegates partially
		err := vpm.UpdateVotingPower(delegatee, alice, -30_000_000, 4)
		uassert.NoError(t, err)

		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(90_000_000), snapshot.TotalPower)             // 120M - 30M
		uassert.Equal(t, uint64(50_000_000), snapshot.DelegatorPowers[alice]) // 80M - 30M
		uassert.Equal(t, uint64(40_000_000), snapshot.DelegatorPowers[bob])
		uassert.Equal(t, uint64(4), snapshot.Epoch)
	})

	t.Run("should remove delegator when power reaches zero", func(t *testing.T) {
		// Alice undelegates completely
		err := vpm.UpdateVotingPower(delegatee, alice, -50_000_000, 5)
		uassert.NoError(t, err)

		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(40_000_000), snapshot.TotalPower) // Only Bob's delegation remains
		_, aliceExists := snapshot.DelegatorPowers[alice]
		uassert.False(t, aliceExists) // Alice should be removed
		uassert.Equal(t, uint64(40_000_000), snapshot.DelegatorPowers[bob])
		uassert.Equal(t, uint64(5), snapshot.Epoch)
	})

	t.Run("should handle negative total power gracefully", func(t *testing.T) {
		// Try to undelegate more than total (should be prevented)
		err := vpm.UpdateVotingPower(delegatee, bob, -50_000_000, 6) // Bob only has 40M
		uassert.ErrorIs(t, err, ErrInsufficientBalance)

		// Verify state unchanged
		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(40_000_000), snapshot.TotalPower)
		uassert.Equal(t, uint64(5), snapshot.Epoch) // Epoch should not advance on error
	})
}

// TestVotingPowerHistory tests voting power history management
func TestVotingPowerHistory(t *testing.T) {
	vpm := NewVotingPowerManager()
	delegatee := std.Address("validator1")
	alice := std.Address("alice")

	t.Run("should maintain history of snapshots", func(t *testing.T) {
		// Create multiple snapshots
		for i := uint64(1); i <= 5; i++ {
			err := vpm.UpdateVotingPower(delegatee, alice, 10_000_000, i)
			uassert.NoError(t, err)
		}

		// Check history
		history := vpm.GetSnapshotHistory(delegatee)
		uassert.Equal(t, 5, len(history))

		// Verify each snapshot
		for i, snapshot := range history {
			uassert.Equal(t, uint64(i+1), snapshot.Epoch)
			uassert.Equal(t, uint64((i+1)*10_000_000), snapshot.TotalPower)
		}
	})

	t.Run("should get snapshot at specific epoch", func(t *testing.T) {
		snapshot := vpm.GetSnapshotAtEpoch(delegatee, 3)
		uassert.NotNil(t, snapshot)
		uassert.Equal(t, uint64(3), snapshot.Epoch)
		uassert.Equal(t, uint64(30_000_000), snapshot.TotalPower)
	})

	t.Run("should return latest snapshot for future epoch", func(t *testing.T) {
		snapshot := vpm.GetSnapshotAtEpoch(delegatee, 10)
		uassert.NotNil(t, snapshot)
		uassert.Equal(t, uint64(5), snapshot.Epoch) // Should return the latest available snapshot
		uassert.Equal(t, uint64(50_000_000), snapshot.TotalPower)
	})
	
	t.Run("should return nil for non-existent delegatee", func(t *testing.T) {
		nonExistent := std.Address("nonexistent")
		snapshot := vpm.GetSnapshotAtEpoch(nonExistent, 3)
		uassert.True(t, snapshot == nil)
	})
}

// TestCleanupEmptyRecords tests the cleanup mechanism (fixes Audit #3)
func TestCleanupEmptyRecords(t *testing.T) {
	vpm := NewVotingPowerManager()

	t.Run("should not remove records with positive power", func(t *testing.T) {
		// Setup
		delegatee1 := std.Address("validator1")
		delegatee2 := std.Address("validator2")
		alice := std.Address("alice")

		vpm.UpdateVotingPower(delegatee1, alice, 50_000_000, 1)
		vpm.UpdateVotingPower(delegatee2, alice, 30_000_000, 1)

		// Clean up
		removed := vpm.CleanupEmptyRecords()
		uassert.Equal(t, 0, removed)

		// Verify both records still exist
		uassert.NotNil(t, vpm.GetLatestSnapshot(delegatee1))
		uassert.NotNil(t, vpm.GetLatestSnapshot(delegatee2))
	})

	t.Run("should remove completely empty records", func(t *testing.T) {
		delegatee := std.Address("validator3")
		alice := std.Address("alice")

		// Delegate and then completely undelegate
		vpm.UpdateVotingPower(delegatee, alice, 50_000_000, 1)
		vpm.UpdateVotingPower(delegatee, alice, -50_000_000, 2)

		// Before cleanup
		snapshot := vpm.GetLatestSnapshot(delegatee)
		uassert.Equal(t, uint64(0), snapshot.TotalPower)
		uassert.Equal(t, 0, len(snapshot.DelegatorPowers))

		// Clean up
		removed := vpm.CleanupEmptyRecords()
		uassert.Equal(t, 1, removed)

		// After cleanup - record should be completely removed
		snapshot = vpm.GetLatestSnapshot(delegatee)
		uassert.True(t, snapshot == nil)
	})

	t.Run("should not remove records with zero power but existing delegators", func(t *testing.T) {
		// This shouldn't happen in practice, but test defensive programming
		delegatee := std.Address("validator4")

		// Manually create inconsistent state for testing
		snapshot := &VotingPowerSnapshot{
			Epoch:      1,
			TotalPower: 0,
			DelegatorPowers: map[std.Address]uint64{
				std.Address("alice"): 100, // Inconsistent state
			},
		}
		vpm.votingSnapshots[delegatee] = []*VotingPowerSnapshot{snapshot}

		// Clean up should not remove this (inconsistent state needs investigation)
		removed := vpm.CleanupEmptyRecords()
		uassert.Equal(t, 0, removed)

		// Record should still exist
		uassert.NotNil(t, vpm.GetLatestSnapshot(delegatee))
	})
}

// TestGetVotingPowerAtEpoch tests retrieving voting power for governance
func TestGetVotingPowerAtEpoch(t *testing.T) {
	vpm := NewVotingPowerManager()
	delegatee := std.Address("validator1")
	alice := std.Address("alice")
	bob := std.Address("bob")

	// Build history
	vpm.UpdateVotingPower(delegatee, alice, 50_000_000, 1)
	vpm.UpdateVotingPower(delegatee, bob, 30_000_000, 2)
	vpm.UpdateVotingPower(delegatee, alice, 20_000_000, 3)
	vpm.UpdateVotingPower(delegatee, alice, -30_000_000, 4)

	testCases := []struct {
		epoch         uint64
		expectedPower uint64
		description   string
	}{
		{1, 50_000_000, "epoch 1: only Alice"},
		{2, 80_000_000, "epoch 2: Alice + Bob"},
		{3, 100_000_000, "epoch 3: Alice increased"},
		{4, 70_000_000, "epoch 4: Alice decreased"},
		{5, 70_000_000, "epoch 5: use latest available"},
	}

	for _, tc := range testCases {
		t.Run(tc.description, func(t *testing.T) {
			power := vpm.GetVotingPowerAtEpoch(delegatee, tc.epoch)
			uassert.Equal(t, tc.expectedPower, power)
		})
	}
}
