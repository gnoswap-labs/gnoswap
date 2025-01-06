package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type IncentiveBound struct {
	Incentive ExternalIncentive
	IsEnter bool
}

// per-pool incentives
type Incentives struct {
	byTime *avl.Tree // (startTime, endTime, creator, rewardToken) => ExternalIncentive
	byHeight *avl.Tree // (startHeight, endHeight, creator, rewardToken) => ExternalIncentive
	byCreator *avl.Tree // (creator, startHeight, endHeight, rewardToken) => ExternalIncentive

	incentiveBound *UintTree // blockNumber -> []IncentiveBound

	rewardCache *RewardCacheTree // blockNumber -> map[string]*u256.Uint
	lastRewardCacheHeight *uint64
}

func NewIncentives(currentHeight uint64) Incentives {
	return Incentives{
		byTime: avl.NewTree(),
		byHeight: avl.NewTree(),
		byCreator: avl.NewTree(),

		incentiveBound: NewUintTree(),

		rewardCache: NewRewardCacheTree(),
		lastRewardCacheHeight: &currentHeight,
	}
}

func (self *Incentives) Exists(startTime, endTime int64, creator std.Address, rewardToken string) bool {
	byTimeId := incentiveIdByTime(uint64(startTime), uint64(endTime), creator, rewardToken)
	return self.byTime.Has(byTimeId)
}

func (self *Incentives) Get(startTime, endTime int64, creator std.Address, rewardToken string) (*ExternalIncentive, bool) {
	byTimeId := incentiveIdByTime(uint64(startTime), uint64(endTime), creator, rewardToken)
	value, ok := self.byTime.Get(byTimeId)
	if !ok {
		return nil, false
	}
	return value.(*ExternalIncentive), true	
}

func (self *Incentives) GetByIncentiveId(incentiveId string) (*ExternalIncentive, bool) {
	value, ok := self.byTime.Get(incentiveId)
	if !ok {
		return nil, false
	}
	return value.(*ExternalIncentive), true
}

// MUST be called after std.GetHeight() > endHeight
func (self *Incentives) remove(incentive *ExternalIncentive) {
	byTimeId := incentiveIdByTime(uint64(incentive.startTimestamp), uint64(incentive.endTimestamp), incentive.refundee, incentive.rewardToken)
	self.byTime.Remove(byTimeId)

	byHeightId, byCreatorId := incentiveIdByHeight(uint64(incentive.startHeight), uint64(incentive.endHeight), incentive.refundee, incentive.rewardToken)
	self.byHeight.Remove(byHeightId)
	self.byCreator.Remove(byCreatorId)
}

func (self *Incentives) GetBound(height uint64) []IncentiveBound {
	value, ok := self.incentiveBound.Get(height)
	if !ok {
		return []IncentiveBound{}
	}
	return value.([]IncentiveBound)
}

// cacheReward() MUST be called before this function
func (self *Incentives) CurrentReward(currentHeight uint64) map[string]*u256.Uint {
	value := self.rewardCache.CurrentReward(currentHeight)
	if value == nil {
		return make(map[string]*u256.Uint)
	}
	return value.(map[string]*u256.Uint)
}

func (self *Incentives) create(
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

	startIncentiveBound := self.GetBound(uint64(incentive.startHeight))
	startIncentiveBound = append(startIncentiveBound, IncentiveBound{
		Incentive: *incentive,
		IsEnter: true,
	})
	self.incentiveBound.Set(uint64(incentive.startHeight), startIncentiveBound)

	endHeight := uint64(incentive.endHeight)
	endIncentiveBound := self.GetBound(endHeight)
	endIncentiveBound = append(endIncentiveBound, IncentiveBound{
		Incentive: *incentive,
		IsEnter: false,
	})
	self.incentiveBound.Set(endHeight, endIncentiveBound)

}

// endHeight MUST be less than or equal to the current block height
func (self *Incentives) cacheRewardPerLiquidityUnit(startHeight, endHeight uint64, stakedLiquidity *u256.Uint) {
	currentReward := self.CurrentReward(startHeight)

	self.incentiveBound.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
		bound := value.([]IncentiveBound)
		reward := make(map[string]*u256.Uint)
		for incentiveId, ratio := range currentReward {
			reward[incentiveId] = ratio
		}
		for _, bound := range bound {
			if bound.IsEnter {
				delta := u256.NewUint(bound.Incentive.rewardPerBlock)
				deltaQ192 := delta.Mul(delta, q192)
				ratio := u256.Zero().Div(deltaQ192, stakedLiquidity)
				reward[bound.Incentive.incentiveId] = ratio
			} else {
				delete(reward, bound.Incentive.incentiveId)
			}
		}
		self.rewardCache.Set(key, reward)
		return false
	})
	*self.lastRewardCacheHeight = endHeight
}