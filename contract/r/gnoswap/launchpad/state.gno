package launchpad

import (
	"std"
	"time"

	"gno.land/r/gnoswap/v1/gns"
)

var avgBlockTimeMs int64 = 2000

func init() {
	avgBlockTimeMs = gns.AvgBlockTimeInMs()

	registerAvgBlockTimeChangeCallback()
}

func registerAvgBlockTimeChangeCallback() {
	gns.SetAvgBlockTimeChangeCallback(cross, func(blockTimeMs int64) {
		func(cur realm) {
			avgBlockTimeMs = blockTimeMs

			updateProjectBlockTimes(blockTimeMs)
		}(cross)
	})
}

func updateProjectBlockTimes(avgBlockTimeMs int64) {
	currentHeight := std.ChainHeight()
	currentBlockTime := time.Now().Unix()

	// update project block times
	projects.Iterate("", "", func(projectID string, value any) bool {
		project, ok := value.(*Project)
		if !ok {
			return false
		}

		for _, tier := range project.tiers {
			tier.endBlockTimeInfo.updateHeightByAverageBlockTimeMs(currentBlockTime, currentHeight, avgBlockTimeMs)
			tier.updateDistributeAmountPerBlock()

			rewardManagerAny, ok := projectTierRewardManagers.Get(tier.ID())
			if !ok {
				return false
			}

			rewardManager, ok := rewardManagerAny.(*RewardManager)
			if !ok {
				return false
			}

			rewardManager.distributeEndHeight = tier.EndHeight()
			rewardManager.updateRewardPerDepositX128(tier.totalDepositAmount, currentHeight)

			// update reward state distributeEndHeight
			rewardManager.rewards.Iterate("", "", func(reward string, value any) bool {
				rewardState, ok := value.(*RewardState)
				if !ok {
					return false
				}

				rewardState.distributeEndHeight = tier.EndHeight()

				return false
			})

			return false
		}

		return false
	})
}