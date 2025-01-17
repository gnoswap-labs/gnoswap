package staker

import (
	"std"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"
)

type IncentiveBound struct {
	Incentive ExternalIncentive
	IsEnter   bool
}

// per-pool incentives
type Incentives struct {
	byTime    *avl.Tree // (startTime, endTime, creator, rewardToken) => ExternalIncentive
	byHeight  *avl.Tree // (startHeight, endHeight, creator, rewardToken) => ExternalIncentive
	byCreator *avl.Tree // (creator, startHeight, endHeight, rewardToken) => ExternalIncentive
}

func NewIncentives(currentHeight uint64) Incentives {
	return Incentives{
		byTime:    avl.NewTree(),
		byHeight:  avl.NewTree(),
		byCreator: avl.NewTree(),
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

func (self *Incentives) GetAllInHeights(startHeight, endHeight int64) []*ExternalIncentive {
	println("[[[GetAllInHeights Start]]]", startHeight, endHeight)

	self.byHeight.Iterate(
		"",
		"",
		func(key string, value interface{}) bool {
			println("[[[GetAllInHeights Iterate]]]")
			println("[[[key]]]", key)
			println("[[[value]]]", value)
			return false
		},
	)

	incentives := make([]*ExternalIncentive, 0)
	self.byHeight.Iterate(
		EncodeUint(uint64(startHeight)),
		EncodeUint(uint64(endHeight)),
		func(key string, value interface{}) bool {
			incentives = append(incentives, value.(*ExternalIncentive))
			return false
		},
	)
	return incentives
}

// MUST be called after std.GetHeight() > endHeight
func (self *Incentives) remove(incentive *ExternalIncentive) {
	byTimeId := incentiveIdByTime(uint64(incentive.startTimestamp), uint64(incentive.endTimestamp), incentive.refundee, incentive.rewardToken)
	self.byTime.Remove(byTimeId)

	byHeightId, byCreatorId := incentiveIdByHeight(uint64(incentive.startHeight), uint64(incentive.endHeight), incentive.refundee, incentive.rewardToken)
	self.byHeight.Remove(byHeightId)
	self.byCreator.Remove(byCreatorId)
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
}