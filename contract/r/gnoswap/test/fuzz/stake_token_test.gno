package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/r/gnoswap/staker"
)

// TestFuzzStakeToken_InternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzStakeToken_InternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		_, internalIncentiveTier, positionID := setupInternalIncentivePoolAndPosition(ft)

		params := NewValidStakeTokenParams(ft, positionID)
		params.setInternalIncentiveTier(internalIncentiveTier)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestStakeToken(ft, params)
	})
}

// TestFuzzStakeToken_ExternalIncentive_Stateless fuzzes the StakeToken function.
func TestFuzzStakeToken_ExternalIncentive_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		_, incentiveID, positionID := setupExternalRewardPoolAndPosition(ft)

		params := NewValidStakeTokenParams(ft, positionID)
		params.addExternalIncentiveId(incentiveID)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestStakeToken(ft, params)
	}, false)
}

// runTestStakeToken runs the test swap route.
func runTestStakeToken(ft *fuzz.T, params *stakeTokenParams) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	staker.StakeToken(
		cross,
		params.positionID,
		"",
	)
}
