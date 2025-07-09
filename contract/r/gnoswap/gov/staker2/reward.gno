package staker2

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// calculatePendingReward calculates pending rewards for a staker (fixes Audit #1)
// This function correctly calculates only the delta between current and last claimed rewards
func calculatePendingReward(staker *StakerState, currentEpoch *EpochState) (gnsReward uint64, protocolFees map[string]uint64) {
	if staker.TotalStaked == 0 {
		return 0, make(map[string]uint64)
	}

	// Calculate GNS reward delta
	// Delta = (current accumulated - snapshot accumulated) * stake / Q128
	deltaGNS := u256.Zero()
	if currentEpoch.GNSRewardPerStake.Gt(staker.RewardSnapshot.AccGNSRewardPerStake) {
		deltaGNS = u256.Zero().Sub(currentEpoch.GNSRewardPerStake, staker.RewardSnapshot.AccGNSRewardPerStake)
	}

	// Calculate actual GNS reward
	if !deltaGNS.IsZero() {
		reward := u256.Zero().Mul(deltaGNS, u256.NewUint(staker.TotalStaked))
		reward = reward.Div(reward, Q128)
		gnsReward = reward.Uint64()
	}

	// Calculate protocol fee rewards
	protocolFees = make(map[string]uint64)
	for token, currentAcc := range currentEpoch.ProtocolFeePerStake {
		snapshotAcc := staker.RewardSnapshot.AccProtocolFeePerStake[token]
		if snapshotAcc == nil {
			snapshotAcc = u256.Zero()
		}

		if currentAcc.Gt(snapshotAcc) {
			deltaFee := u256.Zero().Sub(currentAcc, snapshotAcc)
			feeReward := u256.Zero().Mul(deltaFee, u256.NewUint(staker.TotalStaked))
			feeReward = feeReward.Div(feeReward, Q128)
			if !feeReward.IsZero() {
				protocolFees[token] = feeReward.Uint64()
			}
		}
	}

	return gnsReward, protocolFees
}

// updateRewardSnapshot updates the staker's reward snapshot after claiming
func updateRewardSnapshot(staker *StakerState, currentEpoch *EpochState) {
	// Create new snapshot from current epoch state
	staker.RewardSnapshot = &RewardSnapshot{
		Epoch:                  currentEpoch.Epoch,
		AccGNSRewardPerStake:   currentEpoch.GNSRewardPerStake.Clone(),
		AccProtocolFeePerStake: make(map[string]*u256.Uint),
	}

	// Copy all protocol fee accumulations
	for token, acc := range currentEpoch.ProtocolFeePerStake {
		staker.RewardSnapshot.AccProtocolFeePerStake[token] = acc.Clone()
	}

	staker.LastUpdateEpoch = currentEpoch.Epoch
}

// RewardManager manages reward distribution and claiming
type RewardManager struct {
	epochs map[uint64]*EpochState // epoch -> state
}

// NewRewardManager creates a new reward manager
func NewRewardManager() *RewardManager {
	return &RewardManager{
		epochs: make(map[uint64]*EpochState),
	}
}

// GetOrCreateEpoch gets or creates an epoch state
func (rm *RewardManager) GetOrCreateEpoch(epoch uint64) *EpochState {
	if es, exists := rm.epochs[epoch]; exists {
		return es
	}

	// Create new epoch state
	es := NewEpochState(epoch, 0, 0) // Heights will be set by epoch manager
	rm.epochs[epoch] = es
	return es
}

// UpdateStakerReward updates a staker's reward state
func (rm *RewardManager) UpdateStakerReward(staker *StakerState, currentEpoch uint64) {
	epochState := rm.GetOrCreateEpoch(currentEpoch)

	// Update epoch total if needed
	if staker.LastUpdateEpoch < currentEpoch {
		epochState.TotalStaked += staker.TotalStaked
	}
}

// AddGNSReward adds GNS rewards to an epoch
func (rm *RewardManager) AddGNSReward(epoch uint64, totalStaked uint64, amount uint64) {
	epochState := rm.GetOrCreateEpoch(epoch)
	epochState.TotalStaked = totalStaked
	epochState.AddGNSReward(amount)
}

// AddProtocolFee adds protocol fee to an epoch
func (rm *RewardManager) AddProtocolFee(epoch uint64, totalStaked uint64, token string, amount uint64) {
	epochState := rm.GetOrCreateEpoch(epoch)
	epochState.TotalStaked = totalStaked
	epochState.AddProtocolFee(token, amount)
}

// CalculatePendingReward calculates pending rewards for a staker
func (rm *RewardManager) CalculatePendingReward(staker *StakerState, currentEpoch uint64) (uint64, map[string]uint64) {
	epochState := rm.GetOrCreateEpoch(currentEpoch)
	return calculatePendingReward(staker, epochState)
}

// ClaimReward claims rewards for a staker and updates their snapshot
func (rm *RewardManager) ClaimReward(staker *StakerState, currentEpoch uint64) (gnsAmount uint64, protocolFees map[string]uint64) {
	epochState := rm.GetOrCreateEpoch(currentEpoch)

	// Calculate pending rewards
	gnsAmount, protocolFees = calculatePendingReward(staker, epochState)

	// Update snapshot to prevent double claiming
	updateRewardSnapshot(staker, epochState)

	return gnsAmount, protocolFees
}
