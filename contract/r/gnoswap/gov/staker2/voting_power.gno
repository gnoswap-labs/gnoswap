package staker2

import (
	"std"
)

// VotingPowerSnapshot represents voting power at a specific epoch
type VotingPowerSnapshot struct {
	Epoch           uint64
	TotalPower      uint64                      // Cumulative voting power
	DelegatorPowers map[std.Address]uint64      // Individual delegator contributions
}

// NewVotingPowerSnapshot creates a new voting power snapshot
func NewVotingPowerSnapshot(epoch uint64) *VotingPowerSnapshot {
	return &VotingPowerSnapshot{
		Epoch:           epoch,
		TotalPower:      0,
		DelegatorPowers: make(map[std.Address]uint64),
	}
}

// CopyVotingPowerSnapshot creates a deep copy of a snapshot
func CopyVotingPowerSnapshot(source *VotingPowerSnapshot, newEpoch uint64) *VotingPowerSnapshot {
	snapshot := &VotingPowerSnapshot{
		Epoch:           newEpoch,
		TotalPower:      source.TotalPower,
		DelegatorPowers: make(map[std.Address]uint64),
	}
	
	// Deep copy delegator powers
	for addr, power := range source.DelegatorPowers {
		snapshot.DelegatorPowers[addr] = power
	}
	
	return snapshot
}

// VotingPowerManager manages voting power snapshots
type VotingPowerManager struct {
	votingSnapshots map[std.Address][]*VotingPowerSnapshot // delegatee -> snapshots
}

// NewVotingPowerManager creates a new voting power manager
func NewVotingPowerManager() *VotingPowerManager {
	return &VotingPowerManager{
		votingSnapshots: make(map[std.Address][]*VotingPowerSnapshot),
	}
}

// UpdateVotingPower updates voting power for a delegatee (fixes Audit #2)
func (vpm *VotingPowerManager) UpdateVotingPower(delegatee std.Address, delegator std.Address, deltaAmount int64, epoch uint64) error {
	// Get or create snapshot history
	snapshots, exists := vpm.votingSnapshots[delegatee]
	if !exists {
		snapshots = []*VotingPowerSnapshot{}
	}
	
	// Get latest snapshot or create new one
	var newSnapshot *VotingPowerSnapshot
	if len(snapshots) > 0 {
		latest := snapshots[len(snapshots)-1]
		newSnapshot = CopyVotingPowerSnapshot(latest, epoch)
	} else {
		newSnapshot = NewVotingPowerSnapshot(epoch)
	}
	
	// Update delegator power
	currentPower := newSnapshot.DelegatorPowers[delegator]
	newPower := int64(currentPower) + deltaAmount
	
	// Validate no negative power
	if newPower < 0 {
		return ErrInsufficientBalance
	}
	
	// Update or remove delegator
	if newPower == 0 {
		delete(newSnapshot.DelegatorPowers, delegator)
	} else {
		newSnapshot.DelegatorPowers[delegator] = uint64(newPower)
	}
	
	// Update total power (cumulative)
	newTotal := int64(newSnapshot.TotalPower) + deltaAmount
	if newTotal < 0 {
		// This should not happen if individual validations pass
		panic("negative total voting power")
	}
	newSnapshot.TotalPower = uint64(newTotal)
	
	// Append new snapshot
	vpm.votingSnapshots[delegatee] = append(snapshots, newSnapshot)
	
	return nil
}

// GetLatestSnapshot returns the most recent voting power snapshot
func (vpm *VotingPowerManager) GetLatestSnapshot(delegatee std.Address) *VotingPowerSnapshot {
	snapshots, exists := vpm.votingSnapshots[delegatee]
	if !exists || len(snapshots) == 0 {
		return nil
	}
	return snapshots[len(snapshots)-1]
}

// GetSnapshotAtEpoch returns the voting power snapshot at a specific epoch
func (vpm *VotingPowerManager) GetSnapshotAtEpoch(delegatee std.Address, epoch uint64) *VotingPowerSnapshot {
	snapshots, exists := vpm.votingSnapshots[delegatee]
	if !exists {
		return nil
	}
	
	// Find snapshot at or before the requested epoch
	for i := len(snapshots) - 1; i >= 0; i-- {
		if snapshots[i].Epoch <= epoch {
			return snapshots[i]
		}
	}
	
	return nil
}

// GetVotingPowerAtEpoch returns the total voting power at a specific epoch
func (vpm *VotingPowerManager) GetVotingPowerAtEpoch(delegatee std.Address, epoch uint64) uint64 {
	snapshot := vpm.GetSnapshotAtEpoch(delegatee, epoch)
	if snapshot == nil {
		return 0
	}
	return snapshot.TotalPower
}

// GetSnapshotHistory returns all snapshots for a delegatee
func (vpm *VotingPowerManager) GetSnapshotHistory(delegatee std.Address) []*VotingPowerSnapshot {
	snapshots, exists := vpm.votingSnapshots[delegatee]
	if !exists {
		return []*VotingPowerSnapshot{}
	}
	return snapshots
}

// CleanupEmptyRecords removes completely empty voting records (fixes Audit #3)
func (vpm *VotingPowerManager) CleanupEmptyRecords() int {
	removed := 0
	
	for delegatee, snapshots := range vpm.votingSnapshots {
		if len(snapshots) == 0 {
			delete(vpm.votingSnapshots, delegatee)
			removed++
			continue
		}
		
		// Check latest snapshot
		latest := snapshots[len(snapshots)-1]
		if latest.TotalPower == 0 && len(latest.DelegatorPowers) == 0 {
			// Completely empty - remove entire record
			delete(vpm.votingSnapshots, delegatee)
			removed++
		}
	}
	
	return removed
}