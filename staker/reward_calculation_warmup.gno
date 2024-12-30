package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
)

type Warmup struct {
	Index int
	NextWarmupHeight int64
	WarmupRatio      uint64
}

func DefaultWarmups(currentHeight, avgBlockTimeInMs int64) []Warmup {
	msInDay := int64(86400000)
	blocksInDay := msInDay / int64(avgBlockTimeInMs)
	blocksIn5Days := int64(5 * blocksInDay)
	blocksIn10Days := int64(10 * blocksInDay)
	blocksIn30Days := int64(30 * blocksInDay)

	return []Warmup{
		{
			Index: 0,
			NextWarmupHeight: currentHeight + blocksIn5Days - 1,
			WarmupRatio:      30,
		},
		{
			Index: 1,
			NextWarmupHeight: currentHeight + blocksIn10Days - 1,
			WarmupRatio:      50,
		},
		{
			Index: 2,
			NextWarmupHeight: currentHeight + blocksIn30Days - 1,
			WarmupRatio:      70,
		},
		{
			Index: 3,
			NextWarmupHeight: math.MaxInt64,
			WarmupRatio:      100,
		},
	}
}

func (warmup *Warmup) Apply(poolReward uint64, positionLiquidity, stakedLiquidity *u256.Uint) (uint64, uint64) {
	poolRewardUint := u256.NewUint(poolReward)
	perPositionReward := u256.Zero().Mul(poolRewardUint, positionLiquidity)
	perPositionReward = u256.Zero().Div(perPositionReward, stakedLiquidity)
	rewardRatio := u256.NewUint(warmup.WarmupRatio)
	penaltyRatio := u256.NewUint(100 - warmup.WarmupRatio)
	totalReward := u256.Zero().Mul(perPositionReward, rewardRatio)
	totalReward = u256.Zero().Div(totalReward, u256.NewUint(100))
	totalPenalty := u256.Zero().Mul(perPositionReward, penaltyRatio)
	totalPenalty = u256.Zero().Div(totalPenalty, u256.NewUint(100))
	return totalReward.Uint64(), totalPenalty.Uint64()
}


func (self *Deposit) FindWarmup(currentHeight int64) int {
	for i, warmup := range self.warmups {
		if currentHeight < warmup.NextWarmupHeight {
			return i
		}
	}
	return len(self.warmups) - 1
}

func (self *Deposit) GetWarmup(index int) Warmup {
	return self.warmups[index]
}
