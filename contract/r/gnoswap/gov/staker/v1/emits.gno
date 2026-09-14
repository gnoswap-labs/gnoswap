package staker

import (
	"chain"

	"gno.land/p/gnoswap/utils"
	"gno.land/r/gnoswap/gov/staker"
)

// emitUpdateEmissionRewardAccumulation emits the persisted global emission reward
// accumulation state so that off-chain indexers can consume the authoritative
// accumulator instead of re-deriving it. It must be emitted after every path that
// calls updateAccumulatedRewardX128PerStake (add/remove/claim), otherwise the
// off-chain accumulator drifts from the contract.
//
// All values are read from the manager's persisted state (post-update):
//   - distributedAmount is GetDistributedAmount() (the stored baseline the contract
//     will use for the next delta), not the live emission distribution snapshot.
//   - totalStakedAmount reflects the current total after the stake change and is the
//     divisor for the next accumulation delta.
func emitUpdateEmissionRewardAccumulation(manager *staker.EmissionRewardManager) {
	chain.Emit(
		"UpdateEmissionRewardAccumulation",
		"totalStakedAmount", utils.FormatInt(manager.GetTotalStakedAmount()),
		"distributedAmount", utils.FormatInt(manager.GetDistributedAmount()),
		"accumulatedRewardX128PerStake", manager.GetAccumulatedRewardX128PerStake().ToString(),
		"accumulatedTimestamp", utils.FormatInt(manager.GetAccumulatedTimestamp()),
	)
}

// emitUpdateProtocolFeeStakeAccrual emits the accrual epoch opened by a stake change
// together with the total stake in force from it, so that off-chain indexers can
// attribute fees bucketed under that epoch without re-deriving the stake history.
func emitUpdateProtocolFeeStakeAccrual(manager *staker.ProtocolFeeRewardManager) {
	chain.Emit(
		"UpdateProtocolFeeStakeAccrual",
		"epoch", utils.FormatInt(manager.GetCurrentEpoch()),
		"totalStakedAmount", utils.FormatInt(manager.GetTotalStakedAmount()),
	)
}

// emitUpdateProtocolFeeRewardAccumulation emits the persisted accumulation state of
// every token that was just folded. Like the emission variant it must be emitted after
// every path that folds accrual buckets, otherwise the off-chain accumulator drifts
// from the contract.
func emitUpdateProtocolFeeRewardAccumulation(manager *staker.ProtocolFeeRewardManager, tokenPaths []string) {
	for _, tokenPath := range tokenPaths {
		accumulatedProtocolFeeX128PerStake := "0"
		foldedEpoch := int64(-1)
		if accumulator, ok := manager.GetTokenAccumulator(tokenPath); ok {
			accumulatedProtocolFeeX128PerStake = accumulator.GetAccumulatedX128PerStake().ToString()
			foldedEpoch = accumulator.GetFoldedEpoch()
		}

		chain.Emit(
			"UpdateProtocolFeeRewardAccumulation",
			"tokenPath", tokenPath,
			"totalStakedAmount", utils.FormatInt(manager.GetTotalStakedAmount()),
			"protocolFeeAmount", utils.FormatInt(manager.GetProtocolFeeAmount(tokenPath)),
			"accumulatedProtocolFeeX128PerStake", accumulatedProtocolFeeX128PerStake,
			"foldedEpoch", utils.FormatInt(foldedEpoch),
			"accumulatedTimestamp", utils.FormatInt(manager.GetAccumulatedTimestamp()),
		)
	}
}
