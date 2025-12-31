package staker

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/p/nt/ufmt"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/staker"
)

// TestFuzzCollectReward_InternalIncentive_Stateless fuzzes the CollectReward function.
func TestFuzzCollectReward_InternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		emissionStartTimestamp := setupEmissionStartTimestamp(ft)

		testing.SetRealm(testing.NewUserRealm(adminAddr))
		emission.ChangeDistributionPct(cross, 1, 6500, 2, 0, 3, 0, 4, 3500)

		_, _, positionID := setupInternalIncentivePoolAndPositionByRange(ft, 1, 3)
		setupStakePosition(ft, positionID)

		params := NewValidCollectRewardParams(ft, positionID, true, emissionStartTimestamp)
		testing.SkipHeights(params.skipBlocks)
		params.updatePreviousBalances("gno.land/r/gnoswap/gns")

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestCollectReward(ft, params)
	})
}

// TestFuzzCollectReward_ExternalIncentive_Stateless fuzzes the CollectReward function.
func TestFuzzCollectReward_ExternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		poolPath, incentiveID, positionID := setupExternalRewardPoolAndPosition(ft)
		setupStakePosition(ft, positionID)

		incentiveTimestamp := staker.GetIncentiveStartTimestamp(poolPath, incentiveID)
		params := NewValidCollectRewardParams(ft, positionID, true, incentiveTimestamp)
		testing.SkipHeights(params.skipBlocks)
		params.updatePreviousBalances(oblPath)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestCollectReward(ft, params)
	})
}

// runTestCollectReward runs the test swap route.
func runTestCollectReward(ft *fuzz.T, params *collectRewardParams) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.CollectReward(
		cross,
		params.positionID,
		false,
	)

	isStartedDistribution := params.isStartedDistribution()
	hasBalanceChanges := params.hasBalanceChanges()
	if isStartedDistribution != hasBalanceChanges {
		panic(ufmt.Sprintf("invalid reward result: isStartedDistribution: %v, hasBalanceChanges: %v", isStartedDistribution, hasBalanceChanges))
	}
}

func setupEmissionStartTimestamp(ft *fuzz.T) int64 {
	if emission.GetDistributionStartTimestamp() == 0 {
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	}

	return emission.GetDistributionStartTimestamp()
}
