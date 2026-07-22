package launchpad

import (
	"chain"

	"gno.land/p/gnoswap/utils"
	"gno.land/r/gnoswap/launchpad"
)

// emitUpdateLaunchpadRewardAccumulation emits the persisted per-tier reward
// accumulation state so that off-chain indexers can consume the authoritative
// accumulator instead of re-deriving it. It must be emitted after every path that
// calls updateRewardPerDepositX128 (deposit/withdraw/collect/admin-reclaim),
// otherwise the off-chain accumulator drifts from the contract.
//
// The reward manager is keyed by projectTierId, so it is included to identify which
// tier's accumulator this update belongs to. totalDepositAmount is the current tier
// deposit total after the stake change (the divisor for the next accumulation delta),
// and distributeAmountPerSecondX128 lets indexers project the accumulator forward.
func emitUpdateLaunchpadRewardAccumulation(projectTierID string, r *launchpad.RewardManager, totalDepositAmount int64) {
	chain.Emit(
		"UpdateLaunchpadRewardAccumulation",
		"projectTierId", projectTierID,
		"totalDepositAmount", utils.FormatInt(totalDepositAmount),
		"accumulatedRewardPerDepositX128", r.AccumulatedRewardPerDepositX128().ToString(),
		"distributeAmountPerSecondX128", r.DistributeAmountPerSecondX128().ToString(),
		"accumulatedTime", utils.FormatInt(r.AccumulatedTime()),
	)
}
