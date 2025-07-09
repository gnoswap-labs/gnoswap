package staker2

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"
)

// EpochManager manages epoch transitions and finalization
type EpochManager struct {
	currentEpoch  uint64
	epochDuration uint64 // blocks per epoch
	lastFinalized uint64
	finalized     *avl.Tree // epoch -> bool
}

// NewEpochManager creates a new epoch manager
func NewEpochManager(epochDuration uint64) *EpochManager {
	if epochDuration == 0 {
		panic("epoch duration must be greater than 0")
	}

	return &EpochManager{
		currentEpoch:  0,
		epochDuration: epochDuration,
		lastFinalized: 0,
		finalized:     avl.NewTree(),
	}
}

// GetCurrentEpoch returns the current epoch
func (em *EpochManager) GetCurrentEpoch() uint64 {
	return em.currentEpoch
}

// GetEpochDuration returns the duration of each epoch in blocks
func (em *EpochManager) GetEpochDuration() uint64 {
	return em.epochDuration
}

// GetLastFinalized returns the last finalized epoch
func (em *EpochManager) GetLastFinalized() uint64 {
	return em.lastFinalized
}

// ShouldTransition checks if epoch should transition based on current block height
func (em *EpochManager) ShouldTransition() bool {
	// currentHeight := getBlockHeight()
	currentHeight := uint64(std.ChainHeight())
	nextEpochStart := (em.currentEpoch + 1) * em.epochDuration
	return currentHeight >= nextEpochStart
}

// TransitionEpoch moves to the next epoch
func (em *EpochManager) TransitionEpoch() {
	em.currentEpoch++
}

// GetEpochForHeight calculates which epoch a given height belongs to
func (em *EpochManager) GetEpochForHeight(height uint64) uint64 {
	return height / em.epochDuration
}

// IsEpochFinalized checks if an epoch has been finalized
func (em *EpochManager) IsEpochFinalized(epoch uint64) bool {
	_, exists := em.finalized.Get(ufmt.Sprintf("%d", epoch))
	return exists
}

// MarkEpochFinalized marks an epoch as finalized
func (em *EpochManager) MarkEpochFinalized(epoch uint64) {
	// Check if trying to finalize out of order
	if epoch > 0 && !em.IsEpochFinalized(epoch-1) {
		panic(ufmt.Sprintf("cannot finalize epoch %d: epoch %d not finalized", epoch, epoch-1))
	}

	em.finalized.Set(ufmt.Sprintf("%d", epoch), true)
	em.lastFinalized = epoch
}

// GetEpochBounds returns the start and end heights for an epoch
func (em *EpochManager) GetEpochBounds(epoch uint64) (startHeight, endHeight uint64) {
	startHeight = epoch * em.epochDuration
	endHeight = startHeight + em.epochDuration - 1
	return
}
