package staker2

import (
	"std"

	u256 "gno.land/p/gnoswap/uint256"
)

// Q128 is the precision for fixed-point arithmetic (2^128)
var Q128 = u256.MustFromDecimal("340282366920938463463374607431768211456")

// EpochState represents the state of a single epoch
type EpochState struct {
	Epoch               uint64
	StartHeight         uint64
	EndHeight           uint64
	TotalStaked         uint64
	GNSRewardPerStake   *u256.Uint
	ProtocolFeePerStake map[string]*u256.Uint
	Finalized           bool
}

// NewEpochState creates a new epoch state
func NewEpochState(epoch, startHeight, endHeight uint64) *EpochState {
	return &EpochState{
		Epoch:               epoch,
		StartHeight:         startHeight,
		EndHeight:           endHeight,
		TotalStaked:         0,
		GNSRewardPerStake:   u256.Zero(),
		ProtocolFeePerStake: make(map[string]*u256.Uint),
		Finalized:           false,
	}
}

// AddGNSReward adds GNS reward to the epoch
func (es *EpochState) AddGNSReward(amount uint64) {
	if es.TotalStaked == 0 {
		return // No stakers to distribute to
	}

	// Calculate reward per stake with Q128 precision
	rewardU256 := u256.NewUint(amount)
	rewardU256 = rewardU256.Mul(rewardU256, Q128)
	rewardU256 = rewardU256.Div(rewardU256, u256.NewUint(es.TotalStaked))

	es.GNSRewardPerStake = es.GNSRewardPerStake.Add(es.GNSRewardPerStake, rewardU256)
}

// AddProtocolFee adds protocol fee for a specific token
func (es *EpochState) AddProtocolFee(token string, amount uint64) {
	if es.TotalStaked == 0 {
		return // No stakers to distribute to
	}

	// Calculate fee per stake with Q128 precision
	feeU256 := u256.NewUint(amount)
	feeU256 = feeU256.Mul(feeU256, Q128)
	feeU256 = feeU256.Div(feeU256, u256.NewUint(es.TotalStaked))

	if existing, exists := es.ProtocolFeePerStake[token]; exists {
		es.ProtocolFeePerStake[token] = existing.Add(existing, feeU256)
	} else {
		es.ProtocolFeePerStake[token] = feeU256
	}
}

// RewardSnapshot represents a staker's reward checkpoint
type RewardSnapshot struct {
	Epoch                  uint64
	AccGNSRewardPerStake   *u256.Uint
	AccProtocolFeePerStake map[string]*u256.Uint
}

// NewRewardSnapshot creates a new empty reward snapshot
func NewRewardSnapshot(epoch uint64) *RewardSnapshot {
	return &RewardSnapshot{
		Epoch:                  epoch,
		AccGNSRewardPerStake:   u256.Zero(),
		AccProtocolFeePerStake: make(map[string]*u256.Uint),
	}
}

// NewRewardSnapshotFromEpoch creates a snapshot from epoch state
func NewRewardSnapshotFromEpoch(es *EpochState) *RewardSnapshot {
	snapshot := &RewardSnapshot{
		Epoch:                  es.Epoch,
		AccGNSRewardPerStake:   es.GNSRewardPerStake.Clone(),
		AccProtocolFeePerStake: make(map[string]*u256.Uint),
	}

	// Copy protocol fees
	for token, fee := range es.ProtocolFeePerStake {
		snapshot.AccProtocolFeePerStake[token] = fee.Clone()
	}

	return snapshot
}

// DelegationInfo represents delegation details
type DelegationInfo struct {
	Amount     uint64
	StartEpoch uint64
}

// LockedGNSInfo represents locked GNS tokens pending unlock
type LockedGNSInfo struct {
	Amount     uint64
	UnlockTime int64
}

// IsUnlocked checks if the GNS can be claimed
func (l *LockedGNSInfo) IsUnlocked(currentTime int64) bool {
	return currentTime >= l.UnlockTime
}

// StakerState represents the complete state of a staker
type StakerState struct {
	Address         std.Address
	TotalStaked     uint64                         // Total xGNS amount
	Delegations     map[std.Address]DelegationInfo // to -> delegation info
	RewardSnapshot  *RewardSnapshot                // Last reward checkpoint
	LockedGNS       []LockedGNSInfo                // Pending unlocks
	LastUpdateEpoch uint64                         // Last epoch this was updated
}

// NewStakerState creates a new staker state
func NewStakerState(address std.Address) *StakerState {
	return &StakerState{
		Address:         address,
		TotalStaked:     0,
		Delegations:     make(map[std.Address]DelegationInfo),
		RewardSnapshot:  NewRewardSnapshot(0),
		LockedGNS:       []LockedGNSInfo{},
		LastUpdateEpoch: 0,
	}
}
