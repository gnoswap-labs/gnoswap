package staker

import (
	"chain"
	"chain/runtime"

	"gno.land/p/gnoswap/utils"
)

// emitSetPoolTier emits the pool-tier assignment, per-tier reward rates, counts, and timestamp.
// Parameters:
//   - prevAddr: Address of the realm that initiated the pool-tier change.
//   - prevRealm: Package path of the initiating realm.
//   - poolPath: Pool whose tier assignment and reward allocation changed.
//   - tier: New tier number assigned to the pool.
//   - rewardPerSecond: Per-pool reward rate for the assigned tier.
//   - tierRewards: Per-pool reward rate keyed by tier, emitted for tiers 1 through 3.
//   - counts: Number of pools currently in each tier index.
//   - currentTime: Unix timestamp at which the tier state was calculated.
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
