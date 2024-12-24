package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// per-pool incentives
type Incentives struct {
	byTime *avl.Tree // (startTime, endTime, creator, rewardToken) => ExternalIncentive
	byHeight *avl.Tree // (startHeight, endHeight, creator, rewardToken) => ExternalIncentive
	byCreator *avl.Tree // (creator, startHeight, endHeight, rewardToken) => ExternalIncentive

	// the value map denotes delta of the external incentive per block for the token
	delta *UintTree // blockNumber -> map[string]int64

	rewardCache *RewardCacheTree // blockNumber -> map[string]int64
	lastRewardCacheHeight *uint64
	
	// refund to the refundee
	totalPenalty *uint64
	claimedPenalty *uint64
}

func NewIncentives(currentHeight uint64) Incentives {
	totalPenalty := uint64(0)
	claimedPenalty := uint64(0)

	return Incentives{
		byTime: avl.NewTree(),
		byHeight: avl.NewTree(),
		byCreator: avl.NewTree(),

		delta: NewUintTree(),

		rewardCache: NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,

		totalPenalty: &totalPenalty,
		claimedPenalty: &claimedPenalty,
	}
}

func (self *Incentives) claimPenalty() uint64 {
	amount := *self.totalPenalty - *self.claimedPenalty
	*self.claimedPenalty += amount
	return amount
}

func (self *Incentives) Exists(startTime, endTime int64, creator std.Address, rewardToken string) bool {
	byTimeId := incentiveIdByTime(uint64(startTime), uint64(endTime), creator, rewardToken)
	return self.byTime.Has(byTimeId)
}

func (self *Incentives) Get(startTime, endTime int64, creator std.Address, rewardToken string) *ExternalIncentive {
	byTimeId := incentiveIdByTime(uint64(startTime), uint64(endTime), creator, rewardToken)
	value, ok := self.byTime.Get(byTimeId)
	if !ok {
		return nil
	}
	return value.(*ExternalIncentive)
}

// MUST be called after std.GetHeight() > endHeight
func (self *Incentives) remove(incentive *ExternalIncentive) {
	byTimeId := incentiveIdByTime(uint64(incentive.startTimestamp), uint64(incentive.endTimestamp), incentive.refundee, incentive.rewardToken)
	self.byTime.Remove(byTimeId)

	byHeightId, byCreatorId := incentiveIdByHeight(uint64(incentive.startHeight), uint64(incentive.endHeight), incentive.refundee, incentive.rewardToken)
	self.byHeight.Remove(byHeightId)
	self.byCreator.Remove(byCreatorId)
}

func (self *Incentives) GetDelta(height uint64) map[string]int64 {
	delta, ok := self.delta.Get(height)
	if !ok {
		return make(map[string]int64)
	}
	return delta.(map[string]int64)
}

// cacheReward() MUST be called before this function
func (self *Incentives) CurrentReward(currentHeight uint64) map[string]int64 {
	value := self.rewardCache.CurrentReward(currentHeight)
	if value == nil {
		return make(map[string]int64)
	}
	return value.(map[string]int64)
}

func (self *Incentives) add(
	creator std.Address, 
	incentive *ExternalIncentive,
) {
	byTimeId := incentiveIdByTime(uint64(incentive.startTimestamp), uint64(incentive.endTimestamp), creator, incentive.rewardToken)
	if self.byTime.Has(byTimeId) {
		panic(addDetailToError(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("staker.gno__addExternalIncentive() || incentiveId(%s) already exists", byTimeId),
		))
	}

	byHeightId, byCreatorId := incentiveIdByHeight(uint64(incentive.startHeight), uint64(incentive.endHeight), creator, incentive.rewardToken)

	self.byTime.Set(byTimeId, incentive)
	self.byHeight.Set(byHeightId, incentive)
	self.byCreator.Set(byCreatorId, incentive)

	startIncentiveDelta := self.GetDelta(uint64(incentive.startHeight))
	startIncentiveDelta[incentive.rewardToken] += int64(incentive.rewardPerBlock)
	startHeight := uint64(incentive.startHeight)
	self.delta.Set(startHeight, startIncentiveDelta)

	endHeight := uint64(incentive.endHeight)
	endIncentiveDelta := self.GetDelta(endHeight)
	endIncentiveDelta[incentive.rewardToken] -= int64(incentive.rewardPerBlock)
	self.delta.Set(endHeight, endIncentiveDelta)
}

// endHeight MUST be less than or equal to the current block height
func (self *Incentives) cacheReward(endHeight uint64) {
	startHeight := *self.lastRewardCacheHeight
	currentReward := self.CurrentReward(startHeight)
	self.delta.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		delta := value.(map[string]int64)
		reward := make(map[string]int64)
		for token, deltaAmount := range delta {
			result := currentReward[token] + deltaAmount
			if result == 0 {
				continue
			}
			reward[token] = result
		}
		self.rewardCache.Set(key, reward)
		return false
	})
	*self.lastRewardCacheHeight = endHeight
}
/*
func (self *Incentives) EligibleIntervalToExternalReward(interval Interval, warmup Warmup, positionLiquidity *u256.Uint) (map[string]uint64, map[string]uint64) {
	totalReward := make(map[string]uint64)
	totalPenalty := make(map[string]uint64)
	stakedLiquidity := interval.Value

	self.rewardCache.EligibleIntervalToReward(interval, warmupIndex, warmup, func(blockNumber uint64, poolRewardI interface{}) {
		poolReward := poolRewardI.(map[string]uint64)
		for token, poolReward := range poolReward {
			currentReward, currentPenalty := warmup.CalculateReward(blockNumber, poolReward, positionLiquidity, stakedLiquidity)
			totalReward[token] += currentReward
			totalPenalty[token] += currentPenalty
		}
	})
	return totalReward, totalPenalty
}
*/
func (self *Incentives) EligibleIntervalsToExternalReward(intervals []Interval, deposit *Deposit) ([]map[string]uint64, []map[string]uint64) {
	rewards := make([]map[string]uint64, len(deposit.warmups))
	penalties := make([]map[string]uint64, len(deposit.warmups))
	for i := 0; i < len(deposit.warmups); i++ {
		rewards[i] = make(map[string]uint64)
		penalties[i] = make(map[string]uint64)
	}
	positionLiquidity := deposit.liquidity
	self.rewardCache.EligibleIntervalsToReward(intervals, deposit, func(warmupIndex int, warmup Warmup, blockNumber uint64, stakedLiquidity *u256.Uint, poolRewardI interface{}) {
		poolRewards := poolRewardI.(map[string]uint64)
		for token, poolReward := range poolRewards {
			currentReward, currentPenalty := warmup.CalculateReward(blockNumber, poolReward, positionLiquidity, stakedLiquidity)
			rewards[warmupIndex][token] += currentReward
			penalties[warmupIndex][token] += currentPenalty
		}
	})
	return rewards, penalties
}