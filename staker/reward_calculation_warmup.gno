package staker

import (
	"math"

	u256 "gno.land/p/gnoswap/uint256"
)

type Warmup struct {
	NextWarmupHeight uint64
	WarmupRatio      uint64
}

func DefaultWarmups(currentHeight, avgBlockTimeInMs uint64) []Warmup {
	msInDay := uint64(86400000)
	blocksInDay := msInDay / uint64(avgBlockTimeInMs)
	blocksIn5Days := uint64(5 * blocksInDay)
	blocksIn10Days := uint64(10 * blocksInDay)
	blocksIn30Days := uint64(30 * blocksInDay)

	return []Warmup{
		{
			NextWarmupHeight: currentHeight + blocksIn5Days,
			WarmupRatio:      30,
		},
		{
			NextWarmupHeight: currentHeight + blocksIn10Days,
			WarmupRatio:      50,
		},
		{
			NextWarmupHeight: currentHeight + blocksIn30Days,
			WarmupRatio:      70,
		},
		{
			NextWarmupHeight: math.MaxUint64,
			WarmupRatio:      100,
		},
	}
}

func (self Warmup) CalculateReward(blockNumber uint64, poolReward uint64, positionLiquidity, stakedLiquidity *u256.Uint) (uint64, uint64) {
	poolRewardUint := u256.NewUint(poolReward)
	perPositionReward := poolRewardUint.Mul(poolRewardUint, positionLiquidity)
	perPositionReward = perPositionReward.Div(perPositionReward, stakedLiquidity)
	rewardRatio := self.WarmupRatio
	penaltyRatio := 100 - self.WarmupRatio
	totalReward := blockNumber * perPositionReward.Uint64()
	return totalReward * rewardRatio / 100, totalReward * penaltyRatio / 100
}

func (self *Deposit) FindWarmup(currentHeight uint64) int {
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