package staker2

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// TestEpochManager_Initialization tests the epoch manager initialization
func TestEpochManager_Initialization(t *testing.T) {
	t.Run("should initialize with default values", func(t *testing.T) {
		em := NewEpochManager(7200) // 24 hours worth of blocks

		uassert.Equal(t, uint64(0), em.GetCurrentEpoch())
		uassert.Equal(t, uint64(7200), em.GetEpochDuration())
		uassert.Equal(t, uint64(0), em.GetLastFinalized())
	})

	t.Run("should panic with zero duration", func(t *testing.T) {
		uassert.PanicsWithMessage(t, "epoch duration must be greater than 0", func() {
			NewEpochManager(0)
		})
	})
}

func TestEpochManager_ShouldTransition(t *testing.T) {
	// Test basic epoch transition logic without relying on block height
	t.Run("epoch transitions", func(t *testing.T) {
		em := NewEpochManager(100) // 100 blocks per epoch

		// Initially at epoch 0
		uassert.Equal(t, uint64(0), em.GetCurrentEpoch())

		// Transition to epoch 1
		em.TransitionEpoch()
		uassert.Equal(t, uint64(1), em.GetCurrentEpoch())

		// Transition to epoch 2
		em.TransitionEpoch()
		uassert.Equal(t, uint64(2), em.GetCurrentEpoch())
	})
}

// TestEpochManager_GetEpochForHeight tests epoch calculation for given height
func TestEpochManager_GetEpochForHeight(t *testing.T) {
	em := NewEpochManager(100)

	testCases := []struct {
		height        uint64
		expectedEpoch uint64
	}{
		{0, 0},
		{50, 0},
		{99, 0},
		{100, 1},
		{101, 1},
		{199, 1},
		{200, 2},
		{1000, 10},
	}

	for _, tc := range testCases {
		t.Run("", func(t *testing.T) {
			epoch := em.GetEpochForHeight(tc.height)
			uassert.Equal(t, tc.expectedEpoch, epoch)
		})
	}
}

// TestEpochManager_Finalization tests epoch finalization tracking
func TestEpochManager_Finalization(t *testing.T) {
	em := NewEpochManager(100)

	// Initially no epoch is finalized
	uassert.False(t, em.IsEpochFinalized(0))

	// Mark epoch 0 as finalized
	em.MarkEpochFinalized(0)
	uassert.True(t, em.IsEpochFinalized(0))
	uassert.Equal(t, uint64(0), em.GetLastFinalized())

	// Cannot finalize out of order
	uassert.PanicsWithMessage(t, "cannot finalize epoch 2: epoch 1 not finalized", func() {
		em.MarkEpochFinalized(2)
	})

	// Finalize epoch 1
	em.MarkEpochFinalized(1)
	uassert.True(t, em.IsEpochFinalized(1))
	uassert.Equal(t, uint64(1), em.GetLastFinalized())
}

// TestEpochManager_GetEpochBounds tests epoch boundary calculations
func TestEpochManager_GetEpochBounds(t *testing.T) {
	em := NewEpochManager(100)

	testCases := []struct {
		epoch       uint64
		startHeight uint64
		endHeight   uint64
	}{
		{0, 0, 99},
		{1, 100, 199},
		{2, 200, 299},
		{10, 1000, 1099},
	}

	for _, tc := range testCases {
		t.Run("", func(t *testing.T) {
			start, end := em.GetEpochBounds(tc.epoch)
			uassert.Equal(t, tc.startHeight, start)
			uassert.Equal(t, tc.endHeight, end)
		})
	}
}
