package staker

import (
	"chain"
	"chain/runtime"

	"gno.land/p/gnoswap/utils"
)

func emitSetPoolTier(
	prevAddr string,
	prevRealm string,
	poolPath string,
	tier uint64,
	rewardPerSecond int64,
	tierRewards map[uint64]int64,
	counts [AllTierCount]uint64,
	currentTime int64,
) {
	chain.Emit(
		"SetPoolTier",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"poolPath", poolPath,
		"tier", utils.FormatUint(tier),
		"rewardPerSecond", utils.FormatInt(rewardPerSecond),
		"tier1RewardPerSecond", utils.FormatInt(tierRewards[Tier1]),
		"tier2RewardPerSecond", utils.FormatInt(tierRewards[Tier2]),
		"tier3RewardPerSecond", utils.FormatInt(tierRewards[Tier3]),
		"tier1Count", utils.FormatUint(counts[Tier1]),
		"tier2Count", utils.FormatUint(counts[Tier2]),
		"tier3Count", utils.FormatUint(counts[Tier3]),
		"currentTime", utils.FormatInt(currentTime),
		"currentHeight", utils.FormatInt(runtime.ChainHeight()),
	)
}
