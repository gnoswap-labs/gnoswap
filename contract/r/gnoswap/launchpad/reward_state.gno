package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// RewardState represents the state of a reward for a deposit.
// It contains the necessary data to manage and distribute rewards for a specific deposit.
type RewardState struct {
	priceDebtX128 *u256.Uint // price debt per GNS stake, Q128
	claimableTime int64      // time when reward can be claimed

	depositAmount           int64 // amount of GNS staked
	distributeStartTime     int64 // time when launchpad started staking
	distributeEndTime       int64 // end time of reward calculation
	accumulatedRewardAmount int64 // legacy field; v1 reward accounting does not populate it
	accumulatedTime         int64 // last time when reward was calculated
	claimedAmount           int64 // amount of reward claimed so far
}

// NewRewardState creates a reward state initialized from a reward-per-deposit index.
//
// Parameters:
//   - accumulatedRewardPerDepositX128: current accumulated reward-per-deposit index in Q128 fixed-point units; it becomes this deposit's initial price debt.
//   - depositAmount: GNS amount staked by the deposit, in base units.
//   - distributeStartTime: Unix timestamp in seconds when this deposit begins accruing rewards.
//   - distributeEndTime: Unix timestamp in seconds when this deposit stops accruing rewards.
//   - claimableTime: Unix timestamp in seconds after which the accrued reward can be claimed.
//
// Returns:
//   - rewardState: newly allocated state with claimed and legacy accumulation fields initialized to zero.
func NewRewardState(
	accumulatedRewardPerDepositX128 *u256.Uint,
	depositAmount,
	distributeStartTime,
	distributeEndTime int64,
	claimableTime int64,
) *RewardState {
	return &RewardState{
		priceDebtX128:           accumulatedRewardPerDepositX128,
		depositAmount:           depositAmount,
		distributeStartTime:     distributeStartTime,
		distributeEndTime:       distributeEndTime,
		claimableTime:           claimableTime,
		accumulatedRewardAmount: 0,
		claimedAmount:           0,
	}
}

// PriceDebtX128 returns the deposit's initial reward index debt in Q128 fixed-point units.
//
// Returns:
//   - debt: stored price debt used to subtract rewards accrued before this deposit joined.
func (rs *RewardState) PriceDebtX128() *u256.Uint {
	return rs.priceDebtX128
}

// SetPriceDebtX128 replaces the deposit's initial reward index debt.
//
// Parameters:
//   - debt: new price debt in Q128 fixed-point units; the value is copied into the state.
func (rs *RewardState) SetPriceDebtX128(debt *u256.Uint) {
	rs.priceDebtX128 = u256.Zero().Set(debt)
}

// ClaimableTime returns the earliest Unix timestamp at which this reward may be claimed.
//
// Returns:
//   - claimableTime: claimability timestamp in Unix seconds.
func (rs *RewardState) ClaimableTime() int64 {
	return rs.claimableTime
}

// SetClaimableTime sets the earliest Unix timestamp at which this reward may be claimed.
//
// Parameters:
//   - time: claimability timestamp in Unix seconds.
func (rs *RewardState) SetClaimableTime(time int64) {
	rs.claimableTime = time
}

// DepositAmount returns the GNS principal represented by this reward state.
//
// Returns:
//   - amount: staked GNS amount in base units used for reward allocation.
func (rs *RewardState) DepositAmount() int64 {
	return rs.depositAmount
}

// SetDepositAmount replaces the GNS principal represented by this reward state.
//
// Parameters:
//   - amount: staked GNS amount in base units used for reward allocation.
func (rs *RewardState) SetDepositAmount(amount int64) {
	rs.depositAmount = amount
}

// DistributeStartTime returns the Unix timestamp when this deposit starts accruing rewards.
//
// Returns:
//   - startTime: reward accrual start timestamp in Unix seconds.
func (rs *RewardState) DistributeStartTime() int64 {
	return rs.distributeStartTime
}

// SetDistributeStartTime sets the Unix timestamp when this deposit starts accruing rewards.
//
// Parameters:
//   - time: reward accrual start timestamp in Unix seconds.
func (rs *RewardState) SetDistributeStartTime(time int64) {
	rs.distributeStartTime = time
}

// DistributeEndTime returns the Unix timestamp when this deposit stops accruing rewards.
//
// Returns:
//   - endTime: reward accrual end timestamp in Unix seconds.
func (rs *RewardState) DistributeEndTime() int64 {
	return rs.distributeEndTime
}

// SetDistributeEndTime sets the Unix timestamp when this deposit stops accruing rewards.
//
// Parameters:
//   - time: reward accrual end timestamp in Unix seconds.
func (rs *RewardState) SetDistributeEndTime(time int64) {
	rs.distributeEndTime = time
}

// AccumulatedRewardAmount returns the legacy accumulated reward field.
//
// Returns:
//   - amount: legacy reward amount in token base units; v1 accounting normally leaves it at zero unless explicitly set.
func (rs *RewardState) AccumulatedRewardAmount() int64 {
	return rs.accumulatedRewardAmount
}

// SetAccumulatedRewardAmount sets the legacy accumulated reward field.
//
// Parameters:
//   - amount: legacy reward amount in token base units; v1 accounting does not update this field.
func (rs *RewardState) SetAccumulatedRewardAmount(amount int64) {
	rs.accumulatedRewardAmount = amount
}

// AccumulatedTime returns the last timestamp recorded for reward accumulation.
//
// Returns:
//   - time: last accumulated timestamp in Unix seconds, or zero before one is recorded.
func (rs *RewardState) AccumulatedTime() int64 {
	return rs.accumulatedTime
}

// SetAccumulatedTime sets the last timestamp recorded for reward accumulation.
//
// Parameters:
//   - time: last accumulated timestamp in Unix seconds.
func (rs *RewardState) SetAccumulatedTime(time int64) {
	rs.accumulatedTime = time
}

// ClaimedAmount returns the reward amount already claimed for this deposit.
//
// Returns:
//   - amount: claimed reward amount in token base units.
func (rs *RewardState) ClaimedAmount() int64 {
	return rs.claimedAmount
}

// SetClaimedAmount replaces the reward amount already claimed for this deposit.
//
// Parameters:
//   - amount: claimed reward amount in token base units.
func (rs *RewardState) SetClaimedAmount(amount int64) {
	rs.claimedAmount = amount
}

// Clone returns an independent copy of this reward state, including a cloned Q128 price debt value.
//
// Returns:
//   - rewardState: deep copy of the reward state that can be modified without changing the source.
func (rs RewardState) Clone() *RewardState {
	return &RewardState{
		priceDebtX128:           rs.priceDebtX128.Clone(),
		claimableTime:           rs.claimableTime,
		depositAmount:           rs.depositAmount,
		distributeStartTime:     rs.distributeStartTime,
		distributeEndTime:       rs.distributeEndTime,
		accumulatedRewardAmount: rs.accumulatedRewardAmount,
		accumulatedTime:         rs.accumulatedTime,
		claimedAmount:           rs.claimedAmount,
	}
}
