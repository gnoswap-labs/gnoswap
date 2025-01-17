package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

// per-pool incentives
type Incentives struct {
	byTime    *avl.Tree // (startTime, endTime, creator, rewardToken) => ExternalIncentive
	byHeight  *avl.Tree // (startHeight, endHeight, creator, rewardToken) => ExternalIncentive
	byEndHeight *avl.Tree // (endHeight, startHeight, creator, rewardToken) => ExternalIncentive
	byCreator *avl.Tree // (creator, startHeight, endHeight, rewardToken) => ExternalIncentive

	unclaimablePeriods *UintTree // startHeight => endHeight(0 indicates not ended yet)
}

func NewIncentives() Incentives {
	result := Incentives{
		byTime:    avl.NewTree(),
		byHeight:  avl.NewTree(),
		byEndHeight: avl.NewTree(),
		byCreator: avl.NewTree(),
		unclaimablePeriods: NewUintTree(),
	}

	result.unclaimablePeriods.Set(std.GetHeight(), int64(0))
	return result
}

func (self *Incentives) Exists(startTime, endTime int64, creator std.Address, rewardToken string) bool {
	byTimeId := incentiveIdByTime(startTime, endTime, creator, rewardToken)
	return self.byTime.Has(byTimeId)
}

func (self *Incentives) Get(startTime, endTime int64, creator std.Address, rewardToken string) (*ExternalIncentive, bool) {
	byTimeId := incentiveIdByTime(startTime, endTime, creator, rewardToken)
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

func (self *Incentives) GetAllInHeights(startHeight, endHeight int64) map[string]*ExternalIncentive {
	incentives := make(map[string]*ExternalIncentive)
	// Iterate all incentives that has start height less than endHeight
	self.byHeight.ReverseIterate(
		"",
		EncodeUint(uint64(endHeight)),
		func(key string, value interface{}) bool {
			incentive := value.(*ExternalIncentive)
			if incentive.endHeight < startHeight {
				// incentive is already ended
				return false
			}
			
			incentives[incentive.incentiveId] = incentive
			return false
		},
	)
	// Iterate all incentives that has end height greater than startHeight
	self.byEndHeight.Iterate(
		EncodeUint(uint64(startHeight)),
		"",
		func(key string, value interface{}) bool {
			incentive := value.(*ExternalIncentive)
			if incentive.startHeight > endHeight {
				// incentive is not started yet
				return false
			}

			incentives[incentive.incentiveId] = incentive
			return false
		},
	)
	return incentives
}

// MUST be called after std.GetHeight() > endHeight
func (self *Incentives) remove(incentive *ExternalIncentive) {
	byTimeId := incentiveIdByTime(incentive.startTimestamp, incentive.endTimestamp, incentive.refundee, incentive.rewardToken)
	self.byTime.Remove(byTimeId)

	byHeightId, byCreatorId := incentiveIdByHeight(incentive.startHeight, incentive.endHeight, incentive.refundee, incentive.rewardToken)
	byEndHeightId, _ := incentiveIdByHeight(incentive.endHeight, incentive.startHeight, incentive.refundee, incentive.rewardToken)
	self.byHeight.Remove(byHeightId)
	self.byEndHeight.Remove(byEndHeightId)
	self.byCreator.Remove(byCreatorId)
}

func (self *Incentives) create(
	creator std.Address,
	incentive *ExternalIncentive,
) {
	byTimeId := incentiveIdByTime(incentive.startTimestamp, incentive.endTimestamp, creator, incentive.rewardToken)
	if self.byTime.Has(byTimeId) {
		panic(addDetailToError(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("staker.gno__addExternalIncentive() || incentiveId(%s) already exists", byTimeId),
		))
	}

	byHeightId, byCreatorId := incentiveIdByHeight(incentive.startHeight, incentive.endHeight, creator, incentive.rewardToken)
	byEndHeightId, _ := incentiveIdByHeight(incentive.endHeight, incentive.startHeight, creator, incentive.rewardToken)

	self.byTime.Set(byTimeId, incentive)
	self.byHeight.Set(byHeightId, incentive)
	self.byEndHeight.Set(byEndHeightId, incentive)
	self.byCreator.Set(byCreatorId, incentive)
}

func (self *Incentives) startUnclaimablePeriod(startHeight int64) {
	self.unclaimablePeriods.Set(startHeight, int64(0))
}

func (self *Incentives) endUnclaimablePeriod(endHeight int64) {
	startHeight := int64(0)
	self.unclaimablePeriods.ReverseIterate(0, endHeight, func(key int64, value interface{}) bool {
		if value.(int64) != 0 {
			// Already ended, no need to update
			// keeping startHeight as 0 to indicate this
			return true
		}
		startHeight = key
		return true
	})

	if startHeight == 0 {
		// No ongoing unclaimable period found
		return
	}

	if startHeight == endHeight {
		self.unclaimablePeriods.Remove(startHeight)
	} else {
		self.unclaimablePeriods.Set(startHeight, endHeight)
	}
}

func (self *Incentives) calculateUnclaimableReward(incentiveId string) uint64 {
	incentive, ok := self.GetByIncentiveId(incentiveId)
	if !ok {
		return 0
	}

	blocks := int64(0)


	self.unclaimablePeriods.ReverseIterate(0, incentive.startHeight, func(key int64, value interface{}) bool {
		endHeight := value.(int64)
		if endHeight == 0 {
			endHeight = incentive.endHeight
		}
		if endHeight <= incentive.startHeight {
			return true
		}
		blocks += endHeight - incentive.startHeight
		return true
	})

	self.unclaimablePeriods.Iterate(incentive.startHeight, incentive.endHeight, func(key int64, value interface{}) bool {
		startHeight := key
		endHeight := value.(int64)
		if endHeight == 0 {
			endHeight = incentive.endHeight
		}
		blocks += endHeight - startHeight
		return false
	})

	return uint64(blocks) * incentive.rewardPerBlock
}

