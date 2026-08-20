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

// emitUpdateProtocolFeeRewardAccumulation emits the persisted per-token protocol fee
// reward accumulation state for every accrued token. Like the emission variant it
// must be emitted after every path that calls updateAccumulatedProtocolFeeX128PerStake
// (add/remove/claim). protocolFeeAmount and the accumulator are read from the manager's
// persisted state so the emitted tuple stays internally consistent.
func emitUpdateProtocolFeeRewardAccumulation(manager *staker.ProtocolFeeRewardManager, accruedAmounts map[string]int64) {
	for tokenPath := range accruedAmounts {
		accumulatedProtocolFeeX128PerStake := "0"
		if acc := manager.GetAccumulatedProtocolFeeX128PerStake(tokenPath); acc != nil {
			accumulatedProtocolFeeX128PerStake = acc.ToString()
		}

		chain.Emit(
			"UpdateProtocolFeeRewardAccumulation",
			"tokenPath", tokenPath,
			"totalStakedAmount", utils.FormatInt(manager.GetTotalStakedAmount()),
			"protocolFeeAmount", utils.FormatInt(manager.GetProtocolFeeAmounts()[tokenPath]),
			"accumulatedProtocolFeeX128PerStake", accumulatedProtocolFeeX128PerStake,
			"accumulatedTimestamp", utils.FormatInt(manager.GetAccumulatedTimestamp()),
		)
	}
}
