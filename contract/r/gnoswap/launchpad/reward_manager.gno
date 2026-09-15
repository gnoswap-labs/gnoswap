package launchpad

import (
	bptree "gno.land/p/nt/bptree/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

// RewardManager manages the distribution of rewards for a project tier.
//
// This struct contains the necessary data and methods to calculate and track
// rewards for deposits associated with a project tier.
//
// Fields:
// - rewards (bptree.BPTree): A map of deposit IDs to their associated reward states.
// - distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
// - accumulatedRewardPerDepositX128 (u256.Uint): The accumulated reward per GNS stake, represented as a Q128 fixed-point number.
// - totalDistributeAmount (int64): The total token allocation for this tier.
// - totalClaimedAmount (int64): The total amount of tokens claimed.
// - distributeStartTime (int64): The start time of the reward calculation.
// - distributeEndTime (int64): The end time of the reward calculation.
// - accumulatedDistributeAmount (int64): A legacy field not maintained by v1 reward accounting; normally zero unless explicitly set.
// - rewardClaimableDuration (int64): The duration of reward claimable.
type RewardManager struct {
	rewards *bptree.BPTree // depositId -> RewardState

	distributeAmountPerSecondX128   *u256.Uint // distribute amount per second, Q128
	accumulatedRewardPerDepositX128 *u256.Uint // accumulated reward per GNS stake, Q128

	totalDistributeAmount       int64 // total token allocation for this tier
	totalClaimedAmount          int64 // total claimed amount
	activeDepositAmount         int64 // principal represented by active reward states
	activeClaimedAmount         int64 // claims paid to active reward states
	distributeStartTime         int64 // start time of reward calculation
	distributeEndTime           int64 // end time of reward calculation
	accumulatedDistributeAmount int64 // legacy field; v1 reward paths do not update it
	accumulatedTime             int64 // last time when reward was calculated
	rewardClaimableDuration     int64 // duration of reward claimable

	activePriceDebtX128 *u256.Uint // sum of active deposit amount × initial reward index
}

// Rewards returns the rewards tree of the reward manager.
//
// Returns:
//   - rewards: reward-state tree keyed by deposit ID.
func (rm *RewardManager) Rewards() *bptree.BPTree {
	return rm.rewards
}

// SetRewards sets the rewards tree of the reward manager.
//
// Parameters:
//   - rewards: reward-state tree to use for this manager.
func (rm *RewardManager) SetRewards(rewards *bptree.BPTree) {
	rm.rewards = rewards
}

// SetReward associates a reward state with a deposit ID in the manager's reward tree.
//
// Parameters:
//   - depositID: deposit identifier used as the reward-tree key.
//   - rewardState: reward state to store for that deposit.
func (rm *RewardManager) SetReward(depositID string, rewardState *RewardState) {
	rm.rewards.Set(depositID, rewardState)
}

// RemoveReward removes the reward state associated with a deposit ID.
//
// Parameters:
//   - depositID: deposit identifier whose reward state is removed.
func (rm *RewardManager) RemoveReward(depositID string) {
	rm.rewards.Remove(depositID)
}

// DistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of the reward manager.
//
// Returns:
//   - amountPerSecondX128: reward distribution rate in Q128 fixed-point token units per second.
func (rm *RewardManager) DistributeAmountPerSecondX128() *u256.Uint {
	return rm.distributeAmountPerSecondX128
}

// SetDistributeAmountPerSecondX128 sets the distribute amount per second (Q128) of the reward manager.
//
// Parameters:
//   - amount: replacement reward distribution rate in Q128 fixed-point token units per second; the value is copied.
func (rm *RewardManager) SetDistributeAmountPerSecondX128(amount *u256.Uint) {
	rm.distributeAmountPerSecondX128 = u256.Zero().Set(amount)
}

// AccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of the reward manager.
//
// Returns:
//   - accumulatedRewardPerDepositX128: accumulated reward index per deposited GNS unit in Q128 fixed-point units.
func (rm *RewardManager) AccumulatedRewardPerDepositX128() *u256.Uint {
	return rm.accumulatedRewardPerDepositX128
}

// SetAccumulatedRewardPerDepositX128 sets the accumulated reward per deposit (Q128) of the reward manager.
//
// Parameters:
//   - amount: replacement accumulated reward-per-deposit index in Q128 fixed-point units; the value is copied.
func (rm *RewardManager) SetAccumulatedRewardPerDepositX128(amount *u256.Uint) {
	rm.accumulatedRewardPerDepositX128 = u256.Zero().Set(amount)
}

// TotalDistributeAmount returns the total distribute amount of the reward manager.
//
// Returns:
//   - amount: total reward allocation for the tier in token base units.
func (rm *RewardManager) TotalDistributeAmount() int64 {
	return rm.totalDistributeAmount
}

// SetTotalDistributeAmount sets the total distribute amount of the reward manager.
//
// Parameters:
//   - amount: total reward allocation for the tier in token base units.
func (rm *RewardManager) SetTotalDistributeAmount(amount int64) {
	rm.totalDistributeAmount = amount
}

// TotalClaimedAmount returns the total claimed amount of the reward manager.
//
// Returns:
//   - amount: total reward amount claimed from the tier in token base units.
func (rm *RewardManager) TotalClaimedAmount() int64 {
	return rm.totalClaimedAmount
}

// SetTotalClaimedAmount sets the total claimed amount of the reward manager.
//
// Parameters:
//   - amount: total claimed reward amount in token base units.
func (rm *RewardManager) SetTotalClaimedAmount(amount int64) {
	rm.totalClaimedAmount = amount
}

// ActiveDepositAmount returns the principal represented by currently active reward states.
//
// Returns:
//   - amount: active deposited GNS principal in base units.
func (rm *RewardManager) ActiveDepositAmount() int64 {
	return rm.activeDepositAmount
}

// SetActiveDepositAmount replaces the principal represented by currently active reward states.
//
// Parameters:
//   - amount: active deposited GNS principal in base units.
func (rm *RewardManager) SetActiveDepositAmount(amount int64) {
	rm.activeDepositAmount = amount
}

// ActiveClaimedAmount returns the reward amount claimed by currently active reward states.
//
// Returns:
//   - amount: active claimed reward amount in token base units.
func (rm *RewardManager) ActiveClaimedAmount() int64 {
	return rm.activeClaimedAmount
}

// SetActiveClaimedAmount replaces the reward amount claimed by currently active reward states.
//
// Parameters:
//   - amount: active claimed reward amount in token base units.
func (rm *RewardManager) SetActiveClaimedAmount(amount int64) {
	rm.activeClaimedAmount = amount
}

// ActivePriceDebtX128 returns the sum of active deposits' initial reward-index debts.
//
// Returns:
//   - debt: aggregate active price debt in Q128 fixed-point units.
func (rm *RewardManager) ActivePriceDebtX128() *u256.Uint {
	return rm.activePriceDebtX128
}

// SetActivePriceDebtX128 replaces the aggregate active price-index debt.
//
// Parameters:
//   - debt: aggregate active price debt in Q128 fixed-point units; the value is copied.
func (rm *RewardManager) SetActivePriceDebtX128(debt *u256.Uint) {
	rm.activePriceDebtX128 = u256.Zero().Set(debt)
}

// DistributeStartTime returns the distribute start time of the reward manager.
//
// Returns:
//   - startTime: reward distribution start timestamp in Unix seconds.
func (rm *RewardManager) DistributeStartTime() int64 {
	return rm.distributeStartTime
}

// SetDistributeStartTime sets the distribute start time of the reward manager.
//
// Parameters:
//   - time: reward distribution start timestamp in Unix seconds.
func (rm *RewardManager) SetDistributeStartTime(time int64) {
	rm.distributeStartTime = time
}

// DistributeEndTime returns the distribute end time of the reward manager.
//
// Returns:
//   - endTime: reward distribution end timestamp in Unix seconds.
func (rm *RewardManager) DistributeEndTime() int64 {
	return rm.distributeEndTime
}

// SetDistributeEndTime sets the distribute end time of the reward manager.
//
// Parameters:
//   - time: reward distribution end timestamp in Unix seconds.
func (rm *RewardManager) SetDistributeEndTime(time int64) {
	rm.distributeEndTime = time
}

// AccumulatedDistributeAmount returns the legacy reward-manager field.
// v1 reward paths do not maintain it, so normal reads return zero unless it was
// explicitly set.
//
// Returns:
//   - amount: legacy accumulated distribution amount in token base units; v1 accounting normally leaves it at zero unless explicitly set.
func (rm *RewardManager) AccumulatedDistributeAmount() int64 {
	return rm.accumulatedDistributeAmount
}

// SetAccumulatedDistributeAmount sets the legacy reward-manager field. It is not
// used by v1 reward accounting.
//
// Parameters:
//   - amount: legacy accumulated distribution amount in token base units; v1 accounting does not update this field.
func (rm *RewardManager) SetAccumulatedDistributeAmount(amount int64) {
	rm.accumulatedDistributeAmount = amount
}

// AccumulatedTime returns the accumulated time of the reward manager.
//
// Returns:
//   - time: last reward-accumulation timestamp in Unix seconds, or zero before accumulation.
func (rm *RewardManager) AccumulatedTime() int64 {
	return rm.accumulatedTime
}

// SetAccumulatedTime sets the accumulated time of the reward manager.
//
// Parameters:
//   - time: last reward-accumulation timestamp in Unix seconds.
func (rm *RewardManager) SetAccumulatedTime(time int64) {
	rm.accumulatedTime = time
}

// RewardClaimableDuration returns the reward claimable duration of the reward manager.
//
// Returns:
//   - duration: time after a reward becomes claimable during which it remains collectible, in seconds.
func (rm *RewardManager) RewardClaimableDuration() int64 {
	return rm.rewardClaimableDuration
}

// SetRewardClaimableDuration sets the reward claimable duration of the reward manager.
//
// Parameters:
//   - duration: claimable reward window in seconds.
func (rm *RewardManager) SetRewardClaimableDuration(duration int64) {
	rm.rewardClaimableDuration = duration
}

// Clone returns an independent copy of the reward manager, including its reward states and Q128 values.
//
// Returns:
//   - rewardManager: deep copy with a separate reward tree and mutable numeric values.
func (rm RewardManager) Clone() *RewardManager {
	rewardsTree := bptree.NewBPTreeN(16)
	rm.rewards.Iterate("", "", func(key string, value interface{}) bool {
		rewardState, ok := value.(*RewardState)
		if !ok {
			return true
		}
		rewardsTree.Set(key, rewardState.Clone())
		return false
	})

	return &RewardManager{
		rewards:                         rewardsTree,
		distributeAmountPerSecondX128:   rm.distributeAmountPerSecondX128.Clone(),
		accumulatedRewardPerDepositX128: rm.accumulatedRewardPerDepositX128.Clone(),
		totalDistributeAmount:           rm.totalDistributeAmount,
		totalClaimedAmount:              rm.totalClaimedAmount,
		activeDepositAmount:             rm.activeDepositAmount,
		activeClaimedAmount:             rm.activeClaimedAmount,
		distributeStartTime:             rm.distributeStartTime,
		distributeEndTime:               rm.distributeEndTime,
		accumulatedDistributeAmount:     rm.accumulatedDistributeAmount,
		accumulatedTime:                 rm.accumulatedTime,
		rewardClaimableDuration:         rm.rewardClaimableDuration,
		activePriceDebtX128:             rm.activePriceDebtX128.Clone(),
	}
}

// NewRewardManager returns a pointer to a new RewardManager with the given values.
//
// Parameters:
//   - totalDistributeAmount: total reward allocation for the tier in token base units.
//   - distributeStartTime: reward distribution start timestamp in Unix seconds.
//   - distributeEndTime: reward distribution end timestamp in Unix seconds.
//   - rewardCollectableDuration: duration in seconds for which each accrued reward remains claimable.
//
// Returns:
//   - rewardManager: initialized manager with zeroed accounting counters and an empty reward tree.
func NewRewardManager(
	totalDistributeAmount int64,
	distributeStartTime int64,
	distributeEndTime int64,
	rewardCollectableDuration int64,
) *RewardManager {
	return &RewardManager{
		totalDistributeAmount:           totalDistributeAmount,
		distributeStartTime:             distributeStartTime,
		distributeEndTime:               distributeEndTime,
		totalClaimedAmount:              0,
		activeDepositAmount:             0,
		activeClaimedAmount:             0,
		accumulatedDistributeAmount:     0,
		accumulatedTime:                 0,
		accumulatedRewardPerDepositX128: u256.Zero(),
		distributeAmountPerSecondX128:   u256.Zero(),
		rewardClaimableDuration:         rewardCollectableDuration,
		activePriceDebtX128:             u256.Zero(),
		rewards:                         bptree.NewBPTreeN(16),
	}
}
