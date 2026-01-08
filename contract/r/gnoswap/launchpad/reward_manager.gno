package launchpad

import (
	"gno.land/p/nt/avl"

	u256 "gno.land/p/gnoswap/uint256"
)

// RewardManager manages the distribution of rewards for a project tier.
//
// This struct contains the necessary data and methods to calculate and track
// rewards for deposits associated with a project tier.
//
// Fields:
// - rewards (avl.Tree): A map of deposit IDs to their associated reward states.
// - distributeAmountPerSecondX128 (u256.Uint): The amount of tokens to be distributed per second, represented as a Q128 fixed-point number.
// - accumulatedRewardPerDepositX128 (u256.Uint): The accumulated reward per GNS stake, represented as a Q128 fixed-point number.
// - totalDistributeAmount (int64): The total amount of tokens to be distributed.
// - totalClaimedAmount (int64): The total amount of tokens claimed.
// - distributeStartTime (int64): The start time of the reward calculation.
// - distributeEndTime (int64): The end time of the reward calculation.
// - accumulatedDistributeAmount (int64): The accumulated amount of tokens distributed.
// - accumulatedHeight (int64): The last height when reward was calculated.
// - rewardClaimableDuration (int64): The duration of reward claimable.
type RewardManager struct {
	rewards *avl.Tree // depositId -> RewardState

	distributeAmountPerSecondX128   *u256.Uint // distribute amount per second, Q128
	accumulatedRewardPerDepositX128 *u256.Uint // accumulated reward per GNS stake, Q128

	totalDistributeAmount       int64 // total distributed amount
	totalClaimedAmount          int64 // total claimed amount
	distributeStartTime         int64 // start time of reward calculation
	distributeEndTime           int64 // end time of reward calculation
	accumulatedDistributeAmount int64 // accumulated distribute amount
	accumulatedHeight           int64 // last height when reward was calculated
	accumulatedTime             int64 // last time when reward was calculated
	rewardClaimableDuration     int64 // duration of reward claimable
}

// Rewards returns the rewards tree of the reward manager.
func (rm *RewardManager) Rewards() *avl.Tree {
	return rm.rewards
}

// SetRewards sets the rewards tree of the reward manager.
func (rm *RewardManager) SetRewards(rewards *avl.Tree) {
	rm.rewards = rewards
}

// DistributeAmountPerSecondX128 returns the distribute amount per second (Q128) of the reward manager.
func (rm *RewardManager) DistributeAmountPerSecondX128() *u256.Uint {
	return rm.distributeAmountPerSecondX128
}

// SetDistributeAmountPerSecondX128 sets the distribute amount per second (Q128) of the reward manager.
func (rm *RewardManager) SetDistributeAmountPerSecondX128(amount *u256.Uint) {
	rm.distributeAmountPerSecondX128 = amount
}

// AccumulatedRewardPerDepositX128 returns the accumulated reward per deposit (Q128) of the reward manager.
func (rm *RewardManager) AccumulatedRewardPerDepositX128() *u256.Uint {
	return rm.accumulatedRewardPerDepositX128
}

// SetAccumulatedRewardPerDepositX128 sets the accumulated reward per deposit (Q128) of the reward manager.
func (rm *RewardManager) SetAccumulatedRewardPerDepositX128(amount *u256.Uint) {
	rm.accumulatedRewardPerDepositX128 = amount
}

// TotalDistributeAmount returns the total distribute amount of the reward manager.
func (rm *RewardManager) TotalDistributeAmount() int64 {
	return rm.totalDistributeAmount
}

// SetTotalDistributeAmount sets the total distribute amount of the reward manager.
func (rm *RewardManager) SetTotalDistributeAmount(amount int64) {
	rm.totalDistributeAmount = amount
}

// TotalClaimedAmount returns the total claimed amount of the reward manager.
func (rm *RewardManager) TotalClaimedAmount() int64 {
	return rm.totalClaimedAmount
}

// SetTotalClaimedAmount sets the total claimed amount of the reward manager.
func (rm *RewardManager) SetTotalClaimedAmount(amount int64) {
	rm.totalClaimedAmount = amount
}

// DistributeStartTime returns the distribute start time of the reward manager.
func (rm *RewardManager) DistributeStartTime() int64 {
	return rm.distributeStartTime
}

// SetDistributeStartTime sets the distribute start time of the reward manager.
func (rm *RewardManager) SetDistributeStartTime(time int64) {
	rm.distributeStartTime = time
}

// DistributeEndTime returns the distribute end time of the reward manager.
func (rm *RewardManager) DistributeEndTime() int64 {
	return rm.distributeEndTime
}

// SetDistributeEndTime sets the distribute end time of the reward manager.
func (rm *RewardManager) SetDistributeEndTime(time int64) {
	rm.distributeEndTime = time
}

// AccumulatedDistributeAmount returns the accumulated distribute amount of the reward manager.
func (rm *RewardManager) AccumulatedDistributeAmount() int64 {
	return rm.accumulatedDistributeAmount
}

// SetAccumulatedDistributeAmount sets the accumulated distribute amount of the reward manager.
func (rm *RewardManager) SetAccumulatedDistributeAmount(amount int64) {
	rm.accumulatedDistributeAmount = amount
}

// AccumulatedHeight returns the accumulated height of the reward manager.
func (rm *RewardManager) AccumulatedHeight() int64 {
	return rm.accumulatedHeight
}

// SetAccumulatedHeight sets the accumulated height of the reward manager.
func (rm *RewardManager) SetAccumulatedHeight(height int64) {
	rm.accumulatedHeight = height
}

// AccumulatedTime returns the accumulated time of the reward manager.
func (rm *RewardManager) AccumulatedTime() int64 {
	return rm.accumulatedTime
}

// SetAccumulatedTime sets the accumulated time of the reward manager.
func (rm *RewardManager) SetAccumulatedTime(time int64) {
	rm.accumulatedTime = time
}

// RewardClaimableDuration returns the reward claimable duration of the reward manager.
func (rm *RewardManager) RewardClaimableDuration() int64 {
	return rm.rewardClaimableDuration
}

// SetRewardClaimableDuration sets the reward claimable duration of the reward manager.
func (rm *RewardManager) SetRewardClaimableDuration(duration int64) {
	rm.rewardClaimableDuration = duration
}

// NewRewardManager returns a pointer to a new RewardManager with the given values.
func NewRewardManager(
	totalDistributeAmount int64,
	distributeStartTime int64,
	distributeEndTime int64,
	rewardCollectableDuration int64,
	currentHeight int64,
	currentTime int64,
) *RewardManager {
	return &RewardManager{
		totalDistributeAmount:           totalDistributeAmount,
		distributeStartTime:             distributeStartTime,
		distributeEndTime:               distributeEndTime,
		totalClaimedAmount:              0,
		accumulatedDistributeAmount:     0,
		accumulatedHeight:               0,
		accumulatedTime:                 0,
		accumulatedRewardPerDepositX128: u256.Zero(),
		distributeAmountPerSecondX128:   u256.Zero(),
		rewardClaimableDuration:         rewardCollectableDuration,
		rewards:                         avl.NewTree(),
	}
}
